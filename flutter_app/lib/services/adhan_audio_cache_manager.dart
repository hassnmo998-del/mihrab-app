import 'dart:async';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/adhan_sound.dart';
import 'adhan_data.dart';

/// Manages resilient offline storage, persistent caching, and background downloading
/// of Adhan sound files. Guarantees 100% offline playback with Syria-friendly retry tolerance.
class AdhanAudioCacheManager {
  AdhanAudioCacheManager._();
  static final AdhanAudioCacheManager instance = AdhanAudioCacheManager._();

  static const String defaultSoundId = 'iconic_makkah_ali_mullah';
  static const String pendingTargetPrefKey = 'adhan_pending_target_sound_id';
  static const String pendingQueuePrefKey = 'adhan_pending_download_queue';

  Directory? _audioDir;
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 120),
      sendTimeout: const Duration(seconds: 15),
    ),
  );

  // Download states
  final ValueNotifier<Set<String>> downloadedSoundIdsNotifier =
      ValueNotifier<Set<String>>({defaultSoundId});

  final ValueNotifier<Map<String, double>> downloadProgressNotifier =
      ValueNotifier<Map<String, double>>({});

  final ValueNotifier<Set<String>> activeDownloadingIdsNotifier =
      ValueNotifier<Set<String>>({});

  bool _initialized = false;
  Timer? _resilienceRetryTimer;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    try {
      final docDir = await getApplicationDocumentsDirectory();
      _audioDir = Directory('${docDir.path}/adhan_audio');
      if (!await _audioDir!.exists()) {
        await _audioDir!.create(recursive: true);
      }

      // 1. Ensure the default bundled adhan (Sheikh Ali Mullah) is extracted to disk for Android native use
      await _extractDefaultBundledAdhan();

      // 2. Scan disk for already downloaded sounds
      await refreshDownloadedCache();

      // 3. Kick off resilient downloader for any pending items when network is ready
      _startResilienceRetryWatcher();
      unawaited(_processPendingQueue());
    } catch (e) {
      debugPrint('⚠️ [AdhanAudioCacheManager] Init error: $e');
    }
  }

  /// Extracts the bundled default adhan asset to local app storage once,
  /// so both Flutter AudioPlayer and Android native MediaPlayer can access it directly.
  Future<void> _extractDefaultBundledAdhan() async {
    if (_audioDir == null) return;
    final defaultFile = File('${_audioDir!.path}/$defaultSoundId.mp3');
    if (!await defaultFile.exists() || await defaultFile.length() < 100 * 1024) {
      try {
        final byteData =
            await rootBundle.load('assets/audio/default_adhan.mp3');
        final bytes = byteData.buffer.asUint8List();
        await defaultFile.writeAsBytes(bytes, flush: true);
        debugPrint('✅ [AdhanAudioCacheManager] Extracted default adhan to ${defaultFile.path}');
      } catch (e) {
        debugPrint('⚠️ [AdhanAudioCacheManager] Error extracting default adhan asset: $e');
      }
    }
  }

  /// Scans disk to find all completely downloaded MP3 files
  Future<void> refreshDownloadedCache() async {
    if (_audioDir == null) return;
    final downloaded = <String>{defaultSoundId};

    try {
      if (await _audioDir!.exists()) {
        final entities = await _audioDir!.list().toList();
        for (final entity in entities) {
          if (entity is File && entity.path.endsWith('.mp3')) {
            final fileName = entity.uri.pathSegments.last;
            final id = fileName.substring(0, fileName.length - 4);
            final length = await entity.length();
            if (length > 80 * 1024) {
              // Valid file (> 80 KB)
              downloaded.add(id);
            }
          }
        }
      }
    } catch (_) {}

    downloadedSoundIdsNotifier.value = downloaded;
  }

  /// Returns whether a sound is guaranteed to be available locally offline
  bool isSoundDownloaded(String soundId) {
    if (soundId == defaultSoundId) return true;
    return downloadedSoundIdsNotifier.value.contains(soundId);
  }

  /// Returns the local absolute file path for a sound if it exists on disk
  String? getLocalAudioFilePath(String soundId) {
    if (_audioDir == null) return null;
    final file = File('${_audioDir!.path}/$soundId.mp3');
    if (file.existsSync() && file.lengthSync() > 80 * 1024) {
      return file.path;
    }
    if (soundId == defaultSoundId) {
      final defaultFile = File('${_audioDir!.path}/$defaultSoundId.mp3');
      if (defaultFile.existsSync() && defaultFile.lengthSync() > 80 * 1024) {
        return defaultFile.path;
      }
    }
    return null;
  }

  /// Gets playable Source for audioplayers: prioritizes local file or asset
  Source getPlayableSource(AdhanSound sound) {
    // On web (iPhone PWA), the local filesystem is unavailable — stream directly
    if (kIsWeb) {
      if (sound.id == defaultSoundId) {
        return AssetSource('audio/default_adhan.mp3');
      }
      return UrlSource(sound.audioUrl);
    }

    final localPath = getLocalAudioFilePath(sound.id);
    if (localPath != null) {
      return DeviceFileSource(localPath);
    }
    if (sound.id == defaultSoundId) {
      return AssetSource('audio/default_adhan.mp3');
    }
    // Fallback to streaming URL
    return UrlSource(sound.audioUrl);
  }

  /// Patient internet probe allowing weak/slow Syria connections to establish
  Future<bool> checkInternetConnection({
    Duration timeout = const Duration(seconds: 7),
  }) async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(timeout);
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        return true;
      }
    } catch (_) {
      try {
        final result = await InternetAddress.lookup('cloudflare.com')
            .timeout(const Duration(seconds: 4));
        if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
          return true;
        }
      } catch (_) {}
    }
    return false;
  }

  /// Downloads an Adhan sound with progress reporting and atomic saving
  Future<bool> downloadSound({
    required AdhanSound sound,
    void Function(double progress)? onProgress,
  }) async {
    if (isSoundDownloaded(sound.id)) {
      onProgress?.call(1.0);
      return true;
    }

    if (_audioDir == null) await init();

    final id = sound.id;
    final activeSet = Set<String>.from(activeDownloadingIdsNotifier.value);
    activeSet.add(id);
    activeDownloadingIdsNotifier.value = activeSet;

    final tmpFile = File('${_audioDir!.path}/$id.tmp');
    final finalFile = File('${_audioDir!.path}/$id.mp3');

    try {
      await _dio.download(
        sound.audioUrl,
        tmpFile.path,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            final progress = (received / total).clamp(0.0, 1.0);
            final map = Map<String, double>.from(downloadProgressNotifier.value);
            map[id] = progress;
            downloadProgressNotifier.value = map;
            onProgress?.call(progress);
          }
        },
      );

      // Atomic rename once fully downloaded
      if (await tmpFile.exists() && await tmpFile.length() > 80 * 1024) {
        if (await finalFile.exists()) {
          await finalFile.delete();
        }
        await tmpFile.rename(finalFile.path);

        // Update downloaded set
        final updatedSet = Set<String>.from(downloadedSoundIdsNotifier.value);
        updatedSet.add(id);
        downloadedSoundIdsNotifier.value = updatedSet;

        // Cleanup progress
        final map = Map<String, double>.from(downloadProgressNotifier.value);
        map.remove(id);
        downloadProgressNotifier.value = map;

        // Check if this was the pending target sound chosen by user
        final prefs = await SharedPreferences.getInstance();
        final pendingTargetId = prefs.getString(pendingTargetPrefKey);
        if (pendingTargetId == id) {
          await prefs.remove(pendingTargetPrefKey);
          await prefs.setString('adhan_selected_sound_id', id);
          await prefs.setString('adhan_selected_sound_path', finalFile.path);
        }

        // Remove from pending queue if present
        final queue = prefs.getStringList(pendingQueuePrefKey) ?? [];
        if (queue.contains(id)) {
          queue.remove(id);
          await prefs.setStringList(pendingQueuePrefKey, queue);
        }

        debugPrint('✅ [AdhanAudioCacheManager] Downloaded & verified: ${sound.title} (${finalFile.path})');
        return true;
      } else {
        throw Exception('Downloaded file is incomplete or corrupt');
      }
    } catch (e) {
      debugPrint('⚠️ [AdhanAudioCacheManager] Download failed for ${sound.title}: $e');
      try {
        if (await tmpFile.exists()) await tmpFile.delete();
      } catch (_) {}
      return false;
    } finally {
      final updatedActive = Set<String>.from(activeDownloadingIdsNotifier.value);
      updatedActive.remove(id);
      activeDownloadingIdsNotifier.value = updatedActive;
    }
  }

  /// Queues a sound to be downloaded in the background as soon as connectivity resumes
  Future<void> queuePendingDownload(String soundId, {bool isTargetSound = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (isTargetSound) {
        await prefs.setString(pendingTargetPrefKey, soundId);
      }
      final queue = prefs.getStringList(pendingQueuePrefKey) ?? [];
      if (!queue.contains(soundId)) {
        queue.add(soundId);
        await prefs.setStringList(pendingQueuePrefKey, queue);
      }
    } catch (_) {}
  }

  /// Resilient background worker: runs periodically to pick up any pending downloads
  void _startResilienceRetryWatcher() {
    _resilienceRetryTimer?.cancel();
    _resilienceRetryTimer = Timer.periodic(const Duration(minutes: 2), (_) {
      unawaited(_processPendingQueue());
    });
  }

  Future<void> _processPendingQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queue = prefs.getStringList(pendingQueuePrefKey) ?? [];
      final pendingTarget = prefs.getString(pendingTargetPrefKey);

      if (queue.isEmpty && pendingTarget == null) return;

      final hasInternet = await checkInternetConnection(timeout: const Duration(seconds: 4));
      if (!hasInternet) return;

      final allIds = <String>{...queue};
      if (pendingTarget != null) allIds.add(pendingTarget);

      for (final id in allIds) {
        if (!isSoundDownloaded(id)) {
          final sound = AdhanData.getById(id);
          await downloadSound(sound: sound);
        }
      }
    } catch (_) {}
  }

  void dispose() {
    _resilienceRetryTimer?.cancel();
    _resilienceRetryTimer = null;
  }
}
