import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/services/update/update_downloader.dart';
import 'package:flutter_app/services/update/update_models.dart';

import 'support/flaky_http_server.dart';

/// محرك تنزيل التحديث أمام شبكة سيئة: انقطاع، صمت، أخطاء خادم، ملف يتبدل.
/// المطلوب في كل حالة: لا فشل، والملف النهائي مطابق بايتاً ببايت.
void main() {
  late FlakyHttpServer server;
  late FlakyHttpServer mirror;
  late Directory dir;
  late Uint8List apk;

  UpdateJob jobFor(List<String> urls, {Uint8List? content, int? size, String? hash}) {
    final body = content ?? apk;
    return UpdateJob(
      platform: 'android',
      info: UpdateInfo(
        version: '1.0.10',
        releaseNotes: '',
        publishedAt: DateTime(2026),
        android: UpdateAsset(
          urls: urls,
          size: size ?? body.length,
          sha256: hash ?? sha256.convert(body).toString(),
        ),
      ),
    );
  }

  /// انتظار فوري ومهل قصيرة: الاختبار يجري في ثوانٍ لا دقائق.
  UpdateDownloader downloader({Duration idle = const Duration(milliseconds: 400)}) => UpdateDownloader(
        dir: dir,
        sleep: (_) => Future<void>.delayed(const Duration(milliseconds: 5)),
        connectTimeout: const Duration(seconds: 2),
        idleTimeout: idle,
        backoffBase: const Duration(milliseconds: 10),
        tickInterval: Duration.zero,
      );

  bool keepGoing(UpdateProgress _) => true;

  setUp(() async {
    HttpOverrides.global = null; // مقابس حقيقية على الجهاز نفسه
    server = FlakyHttpServer();
    mirror = FlakyHttpServer();
    await server.start();
    await mirror.start();
    dir = Directory.systemTemp.createTempSync('mihrab_update_test');
    apk = pseudoRandomBytes(600 * 1024);
    server.serve('/app.apk', apk);
    mirror.serve('/app.apk', apk);
  });

  tearDown(() async {
    await server.stop();
    await mirror.stop();
    try {
      dir.deleteSync(recursive: true);
    } catch (_) {}
  });

  test('ينزّل الملف كاملاً ويتحقق من بصمته', () async {
    final job = jobFor([server.url('/app.apk')]);
    final d = downloader();

    final file = await d.run(job, onTick: keepGoing);

    expect(file!.path, d.finalFile(job).path);
    expect(file.readAsBytesSync(), apk);
    expect(d.partFile(job).existsSync(), isFalse);
    expect(server.requests.length, 1);
  });

  test('انقطاع الاتصال خمس مرات في منتصف الملف: يكمل كل مرة من آخر بايت', () async {
    server.plan.addAll(const [
      Reply(cutAfter: 50 * 1024),
      Reply(cutAfter: 120 * 1024),
      Reply(cutAfter: 1),
      Reply(cutAfter: 200 * 1024),
      Reply(cutAfter: 64 * 1024),
    ]);
    final job = jobFor([server.url('/app.apk')]);

    final file = await downloader().run(job, onTick: keepGoing);

    expect(file!.readAsBytesSync(), apk);
    // كل محاولة بعد الأولى طلبت ما بقي فقط، لا الملف من أوله
    final ranges = server.requests.map((r) => r.range).toList();
    expect(ranges.first, isNull);
    expect(ranges.skip(1), everyElement(startsWith('bytes=')));
    final offsets = ranges.skip(1).map((r) => int.parse(r!.substring(6, r.length - 1))).toList();
    for (var i = 1; i < offsets.length; i++) {
      expect(offsets[i], greaterThan(offsets[i - 1]));
    }
  });

  test('لا اتصال إطلاقاً عند البدء: ينتظر ولا يفشل، ويكمل حين يعود الخادم', () async {
    final port = server.port;
    await server.stop();
    final job = jobFor(['http://127.0.0.1:$port/app.apk']);

    final phases = <UpdatePhase>{};
    var ticks = 0;
    final file = await downloader().run(job, onTick: (p) {
      phases.add(p.phase);
      // بعد عدة محاولات فاشلة يعود الخادم
      if (++ticks == 12) server.start(onPort: port);
      return true;
    });

    expect(phases, contains(UpdatePhase.waiting));
    expect(file!.readAsBytesSync(), apk);
  });

  test('الخادم يصمت في منتصف الملف والاتصال مفتوح: يعيد الاتصال ويكمل', () async {
    server.plan.add(const Reply(stallAfter: 90 * 1024));
    final job = jobFor([server.url('/app.apk')]);

    final file = await downloader(idle: const Duration(milliseconds: 250)).run(job, onTick: keepGoing);

    expect(file!.readAsBytesSync(), apk);
    expect(server.requests.length, 2);
    expect(server.requests[1].range, startsWith('bytes='));
  });

  test('أخطاء خادم عابرة (503، 500) لا تُفشل التنزيل', () async {
    server.plan.addAll(const [Reply(status: 503), Reply(status: 500), Reply(cutAfter: 10 * 1024), Reply(status: 502)]);
    final job = jobFor([server.url('/app.apk')]);

    final file = await downloader().run(job, onTick: keepGoing);

    expect(file!.readAsBytesSync(), apk);
  });

  test('الرابط الأول 404: ينتقل إلى الاحتياطي', () async {
    server.files.clear();
    final job = jobFor([server.url('/app.apk'), mirror.url('/app.apk')]);

    final file = await downloader().run(job, onTick: keepGoing);

    expect(file!.readAsBytesSync(), apk);
    expect(mirror.requests, isNotEmpty);
  });

  test('الرابط الأول يخدم إصداراً أقدم بحجم آخر: يُرفض قبل كتابة أي بايت', () async {
    server.serve('/app.apk', pseudoRandomBytes(500 * 1024, seed: 99));
    final job = jobFor([server.url('/app.apk'), mirror.url('/app.apk')]);
    final d = downloader();

    final file = await d.run(job, onTick: keepGoing);

    expect(file!.readAsBytesSync(), apk);
    expect(server.requests.length, 1);
  });

  test('انقطاع عند الأول ثم إكمال من الاحتياطي: الجزء المنزَّل يُكمَل ولا يُعاد', () async {
    // ثلاث محاولات فاشلة متتالية بلا تقدم تنقل إلى الرابط التالي
    server.plan.addAll(const [Reply(cutAfter: 150 * 1024), Reply(status: 503), Reply(status: 503), Reply(status: 503)]);
    final job = jobFor([server.url('/app.apk'), mirror.url('/app.apk')]);

    final file = await downloader().run(job, onTick: keepGoing);

    expect(file!.readAsBytesSync(), apk);
    expect(mirror.requests.first.range, 'bytes=${150 * 1024}-');
  });

  test('الملف تبدّل على الخادم بين محاولتين (ETag آخر): لا يُلصق جديد بقديم', () async {
    // أول اتصال يخدم ملفاً آخر بالحجم نفسه ثم ينقطع؛ بعدها يُنشر الملف الصحيح
    final other = pseudoRandomBytes(apk.length, seed: 1234);
    server.serve('/app.apk', other, etag: '"old"');
    server.plan.add(const Reply(cutAfter: 100 * 1024));
    final job = jobFor([server.url('/app.apk')]);

    var swapped = false;
    final file = await downloader().run(job, onTick: (p) {
      if (!swapped && server.requests.length == 1 && p.received >= 100 * 1024) {
        server.serve('/app.apk', apk, etag: '"new"');
        swapped = true;
      }
      return true;
    });

    expect(swapped, isTrue);
    expect(file!.readAsBytesSync(), apk);
  });

  test('كل الروابط تخدم ملفاً ببصمة أخرى: يبلّغ أن وصف الإصدار قديم ولا يسلّم ملفاً تالفاً', () async {
    final job = jobFor([server.url('/app.apk'), mirror.url('/app.apk')], hash: 'a' * 64);
    final d = downloader();

    await expectLater(d.run(job, onTick: keepGoing), throwsA(isA<UpdateContentMismatch>()));
    expect(d.finalFile(job).existsSync(), isFalse);
    expect(d.partFile(job).existsSync(), isFalse);
  });

  test('كل الروابط تخدم حجماً آخر: يبلّغ بلا تنزيل', () async {
    final job = jobFor([server.url('/app.apk'), mirror.url('/app.apk')], size: apk.length + 5);

    await expectLater(downloader().run(job, onTick: keepGoing), throwsA(isA<UpdateContentMismatch>()));
  });

  test('الإيقاف يحفظ ما نزل، والتشغيل التالي يكمل منه (كما بعد إعادة تشغيل الهاتف)', () async {
    final job = jobFor([server.url('/app.apk')]);
    final d = downloader();

    final stopped = await d.run(job, onTick: (p) => p.received < 200 * 1024);
    expect(stopped, isNull);
    final kept = d.partFile(job).lengthSync();
    expect(kept, greaterThanOrEqualTo(200 * 1024));
    expect(kept, lessThan(apk.length));

    // محرك جديد تماماً على المجلد نفسه
    final file = await downloader().run(job, onTick: keepGoing);
    expect(file!.readAsBytesSync(), apk);
    expect(server.requests.last.range, 'bytes=$kept-');
  });

  test('خادم يتجاهل Range ويرسل الملف من أوله: يبدأ من الصفر بلا تكرار بايتات', () async {
    server.plan.addAll(const [Reply(cutAfter: 100 * 1024), Reply(ignoreRange: true)]);
    final job = jobFor([server.url('/app.apk')]);

    final file = await downloader().run(job, onTick: keepGoing);

    expect(file!.lengthSync(), apk.length);
    expect(file.readAsBytesSync(), apk);
  });

  test('التحويل (302) يحمل ترويسة المدى إلى الوجهة', () async {
    server.serve('/real.apk', apk);
    server.files.remove('/app.apk');
    server.plan.addAll([
      Reply(redirectTo: server.url('/real.apk')),
      const Reply(cutAfter: 80 * 1024),
      Reply(redirectTo: server.url('/real.apk')),
    ]);
    final job = jobFor([server.url('/app.apk')]);

    final file = await downloader().run(job, onTick: keepGoing);

    expect(file!.readAsBytesSync(), apk);
    final resumed = server.requests.lastWhere((r) => r.path == '/real.apk');
    expect(resumed.range, 'bytes=${80 * 1024}-');
  });

  test('ملف مكتمل من قبل: يعاد فوراً بلا شبكة', () async {
    final job = jobFor([server.url('/app.apk')]);
    final d = downloader();
    d.finalFile(job).writeAsBytesSync(apk);

    final file = await d.run(job, onTick: keepGoing);

    expect(file!.path, d.finalFile(job).path);
    expect(server.requests, isEmpty);
  });

  test('جزء أكبر من حجم الملف (تالف): يُرمى ويُنزَّل من جديد', () async {
    final job = jobFor([server.url('/app.apk')]);
    final d = downloader();
    d.partFile(job).writeAsBytesSync(Uint8List(apk.length + 10));

    final file = await d.run(job, onTick: keepGoing);

    expect(file!.readAsBytesSync(), apk);
  });

  test('جزء مكتمل الحجم لكنه تالف: يُكتشف بالبصمة ويُعاد تنزيله', () async {
    final job = jobFor([server.url('/app.apk')]);
    final d = downloader();
    d.partFile(job).writeAsBytesSync(pseudoRandomBytes(apk.length, seed: 5));

    final file = await d.run(job, onTick: keepGoing);

    expect(file!.readAsBytesSync(), apk);
  });

  test('النبضة تبلّغ التقدم تصاعدياً حتى الحجم الكامل', () async {
    final job = jobFor([server.url('/app.apk')]);
    final seen = <int>[];

    await downloader().run(job, onTick: (p) {
      if (p.phase == UpdatePhase.downloading) seen.add(p.received);
      expect(p.total, apk.length);
      return true;
    });

    expect(seen.length, greaterThan(2));
    for (var i = 1; i < seen.length; i++) {
      expect(seen[i], greaterThanOrEqualTo(seen[i - 1]));
    }
  });
}
