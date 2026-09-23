import 'dart:async';
import 'dart:io';
import 'package:audio_service/audio_service.dart' show MediaItem;
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import '../models/quran_reciter.dart';
import 'background_audio.dart';
import 'quran_audio_cache.dart';
import 'quran_service.dart';

/// النطاق الذي تُكرَّر فيه التلاوة.
enum QuranRepeatScope {
  ayah,  // هذه الآية
  page,  // هذه الصفحة
  juz,   // هذا الجزء
  quran, // القرآن كاملاً
}

/// متى تتوقف التلاوة تلقائياً: عند تجاوز الآية أو السورة أو الجزء الحالي، أو لا تتوقف.
enum QuranStopAfter {
  ayah,  // هذه الآية
  surah, // هذه السورة
  juz,   // هذا الجزء
  never, // لا تتوقف
}

/// Metadata for one ayah in the playback queue.
class QuranAyahAudioTag {
  final int surahNumber;
  final int ayahNumber;
  final String surahName;
  final int pageNumber;

  const QuranAyahAudioTag({
    required this.surahNumber,
    required this.ayahNumber,
    required this.surahName,
    required this.pageNumber,
  });

  String get key => '$surahNumber:$ayahNumber';
}

/// Quran Audio Service.
///
/// Plays one ayah at a time from a self-managed queue (the ayahs of one page, or a
/// single ayah), so the active ayah is always the one we asked for — no reliance on
/// platform playlist/index reporting, which is unreliable on Windows.
/// - Tapping an ayah starts it immediately, exactly like pressing play.
/// - Repeat scope (ayah / page / juz / whole Quran) × repeat count (1..10, ∞).
/// - Playback speed cycling (0.75x - 1.5x).
class QuranAudioService implements BackgroundAudioSource {
  QuranAudioService._() {
    // Mirror what's playing to the notification / lock screen (Android & iOS).
    for (final n in <Listenable>[
      activeTagNotifier,
      isPlayingNotifier,
      isBufferingNotifier,
      reciterNotifier,
      durationNotifier,
      speedNotifier,
    ]) {
      n.addListener(syncMediaSession);
    }
  }
  static final QuranAudioService instance = QuranAudioService._();

  static const List<double> speeds = [0.75, 1.0, 1.25, 1.5];
  static const List<int> repeatCounts = [1, 2, 3, 5, 7, 10, -1];

  /// How many upcoming ayahs are downloaded ahead of the one playing.
  static const int _prefetchCount = 3;

  AudioPlayer? _player;
  AudioPlayer get player {
    if (_player == null) {
      _player = AudioPlayer();
      if (!kIsWeb && Platform.isAndroid) {
        // Keep the CPU awake so recitation continues with the screen locked.
        unawaited(_player!.setAudioContext(AudioContextConfig(stayAwake: true).build()).catchError((_) {}));
      }
      _attach(_player!);
    }
    return _player!;
  }

  // Active State Notifiers
  final ValueNotifier<QuranReciter> reciterNotifier =
      ValueNotifier<QuranReciter>(QuranReciter.defaultReciters[0]); // Al-Husary default
  final ValueNotifier<QuranRepeatScope> scopeNotifier =
      ValueNotifier<QuranRepeatScope>(QuranRepeatScope.page);
  final ValueNotifier<String?> activeAyahNotifier = ValueNotifier<String?>(null); // e.g. '1:1'
  final ValueNotifier<int?> activePageNotifier = ValueNotifier<int?>(null);
  final ValueNotifier<QuranAyahAudioTag?> activeTagNotifier =
      ValueNotifier<QuranAyahAudioTag?>(null);

  /// Whether playback is intended to be running (stays true across ayah transitions).
  final ValueNotifier<bool> isPlayingNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<bool> isBufferingNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<double> speedNotifier = ValueNotifier<double>(1.0);
  final ValueNotifier<int> repeatCountNotifier = ValueNotifier<int>(1); // 1 = once, -1 = infinite
  final ValueNotifier<QuranStopAfter> stopAfterNotifier =
      ValueNotifier<QuranStopAfter>(QuranStopAfter.never);
  final ValueNotifier<Duration> positionNotifier = ValueNotifier<Duration>(Duration.zero);
  final ValueNotifier<Duration> durationNotifier = ValueNotifier<Duration>(Duration.zero);

