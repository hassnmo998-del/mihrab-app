import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/services/app_update_service.dart';
import 'package:flutter_app/widgets/update_dialog.dart';

/// نافذة التحديث في كل حالاتها، على هاتف ضيق وعلى شاشة عريضة.
void main() {
  final service = AppUpdateService.instance;
  final info = UpdateInfo(
    version: '1.0.10',
    releaseNotes: '📚 محراب 1.0.10:\n• المكتبة الشاملة بنصوصها الكاملة.\n• الأذان يكتمل والتطبيق مغلق.\n' * 3,
    publishedAt: DateTime(2026, 10, 3),
    android: const UpdateAsset(urls: ['https://example.test/a.apk'], size: 98778537),
    windows: const UpdateAsset(urls: ['https://example.test/a.exe'], size: 20412376),
  );

  void put(SilentUpdateState state, {double progress = 0, bool waiting = false}) {
    service.debugConfigure(currentVersion: '1.0.9');
    service
      ..latestInfo = info
      ..state = state
      ..downloadProgress = progress
      ..receivedBytes = (98778537 * progress).round()
      ..totalBytes = 98778537
      ..isWaitingForNetwork = waiting
      ..errorMessage = state == SilentUpdateState.error ? 'هذا الإصدار لا يحمل ملف تثبيت لهذا الجهاز.' : null;
  }

  Future<void> pumpDialog(WidgetTester tester, Size size, {double textScale = 1.0}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('ar'),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
        child: Directionality(textDirection: TextDirection.rtl, child: child!),
      ),
      home: Scaffold(body: UpdateDialog(info: info, service: service)),
    ));
    await tester.pump(const Duration(milliseconds: 50));
  }

  const sizes = {'phone': Size(320, 640), 'laptop': Size(1366, 768)};

  for (final entry in sizes.entries) {
    testWidgets('متاح: زر «تحديث الآن» (${entry.key})', (tester) async {
      put(SilentUpdateState.updateAvailable);
      await pumpDialog(tester, entry.value, textScale: 1.3);

      expect(tester.takeException(), isNull);
      expect(find.text('تحديث جديد متاح لمحراب'), findsOneWidget);
      expect(find.text('تحديث الآن'), findsOneWidget);
    });

    testWidgets('ينزّل: تقدم بلا أزرار إيقاف أو إلغاء (${entry.key})', (tester) async {
      put(SilentUpdateState.downloading, progress: 0.42);
      await pumpDialog(tester, entry.value, textScale: 1.3);

      expect(tester.takeException(), isNull);
      expect(find.text('جارٍ تحديث محراب'), findsOneWidget);
      expect(find.text('42%'), findsOneWidget);
      expect(find.text('متابعة في الخلفية'), findsOneWidget);
      expect(find.textContaining('إيقاف'), findsNothing);
      expect(find.textContaining('إلغاء'), findsNothing);
      expect(find.text('تحديث الآن'), findsNothing);
    });

    testWidgets('لا اتصال: «بانتظار الاتصال» لا رسالة فشل (${entry.key})', (tester) async {
      put(SilentUpdateState.downloading, progress: 0.42, waiting: true);
      await pumpDialog(tester, entry.value, textScale: 1.3);

      expect(tester.takeException(), isNull);
      expect(find.text('بانتظار الاتصال بالإنترنت…'), findsOneWidget);
      expect(find.textContaining('فشل'), findsNothing);
      expect(find.textContaining('تعذر'), findsNothing);
      expect(find.text('42%'), findsOneWidget);
    });

    testWidgets('جاهز: زر التثبيت (${entry.key})', (tester) async {
      put(SilentUpdateState.readyToInstall, progress: 1);
      await pumpDialog(tester, entry.value, textScale: 1.3);

      expect(tester.takeException(), isNull);
      expect(find.text('تحديث محراب جاهز للتثبيت'), findsOneWidget);
      expect(find.byIcon(Icons.rocket_launch_rounded), findsOneWidget);
    });

    testWidgets('تعذّر البدء: الرسالة وزر إعادة المحاولة (${entry.key})', (tester) async {
      put(SilentUpdateState.error);
      await pumpDialog(tester, entry.value, textScale: 1.3);

      expect(tester.takeException(), isNull);
      expect(find.text('إعادة المحاولة'), findsOneWidget);
    });
  }

  testWidgets('النافذة تتابع الحالة حيّة: من «متاح» إلى «ينزّل» إلى «جاهز»', (tester) async {
    put(SilentUpdateState.updateAvailable);
    await pumpDialog(tester, const Size(412, 800));
    expect(find.text('تحديث الآن'), findsOneWidget);

    service
      ..state = SilentUpdateState.downloading
      ..downloadProgress = 0.1;
    // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
    service.notifyListeners();
    await tester.pump();
    expect(find.text('10%'), findsOneWidget);

    service
      ..state = SilentUpdateState.readyToInstall
      ..downloadProgress = 1;
    // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
    service.notifyListeners();
    await tester.pump();
    expect(find.byIcon(Icons.rocket_launch_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // صورة للمراجعة البصرية عند الطلب: flutter test --dart-define=SHOTS=true
  testWidgets('لقطات', (tester) async {
    const out = 'build/update_dialog_preview';
    Directory(out).createSync(recursive: true);
    await tester.runAsync(() async {
      for (final (family, files) in [
        ('Tajawal', ['assets/fonts/Tajawal-Regular.ttf', 'assets/fonts/Tajawal-Bold.ttf']),
        ('MaterialIcons', ['C:/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf']),
      ]) {
        final loader = FontLoader(family);
        for (final path in files) {
          loader.addFont(Future.value(ByteData.sublistView(File(path).readAsBytesSync())));
        }
        await loader.load();
      }
    });
    for (final (name, state, progress, waiting) in [
      ('available', SilentUpdateState.updateAvailable, 0.0, false),
      ('downloading', SilentUpdateState.downloading, 0.42, false),
      ('waiting', SilentUpdateState.downloading, 0.42, true),
      ('ready', SilentUpdateState.readyToInstall, 1.0, false),
    ]) {
      put(state, progress: progress, waiting: waiting);
      final key = GlobalKey();
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(fontFamily: 'Tajawal'),
          home: Scaffold(
            backgroundColor: Colors.black54,
            body: UpdateDialog(info: info, service: service),
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.runAsync(() async {
        final boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 1.0);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        File('$out/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
      });
    }
  }, skip: !const bool.fromEnvironment('SHOTS'));
}
