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

  Future<void> pumpDialog(WidgetTester tester, Size size,
      {double textScale = 1.0, UpdateInfo? override}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('ar'),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
        child: Directionality(textDirection: TextDirection.rtl, child: child!),
      ),
      home: Scaffold(body: UpdateDialog(info: override ?? info, service: service)),
    ));
    await tester.pump(const Duration(milliseconds: 50));
  }

  // ملاحظات إصدار كما تُكتب في RELEASE_NOTES.md
  UpdateInfo notesInfo(String notes) => UpdateInfo(
        version: '1.0.20',
        releaseNotes: notes,
        publishedAt: DateTime(2026, 11, 1),
        android: const UpdateAsset(urls: ['https://example.test/a.apk'], size: 98778537),
        windows: const UpdateAsset(urls: ['https://example.test/a.exe'], size: 20412376),
      );

  const realisticNotes = '🕌 محراب 1.0.20 — مزامنة أخف:\n'
      '• مزامنة أخف وأسرع: كل جهاز يحمّل بيانات مسجده وما تغيّر فيها فقط.\n'
      '• لوحة المشرف العام: ملخص بأرقام المنصة مع بحث وتصفية بالمدينة.\n'
      '\n'
      '📚 ومن الإصدارات السابقة:\n'
      '• 1.0.19: مواقيت الصلاة بدقة الموقع.\n'
      '• رفع تسجيل الدرس من ملف صوتي.\n';

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

  group('الجديد ظاهر لا مخفي', () {
    for (final entry in sizes.entries) {
      testWidgets('الجديد بعنوانه وخطه الكبير فوراً بلا تمرير (${entry.key})', (tester) async {
        put(SilentUpdateState.updateAvailable);
        await pumpDialog(tester, entry.value, override: notesInfo(realisticNotes));

        expect(tester.takeException(), isNull);
        expect(find.text('ما الجديد في هذا الإصدار'), findsOneWidget);
        expect(find.text('مزامنة أخف'), findsOneWidget, reason: 'عنوان الإصدار');
        expect(find.text('مزامنة أخف وأسرع'), findsOneWidget);
        expect(find.text('لوحة المشرف العام'), findsOneWidget);
        // داخل شاشة المستخدم فعلاً، لا تحت خط الطي
        final viewport = tester.view.physicalSize;
        for (final t in ['مزامنة أخف وأسرع', 'لوحة المشرف العام']) {
          final r = tester.getRect(find.text(t));
          expect(r.bottom, lessThanOrEqualTo(viewport.height), reason: t);
          expect(r.top, greaterThanOrEqualTo(0), reason: t);
        }
        // الخط كبير: العنوان 15.5 والوصف 14.5 (كان 12.5 داخل مربع 140 بكسل)
        final title = tester.widget<Text>(find.text('مزامنة أخف وأسرع'));
        expect(title.style!.fontSize, greaterThanOrEqualTo(15));
        final body = tester.widget<Text>(find.text('كل جهاز يحمّل بيانات مسجده وما تغيّر فيها فقط.'));
        expect(body.style!.fontSize, greaterThanOrEqualTo(14));
      });
    }

    testWidgets('رقم الإصدار الجديد والحالي في الرأس', (tester) async {
      put(SilentUpdateState.updateAvailable);
      await pumpDialog(tester, const Size(360, 700), override: notesInfo(realisticNotes));
      expect(find.text('الإصدار v1.0.20'), findsOneWidget);
      expect(find.text('أنت الآن على v1.0.9'), findsOneWidget);
    });

    testWidgets('الإصدارات السابقة مطوية، وتُفتح بنقرة', (tester) async {
      put(SilentUpdateState.updateAvailable);
      await pumpDialog(tester, const Size(360, 800), override: notesInfo(realisticNotes));

      expect(find.text('ومن الإصدارات السابقة (2)'), findsOneWidget);
      expect(find.textContaining('مواقيت الصلاة بدقة الموقع'), findsNothing);

      await tester.tap(find.text('ومن الإصدارات السابقة (2)'));
      await tester.pumpAndSettle();
      expect(find.textContaining('مواقيت الصلاة بدقة الموقع'), findsOneWidget);
    });

    testWidgets('ملاحظات طويلة جداً على هاتف صغير بخط مكبَّر: زر التثبيت يبقى ظاهراً', (tester) async {
      final long = '🕌 محراب 1.0.20 — كثيرة:\n${List.generate(14, (i) => '• بند رقم $i: وصف مفصّل يحتاج أكثر من سطر ليظهر كاملاً على شاشة ضيقة جداً.').join('\n')}';
      for (final state in [SilentUpdateState.updateAvailable, SilentUpdateState.readyToInstall]) {
        put(state, progress: state == SilentUpdateState.readyToInstall ? 1 : 0);
        await pumpDialog(tester, const Size(320, 568), textScale: 1.3, override: notesInfo(long));

        expect(tester.takeException(), isNull, reason: '$state');
        final button = state == SilentUpdateState.readyToInstall
            ? find.byIcon(Icons.rocket_launch_rounded)
            : find.text('تحديث الآن');
        expect(button, findsOneWidget);
        expect(tester.getRect(button).bottom, lessThanOrEqualTo(568), reason: 'الزر ثابت أسفل النافذة: $state');
        // تمرير الملاحظات لا يحرّك الزر
        final before = tester.getRect(button);
        await tester.drag(find.byType(SingleChildScrollView).first, const Offset(0, -300));
        await tester.pump();
        expect(tester.getRect(button), before);
      }
    });

    testWidgets('ملاحظات بلا نقاط: تُعرض كاملة بخط واضح', (tester) async {
      put(SilentUpdateState.updateAvailable);
      await pumpDialog(tester, const Size(360, 700), override: notesInfo('إصلاحات مهمة في الأذان وتحسينات في الأداء.'));
      expect(find.text('ما الجديد في هذا الإصدار'), findsOneWidget);
      expect(find.text('إصلاحات مهمة في الأذان وتحسينات في الأداء.'), findsOneWidget);
    });

    testWidgets('بلا ملاحظات إطلاقاً: لا قسم «ما الجديد» فارغ', (tester) async {
      put(SilentUpdateState.updateAvailable);
      await pumpDialog(tester, const Size(360, 700), override: notesInfo(''));
      expect(find.text('ما الجديد في هذا الإصدار'), findsNothing);
      expect(find.text('تحديث الآن'), findsOneWidget);
    });

    testWidgets('الوضع الداكن: لا فيض ولا نص غير مقروء', (tester) async {
      put(SilentUpdateState.readyToInstall, progress: 1);
      tester.view.physicalSize = const Size(360, 760);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(brightness: Brightness.dark),
        home: Scaffold(body: UpdateDialog(info: notesInfo(realisticNotes), service: service)),
      ));
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull);
      expect(find.text('مزامنة أخف وأسرع'), findsOneWidget);
    });
  });

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
    // ملاحظات الإصدار الحقيقية من المستودع إن وُجدت، وإلا المثال
    final notesFile = File('../RELEASE_NOTES.md');
    final shotInfo = notesInfo(notesFile.existsSync() ? notesFile.readAsStringSync() : realisticNotes);
    for (final (name, state, progress, waiting, dark) in [
      ('available', SilentUpdateState.updateAvailable, 0.0, false, false),
      ('downloading', SilentUpdateState.downloading, 0.42, false, false),
      ('waiting', SilentUpdateState.downloading, 0.42, true, false),
      ('ready', SilentUpdateState.readyToInstall, 1.0, false, false),
      ('ready_dark', SilentUpdateState.readyToInstall, 1.0, false, true),
    ]) {
      put(state, progress: progress, waiting: waiting);
      final key = GlobalKey();
      tester.view.physicalSize = const Size(360, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(fontFamily: 'Tajawal', brightness: dark ? Brightness.dark : Brightness.light),
          home: Scaffold(
            backgroundColor: Colors.black54,
            body: UpdateDialog(info: shotInfo, service: service),
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