  // Queue state
  List<QuranAyahAudioTag> _queue = [];
  int _index = 0;

  /// Bumped on every load/stop; async work from an older load checks it and bails out.
  int _generation = 0;

  /// True once the current ayah's source is prepared on the player (false while loading,
  /// after completion, or after an error) — completion events are only trusted when true.
  bool _sourceReady = false;
  String? _loadedUrl;

  /// عدد الدورات المكتملة للنطاق الحالي.
  int _passesDone = 0;

  /// حدود الصفحات للنطاقات المبنية على الصفحات (صفحة / جزء / القرآن).
  int _rangeStartPage = 1;
  int _rangeEndPage = 604;

  /// أول وآخر صفحة لكل جزء — تُحسب مرة واحدة.
  static Map<int, (int, int)>? _juzPageRanges;

  final List<StreamSubscription> _subs = [];
  Timer? _bufferingTimer;

  /// Creates the platform player ahead of the first tap to cut start latency.
  void init() => player;

  void _attach(AudioPlayer p) {
    _subs.addAll([
      p.onPlayerComplete.listen((_) => _onTrackComplete(), onError: _logStreamError),
      p.onPositionChanged.listen((pos) => positionNotifier.value = pos, onError: _logStreamError),
      p.onDurationChanged.listen((dur) => durationNotifier.value = dur, onError: _logStreamError),
    ]);
  }

  void _logStreamError(Object e) => debugPrint('⚠️ QuranAudioService stream error: $e');

  bool get _hasMorePasses {
    final target = repeatCountNotifier.value;
    return target == -1 || _passesDone < target;
  }

  // =========================================================================
  // Options
  // =========================================================================

  /// Change the active reciter; the current ayah reloads with the new voice.
  Future<void> setReciter(QuranReciter reciter) async {
    reciterNotifier.value = reciter;
    await _reloadCurrent();
  }

  /// Change the repeat scope; the current ayah is re-anchored to the new scope.
  Future<void> setScope(QuranRepeatScope scope) async {
    scopeNotifier.value = scope;
    await _reloadCurrent();
  }

  /// Where playback stops on its own, on top of the repeat settings.
  void setStopAfter(QuranStopAfter value) => stopAfterNotifier.value = value;

  /// True when moving on from [from] to [to] leaves the ayah / surah / juz the listener
  /// asked to stop after. Repeating within the same unit is not a crossing, so repeat
  /// settings still apply inside it.
  @visibleForTesting
  static bool crossesStopBoundary(QuranStopAfter mode, QuranAyahAudioTag from, QuranAyahAudioTag to) {
    switch (mode) {
      case QuranStopAfter.never:
        return false;
      case QuranStopAfter.ayah:
        return from.key != to.key;
      case QuranStopAfter.surah:
        return from.surahNumber != to.surahNumber;
      case QuranStopAfter.juz:
        return _juzOf(from) != _juzOf(to);
    }
  }

  static int _juzOf(QuranAyahAudioTag tag) {
    final page = QuranService.getPage(tag.pageNumber);
    final ayah = page?.ayahs
        .where((a) => a.surahNumber == tag.surahNumber && a.ayahNumberInSurah == tag.ayahNumber)
        .firstOrNull;
    return ayah?.juzNumber ?? page?.juzNumber ?? 0;
  }

  static QuranAyahAudioTag? _firstTagOfPage(int page) {
    final a = QuranService.getPage(page)?.ayahs.firstOrNull;
    if (a == null) return null;
    return QuranAyahAudioTag(
      surahNumber: a.surahNumber,
      ayahNumber: a.ayahNumberInSurah,
      surahName: a.surahName,
      pageNumber: page,
    );
  }

  /// Stops (and returns true) instead of moving on to [next] when that would pass the
  /// "stop after" point. Only automatic transitions check this; skip buttons don't.
  bool _stopsBefore(QuranAyahAudioTag finished, QuranAyahAudioTag? next) {
    if (next == null || !crossesStopBoundary(stopAfterNotifier.value, finished, next)) return false;
    stop();
    return true;
  }

