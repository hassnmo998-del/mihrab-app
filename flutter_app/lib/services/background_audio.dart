import 'dart:async';
import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';

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
/// - On Android/iOS it runs a media service, so playback keeps going with the app in
///   the background or the screen locked, with notification and lock-screen controls.
///   On desktop audio already continues when the window is minimised; the handler
///   stays null and [publish]/[clear] do nothing.
class BackgroundAudio {
  BackgroundAudio._();

  static _AppAudioHandler? _handler;
  static Future<void>? _initializing;
  static BackgroundAudioSource? _owner;

  static bool get _supported => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  /// Starts the media service once, on first playback (not at app launch).
  static Future<void> _ensureInitialized() {
    if (!_supported || _handler != null) return Future.value();
    return _initializing ??= () async {
      try {
        _handler = await AudioService.init(
          builder: _AppAudioHandler.new,
          config: const AudioServiceConfig(
            androidNotificationChannelId: 'com.masjed.app.audio',
            androidNotificationChannelName: 'التلاوة والدروس',
            androidNotificationOngoing: true,
            androidStopForegroundOnPause: true,
            fastForwardInterval: Duration(seconds: 15),
            rewindInterval: Duration(seconds: 15),
          ),
        );
      } catch (e) {
        debugPrint('⚠️ BackgroundAudio init failed: $e');
      }
    }();
  }

  /// Makes [source] the one the system controls drive, stopping the previous owner
  /// (so a lesson and the Quran never play over each other).
  static Future<void> claim(BackgroundAudioSource source) async {
    final previous = _owner;
    _owner = source;
    if (previous != null && !identical(previous, source)) {
      await previous.stop();
    }
    final wasReady = _handler != null;
    await _ensureInitialized();
    // The first publish may have happened while the service was still starting.
    if (!wasReady && identical(_owner, source)) source.syncMediaSession();
  }

  /// Gives up the session if [source] still owns it (e.g. after it stopped).
  static void release(BackgroundAudioSource source) {
    if (!identical(_owner, source)) return;
    _owner = null;
    _handler?.clear();
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
        ? [MediaControl.rewind, playing ? MediaControl.pause : MediaControl.play, MediaControl.fastForward, MediaControl.stop]
        : [MediaControl.skipToPrevious, playing ? MediaControl.pause : MediaControl.play, MediaControl.skipToNext, MediaControl.stop];
    playbackState.add(PlaybackState(
      controls: controls,
      systemActions: {
        if (seekable) MediaAction.seek,
        MediaAction.playPause,
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
  Future<void> play() async => _source?.play();

  @override
  Future<void> pause() async => _source?.pause();

  @override
  Future<void> stop() async {
    await _source?.stop();
    clear();
  }

  @override
  Future<void> skipToNext() async => _source?.skipToNext();

  @override
  Future<void> skipToPrevious() async => _source?.skipToPrevious();

  @override
  Future<void> seek(Duration position) async => _source?.seek(position);
}
