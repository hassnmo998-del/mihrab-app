import 'dart:async';
import 'dart:io';
import 'package:audio_service/audio_service.dart' show MediaItem;
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import '../models/models.dart';
import 'background_audio.dart';
import 'telegram_media_resolver.dart';

/// Plays a recorded public lesson, app-wide.
///
/// Lived inside the Discover screen before, so leaving that tab (e.g. to open the
/// Quran) destroyed the player mid-lesson. As a singleton it keeps playing across tabs
/// and, through [BackgroundAudio], with the app in the background on Android.
class LessonAudioService extends ChangeNotifier implements BackgroundAudioSource {
  LessonAudioService._();
  static final LessonAudioService instance = LessonAudioService._();

  static const List<double> rates = [1.0, 1.25, 1.5, 2.0];

  AudioPlayer? _player;
  AudioPlayer get _p {
    if (_player == null) {
      final p = AudioPlayer();
      if (!kIsWeb && Platform.isAndroid) {
        // Keep the CPU awake so a locked phone doesn't cut the lesson off.
        unawaited(p.setAudioContext(
          AudioContext(
            android: const AudioContextAndroid(
              isSpeakerphoneOn: false,
              stayAwake: true,
              contentType: AndroidContentType.music,
              usageType: AndroidUsageType.media,
              audioFocus: AndroidAudioFocus.none,
            ),
          ),
        ).catchError((_) {}));
      }
      // Every stream listener needs onError, or a platform error (bad URL) becomes an
      // unhandled exception that brings the app down.
      p.onDurationChanged.listen((d) {
        _duration = d;
        _publish();
        notifyListeners();
      }, onError: _onPlayerError);
      p.onPositionChanged.listen((pos) {
        _position = pos;
        notifyListeners();
      }, onError: _onPlayerError);
      p.onPlayerStateChanged.listen((state) {
        _state = state;
        if (state == PlayerState.completed) _position = Duration.zero;
        _publish();
        notifyListeners();
      }, onError: _onPlayerError);
      _player = p;
    }
    return _player!;
  }

  String? _activeEventId;
  String _title = '';
  String _speaker = '';
  PlayerState _state = PlayerState.stopped;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  double _rate = 1.0;

  /// Shown by whichever screen is listening; errors while no screen is open are logged.
  void Function(String message)? onError;

  String? get activeEventId => _activeEventId;
  bool get isPlaying => _state == PlayerState.playing;
  Duration get position => _position;
  Duration get duration => _duration;
  double get rate => _rate;

  void _onPlayerError(Object error, [StackTrace? _]) {
    debugPrint('⚠️ خطأ في مشغّل الدرس: $error');
    _fail('تعذّر تشغيل هذا التسجيل، حاول مرة أخرى');
  }

  void _fail(String message) {
    _reset();
    onError?.call(message);
  }

  void _reset() {
    unawaited(_player?.stop().catchError((_) {}));
    _activeEventId = null;
    _position = Duration.zero;
    _duration = Duration.zero;
    BackgroundAudio.release(this);
    notifyListeners();
  }

  /// Plays [ev]'s recording, or toggles pause if it's the one already loaded.
  Future<void> playOrPause(CommunityEvent ev) async {
    final rawPath = ev.audioRecordUrl;
    if (rawPath == null || rawPath.trim().isEmpty) {
      onError?.call('ملف التسجيل الصوتي غير متوفر لهذا الدرس');
      return;
    }

    if (_activeEventId == ev.id) {
      return isPlaying ? pause() : play();
    }

    try {
      await BackgroundAudio.claim(this);
      await _p.stop();
      _activeEventId = ev.id;
      _title = ev.title;
      _speaker = ev.organizerName;
      _position = Duration.zero;
      _duration = Duration.zero;
      notifyListeners();

      await _p.setPlaybackRate(_rate);

      final cleanPath = rawPath.trim();
      if (File(cleanPath).existsSync()) {
        await _p.play(DeviceFileSource(cleanPath));
      } else if (TelegramMediaResolver.isRef(cleanPath)) {
        // مرجع دائم: نطلب رابطاً طازجاً لأن روابط تيليجرام تنتهي بعد ساعة
        final resolved = await TelegramMediaResolver.resolveResult(cleanPath);
        if (resolved.url == null) {
          _fail(TelegramMediaResolver.failureMessage(resolved.error));
          return;
        }
        await _p.play(UrlSource(resolved.url!));
      } else if (TelegramMediaResolver.isExpiredLegacyLink(cleanPath)) {
        // رابط محفوظ بنسخة قديمة من التطبيق: انتهت صلاحيته ولا يمكن تجديده
        _fail('هذا التسجيل محفوظ برابط قديم انتهت صلاحيته، يلزم إعادة رفعه');
        return;
      } else if (cleanPath.startsWith('http://') || cleanPath.startsWith('https://')) {
        await _p.play(UrlSource(cleanPath));
      } else {
        await _p.play(DeviceFileSource(cleanPath));
      }
    } catch (e) {
      debugPrint('⚠️ فشل تشغيل الصوت: $e');
      _fail('تعذّر تشغيل هذا التسجيل، حاول مرة أخرى');
    }
  }

  Future<void> seekRelative(int seconds) {
    final target = _position + Duration(seconds: seconds);
    final clamped = target < Duration.zero ? Duration.zero : (target > _duration ? _duration : target);
    return seek(clamped);
  }

  Future<void> cycleRate() async {
    final idx = rates.indexOf(_rate);
    _rate = rates[(idx + 1) % rates.length];
    notifyListeners();
    if (_player != null) await _player!.setPlaybackRate(_rate);
    _publish();
  }

  @override
  void syncMediaSession() => _publish();

  void _publish() {
    if (_activeEventId == null) return;
    BackgroundAudio.publish(
      this,
      item: MediaItem(
        id: 'lesson:$_activeEventId',
        title: _title,
        artist: _speaker,
        album: 'مكتبة الدروس والخطب',
        artUri: BackgroundAudio.cachedArtworkUri,
        duration: _duration > Duration.zero ? _duration : null,
      ),
      playing: isPlaying,
      buffering: false,
      position: _position,
      speed: _rate,
      seekable: true,
    );
  }

  // --- BackgroundAudioSource (system media controls) ---

  @override
  Future<void> play() async {
    BackgroundAudio.onUserPlaybackAction();
    if (_activeEventId == null || _player == null) return;
    await BackgroundAudio.claim(this);
    await _player!.resume();
  }

  @override
  Future<void> pause() async {
    BackgroundAudio.onUserPlaybackAction();
    await _player?.pause();
  }

  @override
  Future<void> stop() async {
    BackgroundAudio.onUserPlaybackAction();
    if (_activeEventId == null) return;
    _reset();
  }

  @override
  Future<void> seek(Duration position) async {
    await _player?.seek(position);
    _position = position;
    _publish();
    notifyListeners();
  }

  @override
  Future<void> skipToNext() => seekRelative(15);

  @override
  Future<void> skipToPrevious() => seekRelative(-15);
}
