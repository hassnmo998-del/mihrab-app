import 'dart:async';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/adhan_sound.dart';
import 'adhan_data.dart';
import 'update/update_downloader.dart';
import 'update/update_models.dart';

/// ملف واحد من ملفي المؤذن كما يراه محرك التنزيل.
class _AdhanFileSpec implements DownloadSpec {
  const _AdhanFileSpec(this.url, this.size, this.sha256);

  final String url;
  @override
  final int size;
  @override
  final String sha256;

  @override
  List<String> get urls => [url];

  /// اسم الملف على الخادم يحمل بصمته، فيُستعمل كما هو على الجهاز.
  @override
  String get fileName => Uri.parse(url).pathSegments.last;
}

/// ملفات أصوات الأذان على الجهاز وتنزيلها.
///
/// التنزيل لا يفشل بسبب الشبكة: يستكمل من آخر بايت وصل، وينتظر عودة الاتصال،
/// وما لم يكتمل يُستأنف عند فتح التطبيق التالي لأن الطابور محفوظ. والمشغّل لا يبثّ
/// من الشبكة أبداً: يشغّل ملفاً محلياً أو معاينة قصيرة مضمَّنة في التطبيق.
class AdhanAudioCacheManager {
  AdhanAudioCacheManager._();
  static final AdhanAudioCacheManager instance = AdhanAudioCacheManager._();

  static const String defaultSoundId = 'iconic_makkah_ali_mullah';
  static const String pendingTargetPrefKey = 'adhan_pending_target_sound_id';
  static const String pendingQueuePrefKey = 'adhan_pending_download_queue';

  static const String _defaultAsset = 'audio/default_adhan.mp3';
  static const String _defaultFajrAsset = 'audio/default_adhan_fajr.mp3';

  List<AdhanSound> _catalog = AdhanData.allSounds;
  Directory? _dir;

  /// مجلد ما قبل 1.0.11: تسجيل واحد لكل مؤذن يُؤذَّن به لكل الصلوات.
  Directory? _legacyDir;
  UpdateDownloader? _downloader;

  // Download states
  final ValueNotifier<Set<String>> downloadedSoundIdsNotifier =
      ValueNotifier<Set<String>>({defaultSoundId});

  final ValueNotifier<Map<String, double>> downloadProgressNotifier =
      ValueNotifier<Map<String, double>>({});

  final ValueNotifier<Set<String>> activeDownloadingIdsNotifier =
      ValueNotifier<Set<String>>({});

  /// يُنادى حين يكتمل تنزيل صوت بملفيه.
  void Function(String soundId)? onSoundReady;

  final List<String> _queue = [];
  final Map<String, Completer<bool>> _waiters = {};
  bool _working = false;
  bool _initialized = false;
  bool _disposed = false;

  /// يتغيّر مع كل dispose: تنزيل بدأ قبله يتوقف ولا يمسّ حالة ما بعده.
  int _session = 0;

  /// المتصفح (نسخة الآيفون) لا يحفظ ملفات: يشغّل من الرابط مباشرة.
  bool get supportsDownloads => !kIsWeb;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    _disposed = false;
    if (kIsWeb) return;