  /// Set repeat count (1, 2, 3, 5, 7, 10, -1 for infinite).
  void setRepeatCount(int count) {
    repeatCountNotifier.value = count;
    _passesDone = 0;
  }

  /// Set playback speed (0.75x, 1.0x, 1.25x, 1.5x).
  Future<void> setSpeed(double speed) async {
    speedNotifier.value = speed;
    if (_player == null || !_sourceReady) return; // applied when the next ayah starts
    try {
      await _player!.setPlaybackRate(speed);
    } catch (e) {
      debugPrint('⚠️ Error setting speed: $e');
    }
  }

  /// Advances to the next speed in [speeds], wrapping around.
  Future<void> cycleSpeed() {
    final idx = speeds.indexOf(speedNotifier.value);
    return setSpeed(speeds[(idx + 1) % speeds.length]);
  }

  // =========================================================================
  // Playback Triggers
  // =========================================================================

  /// Starts the current scope from this ayah — tapping an ayah is the same as pressing play.
  Future<void> playAyah(
    int surahNumber,
    int ayahNumber, {
    int? pageNumber,
    bool autoPlay = true,
  }) async {
    final page = pageNumber ?? QuranService.getPageForAyah(surahNumber, ayahNumber) ?? 1;
    _passesDone = 0;

    switch (scopeNotifier.value) {
      case QuranRepeatScope.ayah:
        _setQueue([
          QuranAyahAudioTag(
            surahNumber: surahNumber,
            ayahNumber: ayahNumber,
            surahName: QuranService.getSurahName(surahNumber),
            pageNumber: page,
          ),
        ], 0);
        if (autoPlay) await _playCurrent();
        return;
      case QuranRepeatScope.page:
        _rangeStartPage = page;
        _rangeEndPage = page;
      case QuranRepeatScope.juz:
        final juz = QuranService.getPage(page)?.juzNumber ?? 1;
        final (start, end) = _juzRange(juz);
        _rangeStartPage = start;
        _rangeEndPage = end;
      case QuranRepeatScope.quran:
        _rangeStartPage = 1;
        _rangeEndPage = QuranService.totalPages;
    }
    await _loadPage(page, startAtAyahKey: '$surahNumber:$ayahNumber', autoPlay: autoPlay);
  }

  Future<void> _reloadCurrent() async {
    final tag = activeTagNotifier.value;
    if (tag == null) return;
    await playAyah(
      tag.surahNumber,
      tag.ayahNumber,
      pageNumber: tag.pageNumber,
      autoPlay: isPlayingNotifier.value,
    );
  }

  static (int, int) _juzRange(int juz) {
    _juzPageRanges ??= () {
      final ranges = <int, (int, int)>{};
      for (int p = 1; p <= QuranService.totalPages; p++) {
        final j = QuranService.getPage(p)?.juzNumber;
        if (j == null) continue;
        final existing = ranges[j];
        ranges[j] = existing == null ? (p, p) : (existing.$1, p);
      }
      return ranges;
    }();
    return _juzPageRanges![juz] ?? (1, QuranService.totalPages);
  }

  /// Queues all Ayahs of a Madinah Mushaf Page (1-604), starting at [startAtAyahKey].
  Future<void> _loadPage(int pageNumber, {String? startAtAyahKey, bool autoPlay = true}) async {
    final quranPage = QuranService.getPage(pageNumber);
    if (quranPage == null || quranPage.ayahs.isEmpty) return;

    final tags = [
      for (final a in quranPage.ayahs)
        QuranAyahAudioTag(
          surahNumber: a.surahNumber,
          ayahNumber: a.ayahNumberInSurah,
          surahName: a.surahName,
          pageNumber: pageNumber,
        ),
    ];
    final startIndex = startAtAyahKey == null ? 0 : tags.indexWhere((t) => t.key == startAtAyahKey);
    _setQueue(tags, startIndex < 0 ? 0 : startIndex);
    if (autoPlay) await _playCurrent();
  }

