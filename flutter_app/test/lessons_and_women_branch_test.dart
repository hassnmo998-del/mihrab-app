import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_app/core/di/injection.dart';
import 'package:flutter_app/models/models.dart';
import 'package:flutter_app/screens/admin/widgets/mosque_info_edit_dialog.dart';
import 'package:flutter_app/screens/admin/widgets/women_branch_setup_dialog.dart';
import 'package:flutter_app/screens/management_portal/management_portal_screen.dart';
import 'package:flutter_app/services/audio_upload_queue_manager.dart';
import 'package:flutter_app/services/data_service.dart';

/// أرشفة الدروس وأسئلتها، الفصل بين فرعي الرجال والنساء، وتعديل معلومات المسجد.
void main() {
  late DataService data;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await initInjection();
    data = sl<DataService>();
  });

  setUp(() {
    for (final role in ['mosque_admin', 'sheikh', 'cashier', 'student']) {
      data.disconnectRole(role);
    }
  });

  Mosque newMosque(String name) =>
      data.addMosque(name: name, address: 'حي الاختبار', city: 'دمشق', gender: 'male', phone: '0911');

  CommunityEvent newLesson(Mosque mosque, {required bool recurring, String? days}) => data.addCommunityEvent(
        mosqueId: mosque.id,
        title: 'درس ${DateTime.now().microsecondsSinceEpoch}',
        description: '',
        eventType: 'lesson',
        timingType: 'custom_time',
        targetAudience: 'general',
        eventDateTime: DateTime.now().add(const Duration(hours: 3)),
        organizerType: 'mosque',
        organizerName: 'إدارة المسجد',
        isRecurring: recurring,
        recurringDays: days,
        isQaEnabled: true,
      );

  /// ينشئ القسم النسائي بالطريق الوحيد: رمز تسليم من إدارة مسجد الرجال.
  Future<Mosque> provisionWomenBranch(Mosque parent) async {
    final token = data.issueWomenProvisionToken(parent.id)!;
    final offer = (await data.inspectWomenProvisionToken(token))!;
    return (await data.redeemWomenProvisionToken(
      offer: offer,
      name: 'القسم النسائي - ${parent.name}',
      city: parent.city,
      address: '',
    ))!;
  }

  CommunityEvent byId(String id) => data.getCommunityEvents().firstWhere((e) => e.id == id);

  group('أرشفة الدرس وتسجيله', () {
    test('درس متكرر: كل جلسة لها سجل أرشيف، وتسجيلها يُربط به هو لا بغيره', () {
      final lesson = newLesson(newMosque('جامع الأرشيف'), recurring: true, days: 'السبت');

      // جلستان انتهتا وتسجيلاهما ينتظران الرفع (لا إنترنت)
      final first = data.finalizeLiveSession(lesson.id)!;
      final second = data.finalizeLiveSession(lesson.id)!;
      expect(first, isNot(second));
      expect(first, startsWith('archived-${lesson.id}-'));

      // يكتمل الرفعان بترتيب معكوس
      data.setEventAudioUrl(second, 'tg:audio:SECOND');
      data.setEventAudioUrl(first, 'tg:audio:FIRST');

      expect(byId(first).audioRecordUrl, 'tg:audio:FIRST');
      expect(byId(second).audioRecordUrl, 'tg:audio:SECOND');
      // الدرس نفسه يبقى قادماً بلا تسجيل
      expect(byId(lesson.id).eventStatus, 'upcoming');
      expect(byId(lesson.id).audioRecordUrl, isNull);
    });

    test('درس لمرة واحدة: يُؤرشف هو نفسه ويحمل تسجيله', () {
      final lesson = newLesson(newMosque('جامع المرة الواحدة'), recurring: false);

      final archiveId = data.finalizeLiveSession(lesson.id);
      data.setEventAudioUrl(archiveId!, 'tg:audio:ONCE');

      expect(archiveId, lesson.id);
      expect(byId(lesson.id).eventStatus, 'archived');
      expect(byId(lesson.id).audioRecordUrl, 'tg:audio:ONCE');
    });

    test('تسجيل نُسب إلى الدرس المتكرر (طابور إصدار أقدم) يصل إلى أحدث جلساته', () {
      final lesson = newLesson(newMosque('جامع الطابور القديم'), recurring: true);
      final snapshot = data.finalizeLiveSession(lesson.id)!;

      data.setEventAudioUrl(lesson.id, 'tg:audio:LEGACY');

      expect(byId(snapshot).audioRecordUrl, 'tg:audio:LEGACY');
    });
  });

  group('أسئلة الدرس', () {
    test('درس متكرر: أسئلة جلسة مضت لا تُعدّ على الجلسة القادمة ولا تُعرض للشيخ', () {
      final lesson = newLesson(newMosque('جامع الأسئلة'), recurring: true);
      data.submitEventQuestion(lesson.id, 'سؤال جلسة اليوم');
      final now = DateTime.now();

      expect(data.getCurrentEventQuestions(lesson, now: now), hasLength(1));
      // بعد ثلاثة أيام (والدرس يومي): السؤال يخص جلسة مضت
      final later = now.add(const Duration(days: 3));
      expect(data.getCurrentEventQuestions(lesson, now: later), isEmpty);
      expect(data.getCurrentEventQuestions(lesson, now: later, forSpeaker: true), isEmpty);
      // ويبقى محفوظاً لم يُحذف
      expect(data.getEventQuestions(lesson.id), hasLength(1));
    });

    test('درس لمرة واحدة: كل أسئلته تبقى له', () {
      final lesson = newLesson(newMosque('جامع الأسئلة 2'), recurring: false);
      data.submitEventQuestion(lesson.id, 'سؤال');

      final later = DateTime.now().add(const Duration(days: 3));
      expect(data.getCurrentEventQuestions(lesson, now: later), hasLength(1));
    });

    test('سؤالان في اللحظة نفسها لا يأخذان المعرّف نفسه', () {
      final lesson = newLesson(newMosque('جامع الأسئلة 3'), recurring: false);

      final ids = {for (var i = 0; i < 40; i++) data.submitEventQuestion(lesson.id, 'سؤال $i').id};

      expect(ids, hasLength(40));
      expect(data.getEventQuestions(lesson.id), hasLength(40));
    });
  });

  group('طابور رفع التسجيلات', () {
    late Directory dir;
    late AudioUploadQueueManager queue;

    File recording(String name) => File('${dir.path}${Platform.pathSeparator}$name')..writeAsBytesSync([1, 2, 3]);

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      dir = Directory.systemTemp.createTempSync('mihrab_upload_queue');
      queue = AudioUploadQueueManager()..retryBase = const Duration(milliseconds: 30);
    });

    tearDown(() {
      try {
        dir.deleteSync(recursive: true);
      } catch (_) {}
    });

    test('رفع فشل (لا إنترنت) يُعاد وحده حتى ينجح، ولا يضيع التسجيل', () async {
      var attempts = 0;
      final uploaded = <String>[];
      queue.debugUploader = (upload, file) async {
        attempts++;
        if (attempts < 3) return false;
        uploaded.add(upload.eventId);
        return true;
      };

      await queue.addToQueue(
        eventId: 'archived-e1-1',
        title: 'درس',
        speaker: 'الشيخ',
        filePath: recording('a.m4a').path,
        durationSeconds: 60,
      );
      expect(queue.queue, hasLength(1));

      final deadline = DateTime.now().add(const Duration(seconds: 5));
      while (queue.queue.isNotEmpty && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }

      expect(attempts, 3);
      expect(uploaded, ['archived-e1-1']);
      expect(queue.queue, isEmpty);
      expect(queue.isUploading, isFalse);
    });

    test('الطابور محفوظ: ما لم يُرفع يعود بعد إعادة فتح التطبيق', () async {
      queue.debugUploader = (_, __) async => false;
      await queue.addToQueue(
        eventId: 'archived-e2-1',
        title: 'درس',
        speaker: 'الشيخ',
        filePath: recording('b.m4a').path,
        durationSeconds: 60,
      );

      final reopened = AudioUploadQueueManager()..retryBase = const Duration(hours: 1);
      final uploaded = <String>[];
      reopened.debugUploader = (upload, _) async {
        uploaded.add(upload.eventId);
        return true;
      };
      await reopened.init();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(uploaded, ['archived-e2-1']);
      expect(reopened.queue, isEmpty);
    });

    test('«أعد المحاولة الآن» (عند المزامنة) لا ينتظر مهلة الإعادة', () async {
      var online = false;
      queue
        ..retryBase = const Duration(hours: 1)
        ..debugUploader = (_, __) async => online;
      await queue.addToQueue(
        eventId: 'archived-e3-1',
        title: 'درس',
        speaker: 'الشيخ',
        filePath: recording('c.m4a').path,
        durationSeconds: 60,
      );
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(queue.queue, hasLength(1));

      online = true;
      queue.retryNow();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(queue.queue, isEmpty);
    });
  });

  group('الفصل بين الرجال والنساء', () {
    test('الحالة النسائية: أي جلسة لقسم نسائي على الجهاز، ولو كانت النشطة غيرها', () async {
      expect(data.isWomenMode, isFalse);
      final parent = newMosque('جامع الفصل');
      final branch = await provisionWomenBranch(parent);

      expect(branch.gender, 'female');
      expect(branch.accessCode, isNot(parent.accessCode));
      expect(data.isWomenMode, isTrue);
      expect(data.canRecordArchive, isFalse);

      // جلسة أخرى لفرع الرجال صارت هي النشطة: الجهاز ما زال في الحالة النسائية
      data.setRoleSession(ActiveSession(role: 'cashier', code: 'CSH-TEST', mosqueId: parent.id, gender: 'male'));
      expect(data.viewerBranch, 'male');
      expect(data.isWomenMode, isTrue);

      data.disconnectRole('mosque_admin');
      expect(data.isWomenMode, isFalse);
    });

    test('رمز القسم النسائي يُستعمل مرة واحدة ويخص المسجد الذي أصدره', () async {
      final parent = newMosque('جامع الرمز');
      final token = data.issueWomenProvisionToken(parent.id)!;

      final offer = await data.inspectWomenProvisionToken(token);
      expect(offer!.parentMosque.id, parent.id);
      final branch = await data.redeemWomenProvisionToken(offer: offer, name: 'القسم النسائي', city: '', address: '');
      expect(branch!.parentMosqueId, parent.id);

      // الرمز استُهلك: لا يفتح شيئاً بعدها
      expect(await data.inspectWomenProvisionToken(token), isNull);
      // والقسم النسائي لا يصدر رمزاً لقسم تحته
      expect(data.issueWomenProvisionToken(branch.id), isNull);
    });

    test('درس القسم النسائي لا يُؤرشف ولا يُربط به تسجيل', () async {
      final parent = newMosque('جامع بلا أرشيف نسائي');
      final branch = await provisionWomenBranch(parent);
      final lesson = data.addCommunityEvent(
        mosqueId: branch.id,
        title: 'درس نسائي',
        description: '',
        eventType: 'lesson',
        timingType: 'custom_time',
        targetAudience: 'female',
        eventDateTime: DateTime.now().add(const Duration(hours: 3)),
        organizerType: 'mosque',
        organizerName: 'إدارة القسم',
        isRecurring: false,
      );

      // حتى من جلسة رجال على الجهاز نفسه
      data.disconnectRole('mosque_admin');
      expect(data.finalizeLiveSession(lesson.id), isNull);
      data.setEventAudioUrl(lesson.id, 'tg:audio:X');

      expect(byId(lesson.id).eventStatus, 'upcoming');
      expect(byId(lesson.id).audioRecordUrl, isNull);
    });
  });

  group('بوابة التفويض: بطاقة القسم النسائي', () {
    Future<void> pumpPortal(WidgetTester tester) async {
      tester.view.physicalSize = const Size(420, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ChangeNotifierProvider<DataService>.value(
          value: data,
          child: MaterialApp(home: ManagementPortalScreen(onSessionUnlocked: (_) {})),
        ),
      );
      await tester.pump();
    }

    Future<void> openCard(WidgetTester tester, String cardTitle) async {
      final card = find.ancestor(of: find.text(cardTitle), matching: find.byType(Container)).first;
      final scan = find.descendant(of: card, matching: find.text('مسح رمز QR أو إدخال الكود'));
      await tester.ensureVisible(scan);
      await tester.pump();
      await tester.tap(scan);
      await tester.pumpAndSettle();
    }

    Future<void> submit(WidgetTester tester, String code) async {
      await tester.enterText(find.byType(TextField), code);
      await tester.tap(find.text('تأكيد الدخول المعتمد'));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
      await tester.pumpAndSettle();
    }

    testWidgets('للقسم النسائي مكانه في البوابة، ويقبل رمز التسليم وحده', (tester) async {
      final parent = newMosque('جامع البوابة');
      await pumpPortal(tester);
      expect(find.text('القسم النسائي (إدارة النساء)'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await openCard(tester, 'القسم النسائي (إدارة النساء)');
      expect(find.text('رمز القسم النسائي'), findsOneWidget);

      // كود إدارة المسجد نفسه لا يُقبل هنا ولا يفتح جلسة
      await submit(tester, parent.accessCode);
      expect(find.textContaining('يقبل رمز القسم النسائي فقط'), findsOneWidget);
      expect(data.getSessionForRole('mosque_admin'), isNull);

      // رمز لم تصدره أي إدارة
      await submit(tester, 'WMV-ZZZZ9999');
      expect(find.textContaining('رمز القسم النسائي غير صالح'), findsOneWidget);
      expect(find.byType(WomenBranchSetupDialog), findsNothing);
    });

    testWidgets('رمز صادر من إدارة المسجد يفتح إنشاء الإدارة النسائية باسم ذلك المسجد', (tester) async {
      final parent = newMosque('جامع التسليم');
      final token = data.issueWomenProvisionToken(parent.id)!;
      await pumpPortal(tester);

      await openCard(tester, 'القسم النسائي (إدارة النساء)');
      await submit(tester, token);

      expect(find.byType(WomenBranchSetupDialog), findsOneWidget);
      expect(find.textContaining('الرمز صادر من: جامع التسليم'), findsOneWidget);
    });

    testWidgets('رمز القسم النسائي لا يُفتح من بطاقة صفة أخرى', (tester) async {
      final parent = newMosque('جامع البطاقات');
      final token = data.issueWomenProvisionToken(parent.id)!;
      await pumpPortal(tester);

      await openCard(tester, 'الشيخ المحفظ وإدارة الحلقة');
      await submit(tester, token);

      expect(find.byType(WomenBranchSetupDialog), findsNothing);
      expect(find.textContaining('بطاقة «القسم النسائي»'), findsOneWidget);
      // الرمز لم يُستهلك
      expect(await tester.runAsync(() => data.inspectWomenProvisionToken(token)), isNotNull);
    });
  });

  group('تعديل معلومات المسجد', () {
    test('الاسم الجديد يصل إلى الجلسات المحفوظة', () {
      final mosque = newMosque('جامع الاسم القديم');
      data.setRoleSession(ActiveSession(
        role: 'mosque_admin',
        code: mosque.accessCode,
        name: 'مدير ${mosque.name}',
        mosqueId: mosque.id,
        mosqueName: mosque.name,
        gender: 'male',
      ));

      data.updateMosque(
        id: mosque.id,
        name: 'جامع الاسم الجديد',
        address: 'حي آخر',
        city: 'حلب',
        phone: '0999',
      );

      final updated = data.getMosqueById(mosque.id)!;
      expect((updated.name, updated.city, updated.address, updated.phone), ('جامع الاسم الجديد', 'حلب', 'حي آخر', '0999'));
      // لم يتغيّر الموقع ولا الكود
      expect((updated.latitude, updated.longitude, updated.accessCode),
          (mosque.latitude, mosque.longitude, mosque.accessCode));
      final session = data.getSessionForRole('mosque_admin')!;
      expect(session.mosqueName, 'جامع الاسم الجديد');
      expect(session.name, 'مدير جامع الاسم الجديد');
    });

    testWidgets('نافذة التعديل تعرض ما أُدخل عند الإنشاء وتحفظ التغيير', (tester) async {
      final mosque = newMosque('جامع النافذة');
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ChangeNotifierProvider<DataService>.value(
          value: data,
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => MosqueInfoEditDialog.show(context, mosque),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextField, 'جامع النافذة'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'دمشق'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'حي الاختبار'), findsOneWidget);
      expect(find.widgetWithText(TextField, '0911'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // الاسم لا يُترك فارغاً
      await tester.enterText(find.widgetWithText(TextField, 'جامع النافذة'), '   ');
      await tester.tap(find.text('حفظ'));
      await tester.pump();
      expect(find.text('اسم المسجد مطلوب'), findsOneWidget);
      expect(data.getMosqueById(mosque.id)!.name, 'جامع النافذة');

      await tester.enterText(find.byType(TextField).first, 'جامع النافذة المعدَّل');
      await tester.enterText(find.widgetWithText(TextField, '0911'), '0933');
      await tester.tap(find.text('حفظ'));
      await tester.pumpAndSettle();

      final updated = data.getMosqueById(mosque.id)!;
      expect((updated.name, updated.phone, updated.city), ('جامع النافذة المعدَّل', '0933', 'دمشق'));
      expect(find.byType(MosqueInfoEditDialog), findsNothing);
    });
  });
}
