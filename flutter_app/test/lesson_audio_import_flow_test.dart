import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_app/core/di/injection.dart';
import 'package:flutter_app/models/models.dart';
import 'package:flutter_app/screens/discover/lesson_audio_import_flow.dart';
import 'package:flutter_app/screens/discover/widgets/lesson_record_split_button.dart';
import 'package:flutter_app/screens/discover_screen.dart';
import 'package:flutter_app/services/audio_upload_queue_manager.dart';
import 'package:flutter_app/services/data_service.dart';
import 'package:flutter_app/services/lesson_audio_engine.dart';

/// محرّك وهمي: يقيس مدة محددة ويكتب ملفاً صغيراً لكل جزء.
class _FakeEngine implements LessonAudioEngine {
  final Duration? total;
  _FakeEngine(this.total);

  @override
  Future<Duration?> probe(String path) async => total;

  @override
  Future<Duration?> compress(String input, String output, {Duration start = Duration.zero, Duration? length}) async {
    final written = length ?? (total! - start);
    File(output).writeAsBytesSync(List.filled(64, 3));
    return written;
  }
}

/// رفع تسجيل درس من ملف صوتي: الزر المقسوم في قائمة الدروس، ومسار الرفع بقواعد التسجيل
/// المباشر (أجزاء ساعة، أرشفة، طابور رفع).
void main() {
  late DataService data;
  late Directory tmp;
  late File source;
  late List<PendingUpload> uploads;

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
    tmp = Directory.systemTemp.createTempSync('mihrab_import_flow');
    source = File('${tmp.path}${Platform.pathSeparator}lesson.mp3')..writeAsBytesSync([9, 9, 9]);
    uploads = [];
    // لا رفع حقيقي إلى تيليجرام: نسجّل ما وصل إلى الطابور فقط
    data.audioUploadQueue.debugUploader = (upload, file) async {
      uploads.add(upload);
      return true;
    };
  });

  tearDown(() {
    data.audioUploadQueue.debugUploader = null;
    tmp.deleteSync(recursive: true);
  });

  Mosque newMosque({String gender = 'male'}) =>
      data.addMosque(name: 'جامع الرفع', address: '', city: 'دمشق', gender: gender);

  CommunityEvent lesson(Mosque mosque, {bool recurring = false, Duration ahead = const Duration(hours: 2)}) =>
      data.addCommunityEvent(
        mosqueId: mosque.id,
        title: 'شرح رياض الصالحين',
        description: '',
        eventType: 'lesson',
        timingType: 'custom_time',
        targetAudience: 'general',
        eventDateTime: DateTime.now().add(ahead),
        organizerType: 'mosque',
        organizerName: 'الشيخ أحمد',
        isRecurring: recurring,
        recurringDays: recurring ? 'السبت, الاثنين, الأربعاء' : null,
      );

  CommunityEvent byId(String id) => data.getCommunityEvents().firstWhere((e) => e.id == id);

  void signInAdmin(Mosque mosque) => data.setRoleSession(ActiveSession(
        role: 'mosque_admin',
        code: 'ADM-${mosque.id}',
        name: 'مدير المسجد',
        mosqueId: mosque.id,
        gender: 'male',
      ));

  // زر يشغّل المسار كما تفعل بطاقة الدرس
  Future<BuildContext> pumpHost(WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<DataService>.value(
        value: data,
        child: const MaterialApp(home: Scaffold(body: SizedBox.expand())),
      ),
    );
    return tester.element(find.byType(Scaffold));
  }

  Future<void> settle(WidgetTester tester) async {
    // تبقى عمليات الملفات الحقيقية خارج ساعة الاختبار الوهمية
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
    await tester.pump();
  }

  group('الزر المقسوم', () {
    Widget host(Widget child, {double width = 400, TextDirection dir = TextDirection.rtl}) => MaterialApp(
          home: Directionality(
            textDirection: dir,
            child: Scaffold(body: Center(child: SizedBox(width: width, child: Align(alignment: Alignment.centerRight, child: child)))),
          ),
        );

    testWidgets('نصفان: بدء الدرس ورفع ملف صوتي، ولكل منهما فعله', (tester) async {
      var recorded = 0, imported = 0;
      await tester.pumpWidget(host(LessonRecordSplitButton(
        isLive: false,
        onRecord: () => recorded++,
        onImport: () => imported++,
      )));

      expect(find.text('بدء الدرس 🎙️'), findsOneWidget);
      expect(find.text('رفع ملف صوتي'), findsOneWidget);

      await tester.tap(find.byKey(LessonRecordSplitButton.recordKey));
      expect((recorded, imported), (1, 0));
      await tester.tap(find.byKey(LessonRecordSplitButton.importKey));
      expect((recorded, imported), (1, 1));
    });

    testWidgets('الدرس جارٍ: نصف التسجيل يصير «متابعة البث» ونصف الرفع يبقى', (tester) async {
      await tester.pumpWidget(host(LessonRecordSplitButton(isLive: true, onRecord: () {}, onImport: () {})));

      expect(find.text('متابعة البث 🔴'), findsOneWidget);
      expect(find.text('بدء الدرس 🎙️'), findsNothing);
      expect(find.text('رفع ملف صوتي'), findsOneWidget);
    });

    testWidgets('على هاتف ضيق (280) وبخط مكبَّر: لا تجاوز ولا انهيار', (tester) async {
      tester.view.physicalSize = const Size(280, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.4)),
          child: child!,
        ),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(children: [LessonRecordSplitButton(isLive: false, onRecord: () {}, onImport: () {})]),
            ),
          ),
        ),
      ));

      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(LessonRecordSplitButton)).width, lessThanOrEqualTo(280 - 32));
    });

    testWidgets('النصفان متجاوران بالارتفاع نفسه (زر واحد)', (tester) async {
      await tester.pumpWidget(host(LessonRecordSplitButton(isLive: false, onRecord: () {}, onImport: () {})));

      final record = tester.getRect(find.byKey(LessonRecordSplitButton.recordKey));
      final import = tester.getRect(find.byKey(LessonRecordSplitButton.importKey));
      expect(record.height, import.height);
      expect(record.top, import.top);
      // في الاتجاه من اليمين لليسار: التسجيل أولاً (يميناً) ثم الرفع إلى يساره
      expect(record.center.dx, greaterThan(import.center.dx));
    });
  });

  group('في بطاقة الدرس', () {
    Future<void> pumpDiscover(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ChangeNotifierProvider<DataService>.value(
          value: data,
          child: MaterialApp(home: Scaffold(body: DiscoverScreen(onOpenScanner: () {}))),
        ),
      );
      await tester.pump();
    }

    testWidgets('مدير المسجد يرى النصفين على درسه', (tester) async {
      final mosque = newMosque();
      lesson(mosque);
      signInAdmin(mosque);

      await pumpDiscover(tester);

      expect(find.byType(LessonRecordSplitButton), findsOneWidget);
      expect(find.text('رفع ملف صوتي'), findsOneWidget);
      expect(find.text('بدء الدرس 🎙️'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('الزائر لا يرى أيّاً منهما', (tester) async {
      lesson(newMosque());

      await pumpDiscover(tester);

      expect(find.byType(LessonRecordSplitButton), findsNothing);
      expect(find.text('رفع ملف صوتي'), findsNothing);
    });
  });

  group('مسار الرفع', () {
    testWidgets('درس بساعتين ونصف: يُؤرشف، وثلاثة أجزاء بسجلاتها في طابور الرفع', (tester) async {
      final mosque = newMosque();
      final ev = lesson(mosque, ahead: const Duration(minutes: -20));
      final context = await pumpHost(tester);

      await tester.runAsync(() => LessonAudioImportFlow.start(
        context,
        data,
        ev,
        picker: () async => PickedLessonFile(source.path, 'lesson.mp3'),
        engine: _FakeEngine(const Duration(minutes: 150)),
        outDir: '${tmp.path}${Platform.pathSeparator}out',
      ));
      await settle(tester);

      expect(find.byKey(const ValueKey('lessonImportBusy')), findsNothing);
      expect(find.textContaining('3 أجزاء'), findsOneWidget);

      // الجزء الأول هو الدرس نفسه (مرة واحدة فتؤرشف)، والباقيان لقطتان «— الجزء n»
      expect(byId(ev.id).eventStatus, 'archived');
      expect(uploads, hasLength(3));
      expect(uploads.map((u) => u.title), [
        'شرح رياض الصالحين',
        'شرح رياض الصالحين — الجزء 2',
        'شرح رياض الصالحين — الجزء 3',
      ]);
      expect(uploads.map((u) => u.durationSeconds), [3600, 3600, 1800]);
      expect(uploads.map((u) => u.kind), everyElement(UploadKind.audio));
      expect(uploads[0].eventId, ev.id);
      expect(uploads[1].eventId, startsWith('archived-${ev.id}-p2-'));
      expect(uploads[2].eventId, startsWith('archived-${ev.id}-p3-'));
      expect(byId(uploads[1].eventId).title, 'شرح رياض الصالحين — الجزء 2');
      // وملف المستخدم الأصلي لم يُمسّ
      expect(source.readAsBytesSync(), [9, 9, 9]);
    });

    testWidgets('درس قصير لمتكرر: جزء واحد، ويبقى الدرس قادماً بموعده التالي', (tester) async {
      final mosque = newMosque();
      final ev = lesson(mosque, recurring: true, ahead: const Duration(minutes: -20));
      final context = await pumpHost(tester);

      await tester.runAsync(() => LessonAudioImportFlow.start(
        context,
        data,
        ev,
        picker: () async => PickedLessonFile(source.path, 'lesson.mp3'),
        engine: _FakeEngine(const Duration(minutes: 42)),
        outDir: '${tmp.path}${Platform.pathSeparator}out',
      ));
      await settle(tester);

      expect(find.text('تم ضغط التسجيل وحفظه ✨ سيُرفع لمكتبة الدروس تلقائياً فور توفر الإنترنت.'), findsOneWidget);
      expect(uploads, hasLength(1));
      expect(uploads.single.durationSeconds, 42 * 60);
      expect(uploads.single.eventId, startsWith('archived-${ev.id}-'));
      expect(byId(ev.id).eventStatus, 'upcoming');
      expect(byId(uploads.single.eventId).eventStatus, 'archived');
    });

    testWidgets('إلغاء الاختيار: لا شيء يتغير ولا نافذة', (tester) async {
      final mosque = newMosque();
      final ev = lesson(mosque);
      final context = await pumpHost(tester);

      await tester.runAsync(() => LessonAudioImportFlow.start(
        context,
        data,
        ev,
        picker: () async => null,
        engine: _FakeEngine(const Duration(minutes: 42)),
        outDir: '${tmp.path}${Platform.pathSeparator}out',
      ));
      await settle(tester);

      expect(find.byType(AlertDialog), findsNothing);
      expect(uploads, isEmpty);
      expect(byId(ev.id).eventStatus, isNot('archived'));
    });

    testWidgets('ملف فيديو أو مستند: رسالة واضحة، ولا يُؤرشف الدرس', (tester) async {
      final mosque = newMosque();
      final ev = lesson(mosque);
      final context = await pumpHost(tester);

      late Future<void> done;
      await tester.runAsync(() async {
        done = LessonAudioImportFlow.start(
          context,
          data,
          ev,
          picker: () async => PickedLessonFile(source.path, 'lesson.mp4'),
          engine: _FakeEngine(const Duration(minutes: 42)),
          outDir: '${tmp.path}${Platform.pathSeparator}out',
        );
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.textContaining('ليس تسجيلاً صوتياً'), findsOneWidget);
      expect(find.byKey(const ValueKey('lessonImportBusy')), findsNothing);

      await tester.tap(find.text('حسناً'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.runAsync(() => done);

      expect(uploads, isEmpty);
      expect(byId(ev.id).eventStatus, isNot('archived'));
      expect(Directory('${tmp.path}${Platform.pathSeparator}out').existsSync() ? Directory('${tmp.path}${Platform.pathSeparator}out').listSync() : <FileSystemEntity>[], isEmpty);
    });

    testWidgets('القسم النسائي لا يرفع تسجيلاً: لا يُفتح المنتقي أصلاً ولا يُؤرشف شيء', (tester) async {
      final branch = newMosque(gender: 'female');
      final ev = lesson(branch);
      final context = await pumpHost(tester);
      var pickerOpened = false;

      await LessonAudioImportFlow.start(
        context,
        data,
        ev,
        picker: () async {
          pickerOpened = true;
          return PickedLessonFile(source.path, 'lesson.mp3');
        },
        engine: _FakeEngine(const Duration(minutes: 42)),
        outDir: '${tmp.path}${Platform.pathSeparator}out',
      );
      await tester.pump();

      expect(pickerOpened, isFalse);
      expect(find.textContaining('غير متاح للقسم النسائي'), findsOneWidget);
      expect(uploads, isEmpty);
      expect(byId(ev.id).eventStatus, isNot('archived'));
    });

    testWidgets('ضغطتان متتاليتان على الزر: مسار واحد لا اثنان', (tester) async {
      final mosque = newMosque();
      final ev = lesson(mosque, ahead: const Duration(minutes: -20));
      final context = await pumpHost(tester);
      var opened = 0;

      Future<void> press() => LessonAudioImportFlow.start(
            context,
            data,
            ev,
            picker: () async {
              opened++;
              await Future<void>.delayed(const Duration(milliseconds: 50));
              return PickedLessonFile(source.path, 'lesson.mp3');
            },
            engine: _FakeEngine(const Duration(minutes: 10)),
            outDir: '${tmp.path}${Platform.pathSeparator}out',
          );

      await tester.runAsync(() async {
        final first = press();
        final second = press();
        await Future.wait([first, second]);
      });
      await settle(tester);

      expect(opened, 1);
      expect(uploads, hasLength(1));
    });
  });
}
