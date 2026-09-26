import 'dart:async';
import 'dart:io';
import 'dart:ui' show Color;
import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

/// Something that can be driven from the system media controls
/// (notification, lock screen, headset / Bluetooth buttons).
abstract class BackgroundAudioSource {
  Future<void> play();
  Future<void> pause();
  Future<void> stop();
  Future<void> skipToNext();
  Future<void> skipToPrevious();
  Future<void> seek(Duration position);

  /// Re-sends the current state via [BackgroundAudio.publish] (e.g. once the media
  /// service has finished starting).
  void syncMediaSession();
}

/// App-wide audio session shared by the Quran reciter and recorded lessons.
///
/// - Only one source plays at a time: [claim] stops whatever held the session before.
/// - On Android/iOS it runs a media service with [AudioSession] and [AudioService],
///   so playback keeps going with the app in the background or screen locked.
/// - Handles audio focus interruptions cleanly: pauses on incoming external audio/video
///   (calls, reels, videos) and auto-resumes immediately when the interruption stops.
/// - Automatically pauses when headphones/AirPods are disconnected (becoming noisy).
/// - Displays high-resolution Islamic artwork and crisp, responsive controls in the
///   notification shade and lock screen.
class BackgroundAudio {
  BackgroundAudio._();

  static _AppAudioHandler? _handler;
  static Future<void>? _initializing;
  static BackgroundAudioSource? _owner;
  static AudioSession? _audioSession;
  static StreamSubscription<AudioInterruptionEvent>? _interruptionSub;
  static StreamSubscription<void>? _becomingNoisySub;
  static bool _interruptedByExternalAudio = false;
  static Uri? _cachedArtworkUri;

  static bool get _supported => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  /// Cached URI for high-res notification artwork.
  static Uri? get cachedArtworkUri => _cachedArtworkUri;

  /// Starts the media service and audio session once, on first playback (not at app launch).
  static Future<void> _ensureInitialized() {
    if (!_supported || _handler != null) return Future.value();
    return _initializing ??= () async {
      try {
        await _prepareArtwork();

        _handler = await AudioService.init(
          builder: _AppAudioHandler.new,
          config: const AudioServiceConfig(
            androidNotificationChannelId: 'com.masjed.app.audio',
            androidNotificationChannelName: 'تلاوة القرآن الكريم والدروس',
            androidNotificationChannelDescription: 'التحكم بالصوت وشاشة القفل في منصة محراب',
            notificationColor: Color(0xFF0F5A47),
            androidNotificationIcon: 'mipmap/ic_launcher',
            androidShowNotificationBadge: false,
            androidNotificationClickStartsActivity: true,
            androidNotificationOngoing: true,
            androidStopForegroundOnPause: true,
            fastForwardInterval: Duration(seconds: 15),
            rewindInterval: Duration(seconds: 15),
          ),
        );

        // Configure system audio session for background playback and interruptions
        _audioSession = await AudioSession.instance;
        await _audioSession!.configure(const AudioSessionConfiguration.music());

        // Listen for external interruptions (calls, videos, reels, alarms)
        _interruptionSub?.cancel();
        _interruptionSub = _audioSession!.interruptionEventStream.listen(_handleInterruption);

        // Listen for headphone disconnect (becoming noisy)
        _becomingNoisySub?.cancel();
        _becomingNoisySub = _audioSession!.becomingNoisyEventStream.listen((_) {
          _interruptedByExternalAudio = false;
          _owner?.pause();
        });
      } catch (e) {
        debugPrint('⚠️ BackgroundAudio init failed: $e');
      }
    }();
  }

