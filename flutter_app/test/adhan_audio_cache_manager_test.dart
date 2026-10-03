import 'dart:io';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/models/adhan_sound.dart';
import 'package:flutter_app/services/adhan_audio_cache_manager.dart';
import 'package:flutter_app/services/update/update_downloader.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/flaky_http_server.dart';

/// تنزيل أصوات الأذان أمام شبكة سيئة، وأيّ ملف يُشغَّل لأي صلاة.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final cache = AdhanAudioCacheManager.instance;
  late FlakyHttpServer server;
  late Directory dir;
  late Directory legacyDir;
  late Uint8List regularBytes;
  late Uint8List fajrBytes;
  late AdhanSound plain; // تسجيل بلا «الصلاة خير من النوم»
  late AdhanSound withFajr; // تسجيل فجر: له ملفان

  UpdateDownloader fastDownloader() => UpdateDownloader(
        dir: dir,
        sleep: (_) => Future<void>.delayed(const Duration(milliseconds: 5)),
        connectTimeout: const Duration(seconds: 2),
        idleTimeout: const Duration(milliseconds: 400),
        backoffBase: const Duration(milliseconds: 10),
        tickInterval: Duration.zero,
      );

  Future<void> configure() => cache.debugConfigure(
        dir: dir,
        legacyDir: legacyDir,
        downloader: fastDownloader(),
        catalog: [plain, withFajr],
      );

  String localPath(String url) => '${dir.path}${Platform.pathSeparator}${Uri.parse(url).pathSegments.last}';

  setUp(() async {
    HttpOverrides.global = null; // مقابس حقيقية على الجهاز نفسه
    SharedPreferences.setMockInitialValues({});
    server = FlakyHttpServer();
    await server.start();
    final root = Directory.systemTemp.createTempSync('mihrab_adhan_test');
    dir = Directory('${root.path}${Platform.pathSeparator}v2');
    legacyDir = Directory('${root.path}${Platform.pathSeparator}adhan_audio')..createSync(recursive: true);

    regularBytes = pseudoRandomBytes(300 * 1024, seed: 3);
    fajrBytes = pseudoRandomBytes(360 * 1024, seed: 5);
    server.serve('/plain-r-aaaa.mp3', regularBytes);
    server.serve('/dawn-r-bbbb.mp3', regularBytes);
    server.serve('/dawn-f-cccc.mp3', fajrBytes);

    plain = AdhanSound(
      id: 'plain',
      title: 'مؤذن بتسجيل عادي',
      category: 'اختبار',
      muezzinOrLocation: 'اختبار',
      audioUrl: server.url('/plain-r-aaaa.mp3'),
      audioBytes: regularBytes.length,
      audioSha256: sha256.convert(regularBytes).toString(),
      durationSeconds: 150,
    );
    withFajr = AdhanSound(
      id: 'dawn',
      title: 'مؤذن بتسجيل فجر',
      category: 'اختبار',
      muezzinOrLocation: 'اختبار',
      audioUrl: server.url('/dawn-r-bbbb.mp3'),
      audioBytes: regularBytes.length,
      audioSha256: sha256.convert(regularBytes).toString(),
      fajrUrl: server.url('/dawn-f-cccc.mp3'),
      fajrBytes: fajrBytes.length,
      fajrSha256: sha256.convert(fajrBytes).toString(),
      durationSeconds: 150,
    );
    await configure();
  });

  tearDown(() async {
    cache.dispose();
    cache.onSoundReady = null;
    await server.stop();
    try {
      dir.parent.deleteSync(recursive: true);
    } catch (_) {}
  });

  test('اتصال ينقطع في منتصف الملف: يكمل من حيث وقف ولا يفشل', () async {
    server.plan.addAll(const [
      Reply(cutAfter: 90 * 1024),
      Reply(status: 503),
      Reply(cutAfter: 60 * 1024),
    ]);

    expect(cache.isSoundDownloaded('plain'), isFalse);
    final ok = await cache.downloadSound(sound: plain);

    expect(ok, isTrue);
    expect(cache.isSoundDownloaded('plain'), isTrue);
    expect(File(localPath(plain.audioUrl)).readAsBytesSync(), regularBytes);
    // المحاولة التي تلت الانقطاع طلبت الباقي فقط، لا الملف من أوله
    expect(server.requests.any((r) => r.range == 'bytes=${90 * 1024}-'), isTrue);
    expect(cache.activeDownloadingIdsNotifier.value, isEmpty);
    expect(cache.downloadProgressNotifier.value, isEmpty);
  });

  test('تسجيل بلا جملة الفجر: ملف واحد يُؤذَّن به لكل الصلوات', () async {
    await cache.downloadSound(sound: plain);

    expect(cache.nativePath(plain, fajr: false), localPath(plain.audioUrl));
    expect(cache.nativePath(plain, fajr: true), isNull);
    final dhuhr = cache.sourceFor(plain) as DeviceFileSource;
    final fajr = cache.sourceFor(plain, fajr: true) as DeviceFileSource;
    expect(fajr.path, dhuhr.path);
  });

  test('تسجيل فجر: الملف العادي للصلوات الأربع وملف الفجر للفجر وحده', () async {
    final ready = <String>[];
    cache.onSoundReady = ready.add;

    expect(await cache.downloadSound(sound: withFajr), isTrue);

    expect(ready, ['dawn']);
    expect(File(localPath(withFajr.fajrUrl!)).readAsBytesSync(), fajrBytes);
    expect(cache.nativePath(withFajr, fajr: false), localPath(withFajr.audioUrl));
    expect(cache.nativePath(withFajr, fajr: true), localPath(withFajr.fajrUrl!));
    expect((cache.sourceFor(withFajr) as DeviceFileSource).path, localPath(withFajr.audioUrl));
    expect((cache.sourceFor(withFajr, fajr: true) as DeviceFileSource).path, localPath(withFajr.fajrUrl!));
  });

  test('صوت بملفين لا يُعدّ محمّلاً حتى يكتمل الاثنان', () async {
    File(localPath(withFajr.audioUrl))
      ..createSync(recursive: true)
      ..writeAsBytesSync(regularBytes);
    await cache.refreshDownloadedCache();

    expect(cache.isSoundDownloaded('dawn'), isFalse);
    // الملف العادي جاهز فيُؤذَّن به ريثما يصل ملف الفجر
    expect(cache.nativePath(withFajr, fajr: false), isNotNull);
    expect(cache.nativePath(withFajr, fajr: true), isNull);
  });

  test('قبل التحميل: المعاينة مقطع مضمَّن في التطبيق لا بثّ من الشبكة', () {
    final preview = cache.previewSource(plain);

    expect(preview, isA<AssetSource>());
    expect((preview as AssetSource).path, 'audio/previews/plain.mp3');
    expect(cache.sourceFor(plain), isNull);
  });

  test('بعد التحميل: المعاينة هي الأذان العادي كاملاً من الجهاز', () async {
    await cache.downloadSound(sound: withFajr);

    final preview = cache.previewSource(withFajr);
    expect((preview as DeviceFileSource).path, localPath(withFajr.audioUrl));
  });

  test('أُغلق التطبيق والتنزيل جارٍ: يُستكمل عند الفتح التالي بلا طلب جديد', () async {
    server.plan.add(const Reply(stallAfter: 120 * 1024));
    final first = cache.downloadSound(sound: plain);
    await _until(() => File('${localPath(plain.audioUrl)}.part').existsSync() &&
        File('${localPath(plain.audioUrl)}.part').lengthSync() >= 120 * 1024);

    cache.dispose(); // «إغلاق التطبيق»
    expect(await first, isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList(AdhanAudioCacheManager.pendingQueuePrefKey), ['plain']);

    final ready = <String>[];
    cache.onSoundReady = ready.add;
    await configure(); // «فتح التطبيق»
    await _until(() => ready.isNotEmpty);

    expect(cache.isSoundDownloaded('plain'), isTrue);
    expect(File(localPath(plain.audioUrl)).readAsBytesSync(), regularBytes);
    expect(server.requests.last.range, 'bytes=${120 * 1024}-');
    expect(prefs.getStringList(AdhanAudioCacheManager.pendingQueuePrefKey), isEmpty);
  });

  test('تسجيل قديم (قبل 1.0.11): يبقى مستعملاً ثم يُستبدل بصمت بالملفين الجديدين', () async {
    cache.dispose();
    final legacy = File('${legacyDir.path}${Platform.pathSeparator}dawn.mp3')
      ..writeAsBytesSync(pseudoRandomBytes(200 * 1024, seed: 9));
    // يُمسك الخادم التنزيل ليُرى ما قبل اكتماله
    server.plan.add(const Reply(stallAfter: 10 * 1024));
    final ready = <String>[];
    cache.onSoundReady = ready.add;
    await configure();

    // ما دام الجديد لم يصل: القديم محسوب محمّلاً ويُؤذَّن به، ولا يظهر «جارٍ التحميل»
    expect(cache.isSoundDownloaded('dawn'), isTrue);
    expect(cache.nativePath(withFajr, fajr: false), legacy.path);
    expect(cache.nativePath(withFajr, fajr: true), isNull);
    expect(cache.activeDownloadingIdsNotifier.value, isEmpty);

    await _until(() => ready.isNotEmpty);

    expect(cache.isSoundDownloaded('dawn'), isTrue);
    expect(cache.nativePath(withFajr, fajr: false), localPath(withFajr.audioUrl));
    expect(cache.nativePath(withFajr, fajr: true), localPath(withFajr.fajrUrl!));
    // القديم يبقى إلى التشغيل التالي (مسار محفوظ قد يشير إليه)، ثم يُحذف
    expect(legacy.existsSync(), isTrue);
    await configure();
    expect(legacy.existsSync(), isFalse);
    expect(cache.nativePath(withFajr, fajr: false), localPath(withFajr.audioUrl));
  });

  test('نسخة الأذان الافتراضي المستخرجة قديماً تُحذف عند التهيئة', () async {
    cache.dispose();
    final oldDefault = File(
      '${legacyDir.path}${Platform.pathSeparator}${AdhanAudioCacheManager.defaultSoundId}.mp3',
    )..writeAsBytesSync(pseudoRandomBytes(200 * 1024));
    final leftover = File('${legacyDir.path}${Platform.pathSeparator}plain.tmp')..writeAsBytesSync([1, 2, 3]);

    await configure();

    expect(oldDefault.existsSync(), isFalse);
    expect(leftover.existsSync(), isFalse);
  });

  test('ملف على الخادم يخالف بصمة الكتالوج: لا يُعتمد', () async {
    server.serve('/plain-r-aaaa.mp3', pseudoRandomBytes(regularBytes.length, seed: 99));

    expect(await cache.downloadSound(sound: plain), isFalse);

    expect(cache.isSoundDownloaded('plain'), isFalse);
    expect(File(localPath(plain.audioUrl)).existsSync(), isFalse);
    expect(cache.activeDownloadingIdsNotifier.value, isEmpty);
  });

  test('طلبان معاً: ينزلان واحداً بعد الآخر ويكتملان', () async {
    final results = await Future.wait([
      cache.downloadSound(sound: withFajr),
      cache.downloadSound(sound: plain),
      cache.downloadSound(sound: plain), // ضغطة ثانية على الزر نفسه
    ]);

    expect(results, [true, true, true]);
    expect(cache.downloadedSoundIdsNotifier.value, containsAll(['plain', 'dawn']));
    // ثلاثة ملفات، كل واحد طُلب مرة واحدة
    expect(server.requests.map((r) => r.path).toList()..sort(),
        ['/dawn-f-cccc.mp3', '/dawn-r-bbbb.mp3', '/plain-r-aaaa.mp3']);
  });
}

Future<void> _until(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 20));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) fail('لم يتحقق الشرط خلال 20 ثانية');
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}
