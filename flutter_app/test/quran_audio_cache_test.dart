import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_app/models/quran_reciter.dart';
import 'package:flutter_app/services/quran_audio_cache.dart';

void main() {
  final reciter = QuranReciter.defaultReciters[0];
  final cache = QuranAudioCache.instance;
  late Directory root;
  late List<Uri> requests;

  setUp(() {
    root = Directory.systemTemp.createTempSync('quran_cache_test');
    cache.setRootForTesting(root);
    requests = [];
    cache.clientOverride = MockClient((req) async {
      requests.add(req.url);
      if (req.url.path.endsWith('404404.mp3')) return http.Response('', 404);
      return http.Response.bytes(List<int>.filled(2048, 7), 200);
    });
  });

  tearDown(() {
    cache.clientOverride = null;
    cache.setRootForTesting(null);
    root.deleteSync(recursive: true);
  });

  test('keyOf groups by reciter and pads surah/ayah like EveryAyah', () {
    expect(QuranAudioCache.keyOf(reciter, 2, 255), '${reciter.id}/002255.mp3');
  });

  test('prefetch downloads ayahs so the next play comes from disk', () async {
    expect(await cache.cachedPath(reciter, 1, 1), isNull);

    cache.prefetch(reciter, [(1, 1), (1, 2), (1, 3)]);
    await cache.whenIdle();

    for (final a in [1, 2, 3]) {
      final path = await cache.cachedPath(reciter, 1, a);
      expect(path, isNotNull);
      expect(File(path!).lengthSync(), 2048);
    }
    expect(requests.length, 3);
    // No half-written leftovers.
    expect(root.listSync(recursive: true).where((e) => e.path.endsWith('.part')), isEmpty);
  });

  test('already cached ayahs are never downloaded again', () async {
    cache.prefetch(reciter, [(1, 1)]);
    await cache.whenIdle();
    cache.prefetch(reciter, [(1, 1), (1, 1)]);
    await cache.whenIdle();
    expect(requests.length, 1);
  });

  test('a failed download leaves nothing behind', () async {
    cache.prefetch(reciter, [(404, 404)]);
    await cache.whenIdle();
    expect(await cache.cachedPath(reciter, 404, 404), isNull);
    expect(root.listSync(recursive: true).whereType<File>(), isEmpty);
  });
}