    try {
      final support = await getApplicationSupportDirectory();
      final dir = Directory('${support.path}${Platform.pathSeparator}adhan_audio_v2');
      await dir.create(recursive: true);
      _dir = dir;
      _downloader = UpdateDownloader(dir: dir);

      try {
        final docs = await getApplicationDocumentsDirectory();
        _legacyDir = Directory('${docs.path}${Platform.pathSeparator}adhan_audio');
        await _cleanLegacyLeftovers();
      } catch (_) {
        _legacyDir = null;
      }

      await refreshDownloadedCache();
      await _resumePending();
    } catch (e) {
      debugPrint('⚠️ [AdhanAudioCacheManager] Init error: $e');
    }
  }

  /// الأذان الافتراضي صار يُشغَّل من داخل التطبيق مباشرة، فنسخته المستخرجة قديماً
  /// (وفيها «الصلاة خير من النوم») تُحذف مع بقايا التنزيلات الناقصة، ومع كل تسجيل
  /// قديم وصل بديلاه. لا يُحذف القديم لحظة وصول البديل: مسار أندرويد المحفوظ قد
  /// يشير إليه بعدُ، فيُحذف هنا عند التشغيل التالي.
  Future<void> _cleanLegacyLeftovers() async {
    final legacy = _legacyDir;
    if (legacy == null || !await legacy.exists()) return;
    final superseded = {
      for (final sound in _catalog)
        if (_hasAllFiles(sound)) '${sound.id}.mp3',
    };
    await for (final entity in legacy.list()) {
      if (entity is! File) continue;
      final name = entity.uri.pathSegments.last;
      if (name == '$defaultSoundId.mp3' || name.endsWith('.tmp') || superseded.contains(name)) {
        try {
          await entity.delete();
        } catch (_) {}
      }
    }
  }

  File? _file(AdhanSound sound, {required bool fajr}) {
    final dir = _dir;
    if (dir == null) return null;
    final url = fajr ? sound.fajrUrl : sound.audioUrl;
    if (url == null || url.isEmpty) return null;
    return File('${dir.path}${Platform.pathSeparator}${Uri.parse(url).pathSegments.last}');
  }

  bool _isComplete(AdhanSound sound, {required bool fajr}) {
    final file = _file(sound, fajr: fajr);
    if (file == null) return false;
    try {
      final expected = fajr ? sound.fajrBytes : sound.audioBytes;
      return file.existsSync() && (expected <= 0 || file.lengthSync() == expected);
    } catch (_) {
      return false;
    }
  }

  bool _hasAllFiles(AdhanSound sound) =>
      _isComplete(sound, fajr: false) && (!sound.hasFajrVariant || _isComplete(sound, fajr: true));

  /// التسجيل القديم لهذا الصوت إن بقي على الجهاز ولم يُستبدل بعد.
  String? legacyPath(String soundId) {
    final legacy = _legacyDir;
    if (legacy == null || soundId == defaultSoundId) return null;
    try {
      final file = File('${legacy.path}${Platform.pathSeparator}$soundId.mp3');
      if (file.existsSync() && file.lengthSync() > 80 * 1024) return file.path;
    } catch (_) {}
    return null;
  }

  /// Scans disk to find all sounds that can play with no connection
  Future<void> refreshDownloadedCache() async {
    final downloaded = <String>{defaultSoundId};
    for (final sound in _catalog) {
      if (_hasAllFiles(sound) || legacyPath(sound.id) != null) downloaded.add(sound.id);
    }
    downloadedSoundIdsNotifier.value = downloaded;
  }

  /// Returns whether a sound is guaranteed to be available locally offline
  bool isSoundDownloaded(String soundId) {
    if (soundId == defaultSoundId) return true;
    return downloadedSoundIdsNotifier.value.contains(soundId);
  }

  /// مسار الملف الذي يشغّله أندرويد عند الأذان. ملف الفجر null للتسجيلات التي
  /// لا تحمل «الصلاة خير من النوم»، فيُؤذَّن للفجر بالملف العادي.
  String? nativePath(AdhanSound sound, {required bool fajr}) {
    if (sound.id == defaultSoundId) return null; // مضمَّن في التطبيق
    if (fajr) {
      return sound.hasFajrVariant && _isComplete(sound, fajr: true) ? _file(sound, fajr: true)!.path : null;
    }
    if (_isComplete(sound, fajr: false)) return _file(sound, fajr: false)!.path;
    return legacyPath(sound.id);
  }

  /// مصدر الأذان الكامل لهذا الصوت، أو null إن لم يكن على الجهاز بعد.
  Source? sourceFor(AdhanSound sound, {bool fajr = false}) {
    final wantsFajr = fajr && sound.hasFajrVariant;
    if (sound.id == defaultSoundId) {
      return AssetSource(wantsFajr ? _defaultFajrAsset : _defaultAsset);
    }
    if (kIsWeb) return UrlSource(wantsFajr ? sound.fajrUrl! : sound.audioUrl);

    final path = (wantsFajr ? nativePath(sound, fajr: true) : null) ?? nativePath(sound, fajr: false);
    return path == null ? null : DeviceFileSource(path);
  }

  /// ما يُسمع عند ضغط زر المعاينة: الأذان كاملاً إن كان على الجهاز، وإلا مقطع
  /// قصير مضمَّن في التطبيق (يعمل فوراً وبلا إنترنت).
  Source previewSource(AdhanSound sound) {
    if (!kIsWeb || sound.id == defaultSoundId) {
      final full = sourceFor(sound);
      if (full != null) return full;
    }
    return AssetSource('audio/previews/${sound.id}.mp3');
  }

  /// Gets playable Source for audioplayers: prioritizes local file or asset
  Source getPlayableSource(AdhanSound sound) => previewSource(sound);

  /// ينزّل ملفي الصوت ويعيد true حين يكتملان. انقطاع الشبكة لا يُنهيه: ينتظر
  /// ويكمل. [silent] لتنزيل لم يطلبه المستخدم الآن (ترقية تسجيل قديم) فلا يظهر.
  Future<bool> downloadSound({
    required AdhanSound sound,
    void Function(double progress)? onProgress,
    bool silent = false,
  }) async {
    if (sound.id == defaultSoundId || _hasAllFiles(sound)) {
      onProgress?.call(1.0);
      return true;
    }
    if (!_initialized) await init();
    if (_downloader == null || _disposed) return false;

    final id = sound.id;
    if (!silent) _setActive(id, true);
    if (onProgress != null) {
      void listener() => onProgress(downloadProgressNotifier.value[id] ?? 0);
      downloadProgressNotifier.addListener(listener);
      unawaited(
        (_waiters[id] ??= Completer<bool>()).future.whenComplete(
              () => downloadProgressNotifier.removeListener(listener),
            ),
      );
    }
    final waiter = _waiters[id] ??= Completer<bool>();
    if (!_queue.contains(id)) {
      _queue.add(id);
      await _persistQueue(add: id);
    }
    unawaited(_pump());
    return waiter.future;
  }

  /// Queues a sound to be downloaded; [isTargetSound] makes it the selected adhan once it lands
  Future<void> queuePendingDownload(String soundId, {bool isTargetSound = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (isTargetSound) {
        await prefs.setString(pendingTargetPrefKey, soundId);
      }
      await _persistQueue(add: soundId);
    } catch (_) {}
  }

  Future<void> _persistQueue({String? add, String? remove}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queue = prefs.getStringList(pendingQueuePrefKey) ?? <String>[];
      if (add != null && !queue.contains(add)) queue.add(add);
      if (remove != null) queue.remove(remove);
      await prefs.setStringList(pendingQueuePrefKey, queue);
    } catch (_) {}
  }

  /// ما طلبه المستخدم ولم يكتمل قبل إغلاق التطبيق، ثم تسجيلات ما قبل 1.0.11
  /// التي تُستبدل بصمت بملفي العادي والفجر.
  Future<void> _resumePending() async {
    final prefs = await SharedPreferences.getInstance();
    final requested = <String>[
      ...?prefs.getStringList(pendingQueuePrefKey),
      if (prefs.getString(pendingTargetPrefKey) case final String target) target,
    ];
    final known = {for (final s in _catalog) s.id: s};
    for (final id in requested.toSet()) {
      final sound = known[id];
      if (sound == null || id == defaultSoundId || _hasAllFiles(sound)) {
        await _persistQueue(remove: id);
        continue;
      }
      unawaited(downloadSound(sound: sound));
    }

    final selected = prefs.getString('adhan_selected_sound_id');
    final legacy = [
      for (final sound in _catalog)
        if (legacyPath(sound.id) != null && !_hasAllFiles(sound)) sound,
    ]..sort((a, b) => (b.id == selected ? 1 : 0) - (a.id == selected ? 1 : 0));
    for (final sound in legacy) {
      if (!_queue.contains(sound.id)) unawaited(downloadSound(sound: sound, silent: true));
    }
  }

  /// صوت واحد في كل مرة: على الشبكة الضعيفة يكتمل الأول بدل أن يتقاسم الكل السرعة.
  Future<void> _pump() async {
    if (_working || _disposed) return;
    _working = true;
    final session = _session;
    try {
      while (_queue.isNotEmpty) {
        final id = _queue.first;
        final sound = _catalog.where((s) => s.id == id).firstOrNull;
        final outcome = sound == null ? false : await _downloadFiles(sound, session);
        if (session != _session) return;
        _queue.remove(id);

        // null: تعذّر على القرص — يبقى في الطابور المحفوظ ويُعاد عند الفتح التالي
        if (outcome != null) await _persistQueue(remove: id);
        if (outcome == true && sound != null) await refreshDownloadedCache();
        if (session != _session) return;
        _setProgress(id, null);
        _setActive(id, false);
        _waiters.remove(id)?.complete(outcome == true);
        if (outcome == true) onSoundReady?.call(id);
      }
    } finally {
      if (session == _session) _working = false;
    }
  }

  /// true اكتمل، false الملف على الخادم ليس ما يصفه الكتالوج، null توقف أو تعذّر على القرص.
  Future<bool?> _downloadFiles(AdhanSound sound, int session) async {
    final downloader = _downloader;
    if (downloader == null) return null;
    final specs = [
      _AdhanFileSpec(sound.audioUrl, sound.audioBytes, sound.audioSha256),
      if (sound.hasFajrVariant) _AdhanFileSpec(sound.fajrUrl!, sound.fajrBytes, sound.fajrSha256),
    ];
    final total = specs.fold<int>(0, (sum, s) => sum + s.size);
    // الشبكة لا تُخرج المحرك من حلقته؛ ما يصل إلى هنا خطأ في القرص (مجلد لا يُنشأ مثلاً)
    for (var attempt = 1; attempt <= 4; attempt++) {
      var done = 0;
      try {
        for (final spec in specs) {
          final file = await downloader.run(spec, onTick: (progress) {
            if (session != _session) return false;
            if (total > 0) _setProgress(sound.id, (done + progress.received) / total);
            return true;
          });
          if (file == null) return null;
          done += spec.size;
        }
        debugPrint('✅ [AdhanAudioCacheManager] Downloaded & verified: ${sound.title}');
        return true;
      } on UpdateContentMismatch catch (e) {
        debugPrint('⚠️ [AdhanAudioCacheManager] ${sound.title}: $e');
        return false;
      } catch (e) {
        debugPrint('⚠️ [AdhanAudioCacheManager] Download interrupted for ${sound.title}: $e');
        await Future<void>.delayed(Duration(seconds: 2 * attempt));
        if (session != _session) return null;
      }
    }
    return null;
  }

  void _setProgress(String id, double? progress) {
    final current = downloadProgressNotifier.value;
    if (progress == null) {
      if (!current.containsKey(id)) return;
      downloadProgressNotifier.value = Map<String, double>.from(current)..remove(id);
      return;
    }
    final clamped = progress.clamp(0.0, 1.0);
    // لا يُعاد بناء القائمة إلا حين يتحرك الرقم الظاهر (1%)
    if (((current[id] ?? -1) * 100).floor() == (clamped * 100).floor()) return;
    downloadProgressNotifier.value = Map<String, double>.from(current)..[id] = clamped;
  }

  void _setActive(String id, bool active) {
    final current = activeDownloadingIdsNotifier.value;
    if (current.contains(id) == active) return;
    final next = Set<String>.from(current);
    active ? next.add(id) : next.remove(id);
    activeDownloadingIdsNotifier.value = next;
  }

  void dispose() {
    _disposed = true;
    _initialized = false;
    _session++;
    _working = false;
    _queue.clear();
    for (final waiter in _waiters.values) {
      if (!waiter.isCompleted) waiter.complete(false);
    }
    _waiters.clear();
    activeDownloadingIdsNotifier.value = {};
    downloadProgressNotifier.value = {};
  }

  /// للاختبارات: مجلدات ومحرك تنزيل بديلة بدل مجلدات النظام.
  @visibleForTesting
  Future<void> debugConfigure({
    required Directory dir,
    Directory? legacyDir,
    UpdateDownloader? downloader,
    List<AdhanSound>? catalog,
  }) async {
    dispose();
    _catalog = catalog ?? AdhanData.allSounds;
    _disposed = false;
    _initialized = true;
    _dir = dir;
    _legacyDir = legacyDir;
    _downloader = downloader ?? UpdateDownloader(dir: dir);
    await dir.create(recursive: true);
    await _cleanLegacyLeftovers();
    await refreshDownloadedCache();
    await _resumePending();
  }
}
