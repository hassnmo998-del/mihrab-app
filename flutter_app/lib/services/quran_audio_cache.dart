import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../models/quran_reciter.dart';

/// Disk cache for ayah recitations, so sequential playback doesn't stall on the
/// network before every ayah and anything heard before replays instantly.
///
/// Files live in `<app cache>/quran_audio/<reciterId>/SSSAAA.mp3`. Downloads write to a
/// `.part` file then rename, so a half-written file is never played. At most
/// [_maxConcurrent] downloads run at once, and the oldest files are evicted past
/// [_maxBytes].
class QuranAudioCache {
  QuranAudioCache._();
  static final QuranAudioCache instance = QuranAudioCache._();

  static const int _maxConcurrent = 2;
  static const int _maxBytes = 300 * 1024 * 1024;
  static const Duration _trimInterval = Duration(minutes: 5);

  Directory? _root;
  final Map<String, Future<String?>> _inFlight = {};
  final Queue<_Job> _pending = Queue<_Job>();
  int _running = 0;
  DateTime _lastTrim = DateTime.fromMillisecondsSinceEpoch(0);

  /// Test hooks: a fake HTTP client and a temp folder instead of the app cache.
  @visibleForTesting
  http.Client? clientOverride;

  @visibleForTesting
  void setRootForTesting(Directory? dir) => _root = dir;

  /// Completes once every queued and running download has finished.
  @visibleForTesting
  Future<void> whenIdle() async {
    while (_running > 0 || _pending.isNotEmpty) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  }

  /// Relative cache key of one ayah for one reciter.
  @visibleForTesting
  static String keyOf(QuranReciter reciter, int surah, int ayah) =>
      '${reciter.id}/${surah.toString().padLeft(3, '0')}${ayah.toString().padLeft(3, '0')}.mp3';

  Future<Directory?> _dir() async {
    if (_root != null) return _root;
    try {
      final base = await getApplicationCacheDirectory();
      _root = Directory('${base.path}${Platform.pathSeparator}quran_audio');
      await _root!.create(recursive: true);
    } catch (e) {
      debugPrint('⚠️ QuranAudioCache unavailable: $e');
      _root = null;
    }
    return _root;
  }

  File _fileFor(Directory root, String key) =>
      File('${root.path}${Platform.pathSeparator}${key.replaceAll('/', Platform.pathSeparator)}');

  /// Local path of an already-downloaded ayah, or null. Never touches the network.
  Future<String?> cachedPath(QuranReciter reciter, int surah, int ayah) async {
    final root = await _dir();
    if (root == null) return null;
    final file = _fileFor(root, keyOf(reciter, surah, ayah));
    try {
      if (file.existsSync() && file.lengthSync() > 0) {
        // Mark as recently used for eviction.
        unawaited(file.setLastModified(DateTime.now()).catchError((_) {}));
        return file.path;
      }
    } catch (_) {}
    return null;
  }

  /// Queues background downloads for these ayahs, most important first.
  /// Replaces the previous not-yet-started requests (the listener moved on);
  /// downloads already running are left to finish.
  void prefetch(QuranReciter reciter, List<(int, int)> ayahs) {
    _pending.clear();
    for (final (surah, ayah) in ayahs) {
      _pending.add(_Job(reciter, surah, ayah));
    }
    _pump();
  }

  void _pump() {
    while (_running < _maxConcurrent && _pending.isNotEmpty) {
      final job = _pending.removeFirst();
      _running++;
      _download(job.reciter, job.surah, job.ayah).whenComplete(() {
        _running--;
        _pump();
      });
    }
  }

  /// Downloads one ayah if missing. Concurrent requests for the same ayah share one download.
  Future<String?> _download(QuranReciter reciter, int surah, int ayah) {
    final key = keyOf(reciter, surah, ayah);
    // Block body on purpose: `=> _inFlight.remove(key)` would return this very future,
    // and whenComplete would then wait on itself forever.
    return _inFlight[key] ??= _fetch(reciter, surah, ayah, key).whenComplete(() {
      _inFlight.remove(key);
    });
  }

  Future<String?> _fetch(QuranReciter reciter, int surah, int ayah, String key) async {
    final existing = await cachedPath(reciter, surah, ayah);
    if (existing != null) return existing;

    final root = await _dir();
    if (root == null) return null;
    final target = _fileFor(root, key);
    final partial = File('${target.path}.part');

    try {
      await target.parent.create(recursive: true);
      final uri = Uri.parse(reciter.getAyahAudioUrl(surah, ayah));
      final response = await (clientOverride?.get(uri) ?? http.get(uri))
          .timeout(const Duration(seconds: 30));
      if (response.statusCode != 200 || response.bodyBytes.isEmpty) return null;
      await partial.writeAsBytes(response.bodyBytes, flush: true);
      if (target.existsSync()) await target.delete();
      await partial.rename(target.path);
      _maybeTrim(root);
      return target.path;
    } catch (e) {
      debugPrint('⚠️ QuranAudioCache download failed for $key: $e');
      try {
        if (partial.existsSync()) await partial.delete();
      } catch (_) {}
      return null;
    }
  }

  void _maybeTrim(Directory root) {
    final now = DateTime.now();
    if (now.difference(_lastTrim) < _trimInterval) return;
    _lastTrim = now;
    unawaited(_trim(root));
  }

  /// Deletes least-recently-used files until the cache is under [_maxBytes].
  Future<void> _trim(Directory root) async {
    try {
      final files = <File>[];
      var total = 0;
      await for (final entity in root.list(recursive: true)) {
        if (entity is File && entity.path.endsWith('.mp3')) {
          files.add(entity);
          total += await entity.length();
        }
      }
      if (total <= _maxBytes) return;
      final stats = {for (final f in files) f: await f.lastModified()};
      files.sort((a, b) => stats[a]!.compareTo(stats[b]!));
      for (final f in files) {
        if (total <= _maxBytes) break;
        final size = await f.length();
        await f.delete();
        total -= size;
      }
    } catch (e) {
      debugPrint('⚠️ QuranAudioCache trim failed: $e');
    }
  }
}

class _Job {
  final QuranReciter reciter;
  final int surah;
  final int ayah;
  const _Job(this.reciter, this.surah, this.ayah);
}
