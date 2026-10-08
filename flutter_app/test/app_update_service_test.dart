import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_app/services/app_update_service.dart';
import 'package:flutter_app/services/update/update_downloader.dart';
import 'package:flutter_app/services/update/update_feed.dart';
import 'package:flutter_app/services/update/update_session.dart';

import 'support/flaky_http_server.dart';

class _FakeFeed extends UpdateFeed {
  UpdateInfo? latest;
  bool offline = false;

  @override
  Future<UpdateInfo> fetchLatest() async {
    final info = latest;
    if (offline || info == null) throw const SocketException('offline');
    return info;
  }
}

void main() {
  group('AppUpdateService Unit Tests', () {
    final service = AppUpdateService.instance;

    test('isNewerVersion semver comparison logic', () {
      // Basic precedence
      expect(service.isNewerVersion('1.0.1', '1.0.0'), isTrue);
      expect(service.isNewerVersion('1.1.0', '1.0.9'), isTrue);
      expect(service.isNewerVersion('2.0.0', '1.9.9'), isTrue);
      expect(service.isNewerVersion('1.0.0', '1.0.0'), isFalse);
      expect(service.isNewerVersion('1.0.0', '1.0.1'), isFalse);

      // Same version with/without build numbers or prefixes MUST be false (no false positive update prompts!)
      expect(service.isNewerVersion('1.0.3', '1.0.3'), isFalse);
      expect(service.isNewerVersion('1.0.3', '1.0.3+3'), isFalse);
      expect(service.isNewerVersion('v1.0.3', '1.0.3+3'), isFalse);
      expect(service.isNewerVersion('1.0.3+3', '1.0.3+3'), isFalse);
      expect(service.isNewerVersion(' v1.0.3 ', '1.0.3+3'), isFalse);
      expect(service.isNewerVersion('1.0.1+2', '1.0.1'), isFalse);
      expect(service.isNewerVersion('1.0.3', '1.0.4'), isFalse);
      expect(service.isNewerVersion('1.0.2', '1.0.3+3'), isFalse);

      // Version 1.0.4 specific checks (the exact issue reported by user)
      expect(service.isNewerVersion('1.0.4', '1.0.4'), isFalse);
      expect(service.isNewerVersion('v1.0.4', '1.0.4'), isFalse);
      expect(service.isNewerVersion('1.0.4', '1.0.4+4'), isFalse);
      expect(service.isNewerVersion('v1.0.4', '1.0.4+4'), isFalse);
      expect(service.isNewerVersion('1.0.4+4', '1.0.4'), isFalse);
      expect(service.isNewerVersion(' V1.0.4 ', '1.0.4+4'), isFalse);

      // Empty or invalid strings must never report update available
      expect(service.isNewerVersion('1.0.4', ''), isFalse);
      expect(service.isNewerVersion('', '1.0.4'), isFalse);
      expect(service.isNewerVersion('', ''), isFalse);

      // Truly newer versions MUST be true
      expect(service.isNewerVersion('1.0.4', '1.0.3'), isTrue);
      expect(service.isNewerVersion('1.0.4', '1.0.3+3'), isTrue);
      expect(service.isNewerVersion('v1.0.4', '1.0.3+3'), isTrue);
      expect(service.isNewerVersion('1.0.3+4', '1.0.3+3'), isTrue);
      expect(service.isNewerVersion('1.0.5', '1.0.4'), isTrue);
      expect(service.isNewerVersion('v1.0.5', '1.0.4+4'), isTrue);
    });

    test('Initial state of AppUpdateService', () {
      expect(service.state, equals(SilentUpdateState.idle));
      expect(service.downloadProgress, equals(0.0));
      expect(service.receivedBytes, equals(0));
      expect(service.totalBytes, equals(0));
    });

    test('Formatting helpers formatProgress and formatSize', () {
      service.downloadProgress = 0.45;
      service.receivedBytes = 45 * 1024 * 1024;
      service.totalBytes = 100 * 1024 * 1024;

      expect(service.formattedProgress, equals('45%'));
      expect(service.formattedSize, contains('45.0 ميغابايت من 100.0 ميغابايت'));
    });
  });

  test('وصف الإصدار من GitHub: الحجم والبصمة والرابطان (الموقع ثم GitHub)', () {
    final info = UpdateInfo.fromJson({
      'tag_name': 'v1.0.10',
      'body': 'ملاحظات',
      'published_at': '2026-10-03T10:00:00Z',
      'assets': [
        {
          'name': 'mihrab-android-v1.0.10.apk',
          'size': 98778537,
          'digest': 'sha256:A9A3DA75',
          'browser_download_url': 'https://github.com/o/r/releases/download/v1.0.10/mihrab-android-v1.0.10.apk',
        },
        {'name': 'mihrab-web.zip', 'size': 5, 'browser_download_url': 'https://github.com/x/web.zip'},
        {
          'name': 'mihrab-windows-v1.0.10.exe',
          'size': 20412376,
          'browser_download_url': 'https://github.com/o/r/releases/download/v1.0.10/mihrab-windows-v1.0.10.exe',
        },
      ],
    }, cdnAndroidUrl: 'https://site/downloads/mihrab-android.apk');

    expect(info.version, '1.0.10');
    expect(info.android!.size, 98778537);
    expect(info.android!.sha256, 'a9a3da75');
    expect(info.android!.urls, [
      'https://site/downloads/mihrab-android.apk',
      'https://github.com/o/r/releases/download/v1.0.10/mihrab-android-v1.0.10.apk',
    ]);
    expect(info.windows!.urls.single, endsWith('mihrab-windows-v1.0.10.exe'));
    expect(info.windows!.sha256, isEmpty);
  });

  test('وصف الإصدار من update.json على الموقع: الروابط نسبية إلى مكانه', () {
    final info = UpdateInfo.fromManifest({
      'version': '1.0.10',
      'notes': 'ملاحظات',
      'publishedAt': '2026-10-03T10:00:00Z',
      'android': {
        'path': 'downloads/mihrab-android.apk',
        'size': 100,
        'sha256': 'ABC',
        'mirror': 'https://github.com/o/r/releases/download/v1.0.10/a.apk',
      },
    }, Uri.parse('https://owner.github.io/repo/update.json'));

    expect(info.android!.urls, [
      'https://owner.github.io/repo/downloads/mihrab-android.apk',
      'https://github.com/o/r/releases/download/v1.0.10/a.apk',
    ]);
    expect(info.android!.sha256, 'abc');
    expect(info.windows, isNull);
  });

  // ══════════════════════════════════════════════════════════════════
  // السلوك الذي اشتكى منه المستخدمون: التنزيل يفشل مع نت ضعيف، ونافذة
  // «تحديث متاح» تظهر لتحديث هو قيد التنزيل، وإغلاق التطبيق يضيّع التنزيل.
  // ══════════════════════════════════════════════════════════════════
  group('التحديث من الضغط إلى الجاهزية', () {
    final service = AppUpdateService.instance;
    late FlakyHttpServer server;
    late Directory dir;
    late Uint8List apk;
    late _FakeFeed feed;
    late List<SilentUpdateState> states;
    void record() => states.add(service.state);

    UpdateInfo release(String version, Uint8List body, String path) => UpdateInfo(
          version: version,
          releaseNotes: 'ملاحظات $version',
          publishedAt: DateTime(2026),
          android: UpdateAsset(
            urls: [server.url(path)],
            size: body.length,
            sha256: sha256.convert(body).toString(),
          ),
        );

    /// يهيئ الخدمة كأن التطبيق أقلع للتو (بالإصدار [current]) على مجلد التحديثات نفسه.
    void boot({String current = '1.0.9'}) {
      service.debugConfigure(
        feed: feed,
        updatesDir: () async => dir,
        platform: 'android',
        currentVersion: current,
        sessionFactory: (d, owner, f) => UpdateSession(
          dir: d,
          ownerId: owner,
          feed: f,
          staleAfter: const Duration(milliseconds: 500),
          heartbeatEvery: const Duration(milliseconds: 100),
          sleep: (t) => Future<void>.delayed(t < const Duration(milliseconds: 40) ? t : const Duration(milliseconds: 40)),
          downloader: UpdateDownloader(
            dir: d,
            sleep: (_) => Future<void>.delayed(const Duration(milliseconds: 5)),
            connectTimeout: const Duration(seconds: 2),
            idleTimeout: const Duration(milliseconds: 300),
            backoffBase: const Duration(milliseconds: 20),
            maxBackoff: const Duration(milliseconds: 200),
            tickInterval: const Duration(milliseconds: 20),
          ),
        ),
      );
    }

    Future<void> until(bool Function() condition, {Duration timeout = const Duration(seconds: 20)}) async {
      final deadline = DateTime.now().add(timeout);
      while (!condition()) {
        if (DateTime.now().isAfter(deadline)) fail('لم يتحقق الشرط خلال $timeout (الحالة: ${service.state})');
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    }

    setUp(() async {
      HttpOverrides.global = null;
      SharedPreferences.setMockInitialValues({});
      server = FlakyHttpServer();
      await server.start();
      dir = Directory.systemTemp.createTempSync('mihrab_service_test');
      apk = pseudoRandomBytes(500 * 1024);
      server.serve('/app.apk', apk);
      feed = _FakeFeed()..latest = release('1.0.10', apk, '/app.apk');
      states = [];
      boot();
      service.addListener(record);
    });

    tearDown(() async {
      service.removeListener(record);
      service.onReadyToInstall = null;
      // أي جلسة باقية تتوقف قبل حذف مجلدها
      service.debugConfigure(updatesDir: () async => dir);
      await server.stop();
      await Future<void>.delayed(const Duration(milliseconds: 150));
      try {
        dir.deleteSync(recursive: true);
      } catch (_) {}
    });

    test('فحص يجد إصداراً أحدث: الحالة «متاح»، ولا شيء يُنزَّل قبل الضغط', () async {
      final info = await service.checkForUpdate();

      expect(info!.version, '1.0.10');
      expect(service.state, SilentUpdateState.updateAvailable);
      expect(server.requests, isEmpty);
    });

    test('الإصدار المنشور ليس أحدث: لا تحديث', () async {
      boot(current: '1.0.10');
      expect(await service.checkForUpdate(), isNull);
      expect(service.state, SilentUpdateState.idle);
    });

    test('الضغط على «تحديث» ينزّل حتى الجاهزية ويبلّغ الواجهة', () async {
      final ready = Completer<UpdateInfo>();
      service.onReadyToInstall = ready.complete;
      final info = (await service.checkForUpdate())!;

      await service.startDownload(info);
      expect(service.state, SilentUpdateState.downloading);

      expect((await ready.future.timeout(const Duration(seconds: 20))).version, '1.0.10');
      expect(service.state, SilentUpdateState.readyToInstall);
      expect(File(service.downloadedFilePath!).readAsBytesSync(), apk);
      expect(service.downloadProgress, 1.0);
    });

    test('التنزيل التلقائي: فحص الفتح ينزّل الإصدار الجديد وحده، والنافذة عند الجاهزية فقط', () async {
      final ready = Completer<UpdateInfo>();
      service.onReadyToInstall = ready.complete;

      // ما يجري عند فتح التطبيق: لا ضغط على شيء
      final info = await service.checkAndDownload();

      expect(info!.version, '1.0.10');
      expect(service.state, SilentUpdateState.downloading);
      expect((await ready.future.timeout(const Duration(seconds: 20))).version, '1.0.10');
      expect(service.state, SilentUpdateState.readyToInstall);
      expect(File(service.downloadedFilePath!).readAsBytesSync(), apk);
    });

    test('التنزيل التلقائي: لا إصدار أحدث، لا شيء يُنزَّل', () async {
      boot(current: '1.0.10');
      expect(await service.checkAndDownload(), isNull);
      expect(service.state, SilentUpdateState.idle);
      expect(server.requests, isEmpty);
    });

    test('التنزيل التلقائي: كل عودة إلى التطبيق أثناء التنزيل لا تبدأه من جديد', () async {
      server.plan.add(const Reply(stallAfter: 150 * 1024));
      await service.checkAndDownload();
      await until(() => service.receivedBytes >= 150 * 1024);
      states.clear();

      await service.checkAndDownload();
      await service.checkAndDownload();

      expect(states, isNot(contains(SilentUpdateState.updateAvailable)));
      await until(() => service.state == SilentUpdateState.readyToInstall);
      expect(server.requests.length, 2); // الذي صمت والذي أكمل
      expect(File(service.downloadedFilePath!).readAsBytesSync(), apk);
    });

    test('التنزيل التلقائي: الملف جاهز من قبل، الفتح التالي لا ينزّله ثانية', () async {
      await service.checkAndDownload();
      await until(() => service.state == SilentUpdateState.readyToInstall);
      final before = server.requests.length;

      boot();
      await service.resumePendingUpdate();
      await service.checkAndDownload();
      await until(() => service.state == SilentUpdateState.readyToInstall);

      expect(server.requests.length, before);
    });

    test('فحص التحديث أثناء التنزيل لا يعيد الحالة إلى «متاح» ولا يبدأ تنزيلاً ثانياً', () async {
      server.plan.add(const Reply(stallAfter: 150 * 1024));
      final info = (await service.checkForUpdate())!;
      await service.startDownload(info);
      await until(() => service.receivedBytes >= 150 * 1024);
      states.clear();

      // ما يفعله التطبيق عند كل عودة إليه
      final again = await service.checkForUpdate();
      final again2 = await service.checkForUpdate();

      expect(again!.version, '1.0.10');
      expect(again2!.version, '1.0.10');
      expect(states, isNot(contains(SilentUpdateState.checking)));
      expect(states, isNot(contains(SilentUpdateState.updateAvailable)));
      expect(service.state, SilentUpdateState.downloading);

      await until(() => service.state == SilentUpdateState.readyToInstall);
      expect(File(service.downloadedFilePath!).readAsBytesSync(), apk);
      // اتصالان فقط: الأول الذي صمت، والثاني الذي أكمل
      expect(server.requests.length, 2);
    });

    test('ضغط «تحديث» مرتين لا يشغّل تنزيلين', () async {
      server.plan.add(const Reply(stallAfter: 100 * 1024));
      final info = (await service.checkForUpdate())!;

      await service.startDownload(info);
      await service.startDownload(info);
      await until(() => service.state == SilentUpdateState.readyToInstall);

      expect(server.requests.length, 2);
      expect(File(service.downloadedFilePath!).readAsBytesSync(), apk);
    });

    test('انقطاع الشبكة في منتصف التنزيل: الحالة تبقى «ينزّل» بانتظار الاتصال، ثم يكتمل وحده', () async {
      server.plan.add(const Reply(cutAfter: 200 * 1024));
      final port = server.port;
      final info = (await service.checkForUpdate())!;
      await service.startDownload(info);
      await until(() => service.receivedBytes >= 200 * 1024);

      await server.stop(); // لا شبكة
      await until(() => service.isWaitingForNetwork);
      await Future<void>.delayed(const Duration(milliseconds: 600));

      expect(service.state, SilentUpdateState.downloading);
      expect(states, isNot(contains(SilentUpdateState.error)));
      expect(service.receivedBytes, greaterThanOrEqualTo(200 * 1024)); // ما نزل محفوظ

      await server.start(onPort: port); // عاد الاتصال
      await until(() => service.state == SilentUpdateState.readyToInstall);

      expect(service.isWaitingForNetwork, isFalse);
      expect(File(service.downloadedFilePath!).readAsBytesSync(), apk);
      expect(states, isNot(contains(SilentUpdateState.error)));
    });

    test('إغلاق التطبيق أثناء التنزيل ثم فتحه: يكمل وحده من حيث وقف، بلا نافذة ولا ضغط', () async {
      server.plan.add(const Reply(stallAfter: 200 * 1024));
      await service.startDownload((await service.checkForUpdate())!);
      await until(() => service.receivedBytes >= 200 * 1024);

      // "قتل" التطبيق ثم إقلاع جديد على المجلد نفسه
      boot();
      states.clear();
      expect(service.state, SilentUpdateState.idle);
      await Future<void>.delayed(const Duration(milliseconds: 700)); // النبضة القديمة تبرد

      await service.resumePendingUpdate();
      expect(service.state, SilentUpdateState.downloading);
      expect(service.latestInfo!.version, '1.0.10');

      // فحص الإقلاع يجري كعادته ولا يغيّر شيئاً
      await service.checkForUpdate();
      expect(states, isNot(contains(SilentUpdateState.updateAvailable)));

      await until(() => service.state == SilentUpdateState.readyToInstall);
      expect(File(service.downloadedFilePath!).readAsBytesSync(), apk);
      final resumed = server.requests.last.range!;
      expect(int.parse(resumed.substring(6, resumed.length - 1)), greaterThanOrEqualTo(200 * 1024));
    });

    test('فتح التطبيق بلا إنترنت وتحديث معلّق: يبقى «ينزّل» وينتظر', () async {
      server.plan.add(const Reply(stallAfter: 100 * 1024));
      await service.startDownload((await service.checkForUpdate())!);
      await until(() => service.receivedBytes >= 100 * 1024);

      final port = server.port;
      await server.stop();
      feed.offline = true;
      boot();
      states.clear();
      await Future<void>.delayed(const Duration(milliseconds: 700));

      await service.resumePendingUpdate();
      await service.checkForUpdate(); // يفشل بلا شبكة
      await until(() => service.isWaitingForNetwork);

      expect(service.state, SilentUpdateState.downloading);
      expect(states, isNot(contains(SilentUpdateState.error)));

      await server.start(onPort: port);
      await until(() => service.state == SilentUpdateState.readyToInstall);
      expect(File(service.downloadedFilePath!).readAsBytesSync(), apk);
    });

    test('فتح التطبيق وملف التحديث مكتمل: جاهز للتثبيت فوراً بلا شبكة', () async {
      await service.startDownload((await service.checkForUpdate())!);
      await until(() => service.state == SilentUpdateState.readyToInstall);
      final before = server.requests.length;

      boot();
      await service.resumePendingUpdate();
      await until(() => service.state == SilentUpdateState.readyToInstall);

      expect(server.requests.length, before);
      expect(File(service.downloadedFilePath!).existsSync(), isTrue);
    });

    test('بعد تثبيت الإصدار: الإقلاع ينظف ملفاته ولا يعود للتنزيل', () async {
      await service.startDownload((await service.checkForUpdate())!);
      await until(() => service.state == SilentUpdateState.readyToInstall);

      boot(current: '1.0.10'); // التطبيق صار على الإصدار الجديد
      await service.resumePendingUpdate();

      expect(service.state, SilentUpdateState.idle);
      expect(dir.existsSync(), isFalse);
    });

    test('صدر إصدار أحدث أثناء التنزيل: ينتقل إليه', () async {
      final newer = pseudoRandomBytes(300 * 1024, seed: 21);
      server.serve('/new.apk', newer);
      server.plan.add(const Reply(stallAfter: 100 * 1024));
      await service.startDownload((await service.checkForUpdate())!);
      await until(() => service.receivedBytes >= 100 * 1024);

      feed.latest = release('1.0.11', newer, '/new.apk');
      final info = await service.checkForUpdate();

      expect(info!.version, '1.0.11');
      await until(() => service.state == SilentUpdateState.readyToInstall);
      expect(service.downloadedFilePath, endsWith('mihrab-1.0.11.apk'));
      expect(File(service.downloadedFilePath!).readAsBytesSync(), newer);
    });

    test('إصدار بلا ملف لهذا الجهاز: رسالة واضحة لا تنزيل معلّق', () async {
      final info = UpdateInfo(version: '1.0.10', releaseNotes: '', publishedAt: DateTime(2026));

      await service.startDownload(info);

      expect(service.state, SilentUpdateState.error);
      expect(service.errorMessage, isNotEmpty);
    });
  });
}