  /// Replaces the queue and publishes the start ayah without touching the player.
  void _setQueue(List<QuranAyahAudioTag> tags, int startIndex) {
    _generation++;
    _queue = tags;
    _index = startIndex;
    _sourceReady = false;
    _publish(tags[startIndex]);
  }

  void _publish(QuranAyahAudioTag tag) {
    activeTagNotifier.value = tag;
    activeAyahNotifier.value = tag.key;
    activePageNotifier.value = tag.pageNumber;
  }

  /// Loads and plays `_queue[_index]` from its beginning.
  Future<void> _playCurrent() async {
    final gen = ++_generation;
    final tag = _queue[_index];
    final reciter = reciterNotifier.value;
    final url = reciter.getAyahAudioUrl(tag.surahNumber, tag.ayahNumber);

    unawaited(BackgroundAudio.claim(this));
    _publish(tag);
    positionNotifier.value = Duration.zero;
    isPlayingNotifier.value = true;
    // Only show the loading spinner when a load is actually slow, not on every ayah change.
    _bufferingTimer?.cancel();
    _bufferingTimer = Timer(const Duration(milliseconds: 400), () {
      if (gen == _generation && !_sourceReady) isBufferingNotifier.value = true;
    });
    _prefetchAhead(reciter);

    try {
      if (_sourceReady && url == _loadedUrl) {
        // Same ayah already loaded: restart it instead of reloading.
        _sourceReady = false;
        await player.seek(Duration.zero);
        if (gen != _generation) return;
        await player.resume();
      } else {
        _sourceReady = false;
        // Heard before or prefetched: play from disk, no network wait.
        final local = await QuranAudioCache.instance.cachedPath(reciter, tag.surahNumber, tag.ayahNumber);
        if (gen != _generation) return;
        await player.play(local != null ? DeviceFileSource(local) : UrlSource(url));
      }
      if (gen != _generation) return;
      _loadedUrl = url;
      _sourceReady = true;
      await player.setPlaybackRate(speedNotifier.value);
    } catch (e) {
      if (gen != _generation) return;
      debugPrint('⚠️ Error playing ${tag.key}: $e');
      _loadedUrl = null;
      isPlayingNotifier.value = false; // pressing play retries this ayah
    } finally {
      if (gen == _generation) {
        _bufferingTimer?.cancel();
        isBufferingNotifier.value = false;
      }
    }
  }

  /// Downloads the current ayah (instant repeats) and the next few in the background,
  /// plus the start of the next page when the queue is about to run out.
  void _prefetchAhead(QuranReciter reciter) {
    final ahead = <(int, int)>[
      for (var i = _index; i < _queue.length && i <= _index + _prefetchCount; i++)
        (_queue[i].surahNumber, _queue[i].ayahNumber),
    ];
    if (scopeNotifier.value != QuranRepeatScope.ayah && _index + _prefetchCount >= _queue.length - 1) {
      final page = _queue[_index].pageNumber;
      final nextPage = page < _rangeEndPage ? page + 1 : _rangeStartPage;
      final nextAyahs = QuranService.getPage(nextPage)?.ayahs ?? const [];
      for (final a in nextAyahs.take(2)) {
        ahead.add((a.surahNumber, a.ayahNumberInSurah));
      }
    }
    QuranAudioCache.instance.prefetch(reciter, ahead);
  }

  /// Called when the current ayah finishes: next ayah, next page, next pass, or stop.
  void _onTrackComplete() {
    if (!_sourceReady || !isPlayingNotifier.value) return; // stale or mid-load event
    _sourceReady = false;
    _loadedUrl = null; // the player releases the source on completion
    final finished = _queue[_index];

    if (_index + 1 < _queue.length) {
      if (_stopsBefore(finished, _queue[_index + 1])) return;
      _index++;
      _playCurrent();
      return;
    }

    if (scopeNotifier.value == QuranRepeatScope.ayah) {
      _passesDone++;
      if (_hasMorePasses) {
        _playCurrent();
      } else {
        stop();
      }
      return;
    }

    // Page-based scopes: advance through the range, then loop it.
    final currentPage = finished.pageNumber;
    if (currentPage < _rangeEndPage) {
      if (_stopsBefore(finished, _firstTagOfPage(currentPage + 1))) return;
      _loadPage(currentPage + 1);
      return;
    }
    _passesDone++;
    if (_hasMorePasses) {
      if (_stopsBefore(finished, _firstTagOfPage(_rangeStartPage))) return;
      _loadPage(_rangeStartPage);
    } else {
      stop();
    }
  }

