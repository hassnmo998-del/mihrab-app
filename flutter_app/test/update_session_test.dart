import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/services/update/update_downloader.dart';
import 'package:flutter_app/services/update/update_feed.dart';
import 'package:flutter_app/services/update/update_models.dart';
import 'package:flutter_app/services/update/update_session.dart';

import 'support/flaky_http_server.dart';

class _FakeFeed extends UpdateFeed {
  UpdateInfo? latest;
  int calls = 0;

  @override
  Future<UpdateInfo> fetchLatest() async {
    calls++;
    final info = latest;
    if (info == null) throw const SocketException('offline');
    return info;
  }
}

/// جلسة التحديث فوق مجلد مشترك: طرف واحد ينزّل، والمهمة تبقى إلى أن تكتمل
/// مهما تبدّل من يعمل عليها (الواجهة، مهمة الخلفية، تشغيل جديد بعد إقلاع).
void main() {
  late FlakyHttpServer server;
  late Directory dir;
  late Uint8List apk;
  late _FakeFeed feed;

  UpdateInfo infoFor(String version, Uint8List body, String path, {String? hash}) => UpdateInfo(
        version: version,
        releaseNotes: 'ملاحظات $version',
        publishedAt: DateTime(2026),
        android: UpdateAsset(
          urls: [server.url(path)],
          size: body.length,
          sha256: hash ?? sha256.convert(body).toString(),
        ),
      );

  UpdateSession session(String owner, {Duration stale = const Duration(seconds: 2)}) => UpdateSession(
        dir: dir,
        ownerId: owner,
        feed: feed,
        staleAfter: stale,
        sleep: (d) => Future<void>.delayed(d < const Duration(milliseconds: 40) ? d : const Duration(milliseconds: 40)),
        downloader: UpdateDownloader(
          dir: dir,
          sleep: (_) => Future<void>.delayed(const Duration(milliseconds: 5)),
          connectTimeout: const Duration(seconds: 2),
          idleTimeout: const Duration(milliseconds: 400),
          backoffBase: const Duration(milliseconds: 10),
          tickInterval: const Duration(milliseconds: 20),
        ),
      );

  setUp(() async {
    HttpOverrides.global = null;
    server = FlakyHttpServer();
    await server.start();
    dir = Directory.systemTemp.createTempSync('mihrab_session_test');
    apk = pseudoRandomBytes(500 * 1024);
    server.serve('/app.apk', apk);
    feed = _FakeFeed();
  });

  tearDown(() async {
    await server.stop();
    try {
      dir.deleteSync(recursive: true);
    } catch (_) {}
  });

  test('بلا مهمة: لا شيء يُنزَّل', () async {
    expect(await session('ui').run(onStatus: (_) {}), isNull);
    expect(server.requests, isEmpty);
  });

  test('تنزّل المهمة حتى تجهز، والمهمة تبقى محفوظة إلى أن يُثبَّت الإصدار', () async {
    final s = session('ui');
    await s.writeJob(UpdateJob.forPlatform(infoFor('1.0.10', apk, '/app.apk'), 'android')!);

    final statuses = <UpdateStatus>[];
    final file = await s.run(onStatus: statuses.add);

    expect(file!.readAsBytesSync(), apk);
    expect(statuses.last.phase, UpdatePhase.ready);
    expect(s.readJob()!.version, '1.0.10');
    expect((await s.readyFile())!.path, file.path);
    // تشغيل ثانٍ (فتح التطبيق من جديد): جاهز فوراً بلا شبكة
    final before = server.requests.length;
    expect((await session('ui-2').run(onStatus: (_) {}))!.path, file.path);
    expect(server.requests.length, before);
  });

  test('إغلاق التطبيق في منتصف التنزيل ثم فتحه: جلسة جديدة تكمل من حيث وقف', () async {
    // الخادم يصمت بعد 200KB: التنزيل عالق في منتصفه لحظة "القتل"
    server.plan.add(const Reply(stallAfter: 200 * 1024));
    final first = session('ui-before-kill');
    await first.writeJob(UpdateJob.forPlatform(infoFor('1.0.10', apk, '/app.apk'), 'android')!);

    var killed = false;
    final stopped = await first.run(
      onStatus: (s) => killed = killed || s.received > 150 * 1024,
      shouldStop: () => killed,
    );
    expect(stopped, isNull);
    final kept = first.downloader.partFile(first.readJob()!).lengthSync();
    expect(kept, greaterThan(150 * 1024));

    // لا أحد ينبض بعد "القتل": الجلسة الجديدة تنتظر انقضاء مهلة الصمت ثم تتولى
    final file = await session('ui-after-restart', stale: const Duration(milliseconds: 300)).run(onStatus: (_) {});

    expect(file!.readAsBytesSync(), apk);
    expect(server.requests.last.range, 'bytes=$kept-');
  });

  test('طرف ينزّل وطرف يراقب: المراقب لا يفتح اتصالاً ويرى التقدم ثم الملف نفسه', () async {
    // الخادم يصمت في منتصف الملف: المالك عالق لحظة يبدأ المراقب
    server.plan.add(const Reply(stallAfter: 200 * 1024));
    final owner = session('ui');
    await owner.writeJob(UpdateJob.forPlatform(infoFor('1.0.10', apk, '/app.apk'), 'android')!);

    final observed = <UpdateStatus>[];
    final ownerRun = owner.run(onStatus: (_) {});
    await Future<void>.delayed(const Duration(milliseconds: 150));
    final watcherRun = session('bg').run(onStatus: observed.add);

    final files = await Future.wait([ownerRun, watcherRun]);

    expect(files[0]!.readAsBytesSync(), apk);
    expect(files[1]!.path, files[0]!.path);
    // المراقب رأى نبضات المالك لا نبضاته هو
    expect(observed.where((s) => s.phase != UpdatePhase.ready).map((s) => s.owner).toSet(), {'ui'});
  });

  test('طرفان يبدآن معاً: الملف النهائي سليم ولا يُسلَّم مرتين مختلفتين', () async {
    final a = session('ui');
    await a.writeJob(UpdateJob.forPlatform(infoFor('1.0.10', apk, '/app.apk'), 'android')!);
    final b = session('bg');

    final files = await Future.wait([a.run(onStatus: (_) {}), b.run(onStatus: (_) {})]);

    expect(files[0]!.readAsBytesSync(), apk);
    expect(files[1]!.path, files[0]!.path);
  });

  test('المالك يصمت (جُمّد أو قُتل): المراقب يتولى بعد مهلة الصمت', () async {
    final s = session('bg', stale: const Duration(milliseconds: 400));
    await s.writeJob(UpdateJob.forPlatform(infoFor('1.0.10', apk, '/app.apk'), 'android')!);
    // نبضة حديثة من مالك لن ينبض بعدها
    File('${dir.path}${Platform.pathSeparator}status.json').writeAsStringSync(UpdateStatus(
      owner: 'ui-dead',
      atMs: DateTime.now().millisecondsSinceEpoch,
      phase: UpdatePhase.downloading,
      received: 0,
      total: apk.length,
      version: '1.0.10',
    ).encode());

    final seen = <String>[];
    final watch = Stopwatch()..start();
    final file = await s.run(onStatus: (st) => seen.add(st.owner));

    expect(file!.readAsBytesSync(), apk);
    expect(seen.first, 'ui-dead'); // راقب أولاً
    expect(seen.last, 'bg'); // ثم تولى
    expect(watch.elapsedMilliseconds, greaterThanOrEqualTo(350));
  });

  test('طرف آخر يتولى التنزيل: المالك القديم يتوقف عن الكتابة فوراً', () async {
    server.plan.add(const Reply(stallAfter: 100 * 1024));
    final old = session('ui', stale: const Duration(seconds: 30));
    await old.writeJob(UpdateJob.forPlatform(infoFor('1.0.10', apk, '/app.apk'), 'android')!);

    var taken = false;
    final oldStatuses = <UpdateStatus>[];
    final oldRun = old.run(
      onStatus: (s) {
        oldStatuses.add(s);
        if (!taken && s.owner == 'ui' && s.received >= 100 * 1024) {
          taken = true;
          // طرف آخر يكتب نبضته: هو المالك الآن
          File('${dir.path}${Platform.pathSeparator}status.json').writeAsStringSync(UpdateStatus(
            owner: 'bg',
            atMs: DateTime.now().millisecondsSinceEpoch,
            phase: UpdatePhase.downloading,
            received: s.received,
            total: s.total,
            version: s.version,
          ).encode());
        }
      },
      shouldStop: () => taken && oldStatuses.last.owner == 'bg',
    );

    expect(await oldRun, isNull);
    // بعد أن رأى نبضة غيره صار مراقباً: آخر ما بلّغه نبضة "bg" لا نبضته
    expect(oldStatuses.last.owner, 'bg');
  });

  test('صدر إصدار أحدث أثناء التنزيل: الجلسة تنتقل إليه وتحذف ملفات القديم', () async {
    final newer = pseudoRandomBytes(420 * 1024, seed: 42);
    server.serve('/new.apk', newer);
    server.plan.add(const Reply(stallAfter: 120 * 1024));
    final s = session('ui');
    final oldJob = UpdateJob.forPlatform(infoFor('1.0.10', apk, '/app.apk'), 'android')!;
    await s.writeJob(oldJob);

    var switched = false;
    final file = await s.run(onStatus: (st) {
      if (!switched && st.received >= 120 * 1024) {
        switched = true;
        unawaited(s.writeJob(UpdateJob.forPlatform(infoFor('1.0.11', newer, '/new.apk'), 'android')!));
      }
    });

    expect(file!.readAsBytesSync(), newer);
    expect(file.path, endsWith('mihrab-1.0.11.apk'));
    expect(s.downloader.partFile(oldJob).existsSync(), isFalse);
  });

  test('وصف الإصدار قديم (الموقع يخدم إصداراً أحدث): يُجلب الوصف الجديد ويكتمل عليه', () async {
    // المهمة تصف 1.0.10 ببصمة لا يخدمها أي رابط الآن
    final newer = pseudoRandomBytes(apk.length, seed: 77);
    server.serve('/app.apk', newer);
    feed.latest = infoFor('1.0.11', newer, '/app.apk');
    final s = session('bg');
    await s.writeJob(UpdateJob.forPlatform(infoFor('1.0.10', apk, '/app.apk'), 'android')!);

    final file = await s.run(onStatus: (_) {});

    expect(feed.calls, greaterThanOrEqualTo(1));
    expect(s.readJob()!.version, '1.0.11');
    expect(file!.readAsBytesSync(), newer);
  });

  test('إلغاء المهمة أثناء التنزيل ينهي الجلسة بهدوء', () async {
    server.plan.add(const Reply(stallAfter: 80 * 1024));
    final s = session('ui');
    await s.writeJob(UpdateJob.forPlatform(infoFor('1.0.10', apk, '/app.apk'), 'android')!);

    var cleared = false;
    final file = await s.run(onStatus: (st) {
      if (!cleared && st.received >= 80 * 1024) {
        cleared = true;
        File('${dir.path}${Platform.pathSeparator}job.json').deleteSync();
      }
    });

    expect(file, isNull);
  });

  test('نبضة الحالة تُكتب على القرص أثناء التنزيل وتحمل هوية المالك والتقدم', () async {
    server.plan.add(const Reply(stallAfter: 200 * 1024));
    final s = session('ui');
    await s.writeJob(UpdateJob.forPlatform(infoFor('1.0.10', apk, '/app.apk'), 'android')!);

    UpdateStatus? onDisk;
    await s.run(onStatus: (st) {
      if (st.phase == UpdatePhase.downloading && st.received >= 200 * 1024) onDisk ??= s.readStatus();
    });

    expect(onDisk, isNotNull);
    expect(onDisk!.owner, 'ui');
    expect(onDisk!.version, '1.0.10');
    expect(onDisk!.total, apk.length);
    expect(onDisk!.received, greaterThanOrEqualTo(200 * 1024));
  });
}