  /// Copies app logo asset to a local file for Android/iOS notification artwork.
  static Future<void> _prepareArtwork() async {
    if (_cachedArtworkUri != null) return;
    try {
      final byteData = await rootBundle.load('assets/images/app_logo.png');
      final tempDir = await getTemporaryDirectory();
      final artFile = File('${tempDir.path}/mihrab_notification_artwork.png');
      if (!artFile.existsSync() || artFile.lengthSync() != byteData.lengthInBytes) {
        await artFile.writeAsBytes(
          byteData.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes),
          flush: true,
        );
      }
      _cachedArtworkUri = Uri.file(artFile.path);
    } catch (e) {
      debugPrint('⚠️ Could not prepare notification artwork: $e');
    }
  }

  /// Manages pausing when external video/audio starts and resuming immediately when it stops.
  static void _handleInterruption(AudioInterruptionEvent event) {
    if (event.begin) {
      // External video, audio or call started -> pause playback immediately
      if (_owner != null) {
        _interruptedByExternalAudio = true;
        _owner?.pause();
      }
    } else {
      // External video/audio stopped -> resume playback immediately if interrupted
      if (_interruptedByExternalAudio && _owner != null) {
        _interruptedByExternalAudio = false;
        _owner?.play();
      }
    }
  }

  /// Notifies that the user intentionally paused or played, clearing any interruption flag.
  static void onUserPlaybackAction() {
    _interruptedByExternalAudio = false;
  }

  /// Makes [source] the one the system controls drive, stopping the previous owner
  /// (so a lesson and the Quran never play over each other).
  static Future<void> claim(BackgroundAudioSource source) async {
    final previous = _owner;
    _owner = source;
    _interruptedByExternalAudio = false;
    if (previous != null && !identical(previous, source)) {
      await previous.stop();
    }
    final wasReady = _handler != null;
    await _ensureInitialized();
    try {
      await _audioSession?.setActive(true);
    } catch (_) {}
    // The first publish may have happened while the service was still starting.
    if (!wasReady && identical(_owner, source)) source.syncMediaSession();
  }

  /// Gives up the session if [source] still owns it (e.g. after it stopped).
  static void release(BackgroundAudioSource source) {
    if (!identical(_owner, source)) return;
    _owner = null;
    _interruptedByExternalAudio = false;
    _handler?.clear();
    try {
      _audioSession?.setActive(false);
    } catch (_) {}
  }

  /// Updates the notification / lock screen for [source], if it owns the session.
  static void publish(
    BackgroundAudioSource source, {
    required MediaItem item,
    required bool playing,
    required bool buffering,
    required Duration position,
    double speed = 1.0,
    bool seekable = false,
  }) {
    if (!identical(_owner, source)) return;
    _handler?.update(
      item: item,
      playing: playing,
      buffering: buffering,
      position: position,
      speed: speed,
      seekable: seekable,
    );
  }

  static BackgroundAudioSource? get owner => _owner;
}

class _AppAudioHandler extends BaseAudioHandler with SeekHandler {
  BackgroundAudioSource? get _source => BackgroundAudio._owner;

  void update({
    required MediaItem item,
    required bool playing,
    required bool buffering,
    required Duration position,
    required double speed,
    required bool seekable,
  }) {
    if (mediaItem.value != item) mediaItem.add(item);

    // Ayah-by-ayah sources skip between items; long recordings rewind/forward instead.
    final controls = seekable
        ? [
            MediaControl.rewind,
            playing ? MediaControl.pause : MediaControl.play,
            MediaControl.fastForward,
            MediaControl.stop,
          ]
        : [
            MediaControl.skipToPrevious,
            playing ? MediaControl.pause : MediaControl.play,
            MediaControl.skipToNext,
            MediaControl.stop,
          ];

    playbackState.add(PlaybackState(
      controls: controls,
      systemActions: {
        MediaAction.playPause,
        if (seekable) ...{
          MediaAction.rewind,
          MediaAction.fastForward,
        } else ...{
          MediaAction.skipToNext,
          MediaAction.skipToPrevious,
        },
        MediaAction.seek,
        MediaAction.stop,
      },
      androidCompactActionIndices: const [0, 1, 2],
      processingState: buffering ? AudioProcessingState.buffering : AudioProcessingState.ready,
      playing: playing,
      updatePosition: position,
      speed: speed,
    ));
  }

  /// Idle removes the notification and lets the service stop.
  void clear() {
    playbackState.add(PlaybackState(processingState: AudioProcessingState.idle, playing: false));
  }

  @override
  Future<void> play() async {
    BackgroundAudio.onUserPlaybackAction();
    final current = playbackState.value;
    playbackState.add(current.copyWith(
      playing: true,
      processingState: AudioProcessingState.ready,
      controls: [
        for (final c in current.controls)
          if (c == MediaControl.play) MediaControl.pause else c,
      ],
    ));
    await _source?.play();
  }

  @override
  Future<void> pause() async {
    BackgroundAudio.onUserPlaybackAction();
    final current = playbackState.value;
    playbackState.add(current.copyWith(
      playing: false,
      processingState: AudioProcessingState.ready,
      controls: [
        for (final c in current.controls)
          if (c == MediaControl.pause) MediaControl.play else c,
      ],
    ));
    await _source?.pause();
  }

  @override
  Future<void> stop() async {
    BackgroundAudio.onUserPlaybackAction();
    await _source?.stop();
    clear();
  }

  @override
  Future<void> skipToNext() async {
    final current = playbackState.value;
    playbackState.add(current.copyWith(
      processingState: AudioProcessingState.buffering,
      updatePosition: Duration.zero,
    ));
    await _source?.skipToNext();
  }

  @override
  Future<void> skipToPrevious() async {
    final current = playbackState.value;
    playbackState.add(current.copyWith(
      processingState: AudioProcessingState.buffering,
      updatePosition: Duration.zero,
    ));
    await _source?.skipToPrevious();
  }

  @override
  Future<void> seek(Duration position) async => _source?.seek(position);
}