  // =========================================================================
  // Playback Controls
  // =========================================================================

  Future<void> resume() async {
    if (activeTagNotifier.value == null || _queue.isEmpty) return;
    if (!_sourceReady) return _playCurrent(); // not loaded yet, released, or failed
    unawaited(BackgroundAudio.claim(this));
    isPlayingNotifier.value = true;
    try {
      await player.resume();
    } catch (e) {
      debugPrint('⚠️ Resume error: $e');
      await _playCurrent();
    }
  }

  @override
  Future<void> pause() async {
    isPlayingNotifier.value = false;
    try {
      await _player?.pause();
    } catch (e) {
      debugPrint('⚠️ Pause error: $e');
    }
  }

  @override
  Future<void> stop() async {
    _generation++;
    _bufferingTimer?.cancel();
    _passesDone = 0;
    _sourceReady = false;
    _loadedUrl = null;
    _queue = [];
    isPlayingNotifier.value = false;
    isBufferingNotifier.value = false;
    positionNotifier.value = Duration.zero;
    activeAyahNotifier.value = null;
    activePageNotifier.value = null;
    activeTagNotifier.value = null;
    BackgroundAudio.release(this);
    try {
      await _player?.stop();
    } catch (e) {
      debugPrint('⚠️ Stop error: $e');
    }
  }

  /// Next ayah within the queue, otherwise re-anchors the scope on the next ayah.
  Future<void> skipNext() async {
    if (_queue.isEmpty) return;
    if (_index + 1 < _queue.length) {
      _index++;
      return _playCurrent();
    }
    final tag = _queue[_index];
    final count = QuranService.getUthmaniVerses(tag.surahNumber).length;
    if (tag.ayahNumber < count) {
      await playAyah(tag.surahNumber, tag.ayahNumber + 1);
    } else if (tag.surahNumber < 114) {
      await playAyah(tag.surahNumber + 1, 1);
    }
  }

  /// Previous ayah within the queue, otherwise re-anchors the scope on the previous ayah.
  Future<void> skipPrevious() async {
    if (_queue.isEmpty) return;
    if (_index > 0) {
      _index--;
      return _playCurrent();
    }
    final tag = _queue[_index];
    if (tag.ayahNumber > 1) {
      await playAyah(tag.surahNumber, tag.ayahNumber - 1);
    } else if (tag.surahNumber > 1) {
      final prevSurah = tag.surahNumber - 1;
      await playAyah(prevSurah, QuranService.getUthmaniVerses(prevSurah).length);
    }
  }

  @override
  Future<void> seek(Duration position) async {
    try {
      await _player?.seek(position);
    } catch (e) {
      debugPrint('⚠️ Seek error: $e');
    }
  }

  // --- BackgroundAudioSource (system media controls) ---

  @override
  Future<void> play() => resume();

  @override
  Future<void> skipToNext() => skipNext();

  @override
  Future<void> skipToPrevious() => skipPrevious();

  @override
  void syncMediaSession() {
    final tag = activeTagNotifier.value;
    if (tag == null) return;
    final duration = durationNotifier.value;
    BackgroundAudio.publish(
      this,
      item: MediaItem(
        id: 'quran:${reciterNotifier.value.id}:${tag.key}',
        title: 'سورة ${tag.surahName} · الآية ${tag.ayahNumber}',
        artist: reciterNotifier.value.nameArabic,
        album: 'القرآن الكريم',
        duration: duration > Duration.zero ? duration : null,
      ),
      playing: isPlayingNotifier.value,
      buffering: isBufferingNotifier.value,
      position: positionNotifier.value,
      speed: speedNotifier.value,
    );
  }

  void dispose() {
    _generation++;
    _bufferingTimer?.cancel();
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
    _player?.dispose();
    _player = null;
  }
}
