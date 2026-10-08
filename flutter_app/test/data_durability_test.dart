import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_app/core/utils/access_code_generator.dart';
import 'package:flutter_app/data/datasources/datasources.dart';
import 'package:flutter_app/models/models.dart';
import 'package:flutter_app/services/data_service.dart';
import 'package:flutter_app/services/prefs_file_guard.dart';

/// خادم وهمي: يُقطع عنه الاتصال، يرفض سجلاً بعينه، ثم يعود.
class ScriptedRemote extends SupabaseRemoteDataSource {
  /// خطأ يُرمى مع كل عملية ما دام غير فارغ (شبكة مقطوعة، خادم مشغول...).
  Object? failure;

  /// معرّفات يرفضها الخادم نفسه رفضاً نهائياً.
  final Set<String> rejectedIds = {};
  final List<String> uploaded = [];
  int attempts = 0;

  @override
  SupabaseClient? get client => Supabase.instance.client;

  Future<void> _send(String label, String? id) async {
    attempts++;
    final f = failure;
    if (f != null) throw f;
    if (id != null && rejectedIds.contains(id)) {
      throw const PostgrestException(message: 'violates check constraint', code: '23514');
    }
    uploaded.add(label);
  }

  @override
  Future<void> upsert(String table, Map<String, dynamic> data) =>
      _send('upsert:$table:${data['id']}', data['id']?.toString());

  @override
  Future<void> update(
    String table,
    Map<String, dynamic> data, {
    required String matchingColumn,
    required dynamic matchingValue,
  }) =>
      _send('patch:$table:$matchingValue', matchingValue?.toString());

  @override
  Future<void> delete(
    String table, {
    required String matchingColumn,
    required dynamic matchingValue,
  }) =>
      _send('delete:$table:$matchingValue', null);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await SupabaseRemoteDataSource().initialize();
  });

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('طابور المزامنة: تعديل أُجري بلا إنترنت لا يُرمى أبداً', () {
    test('تصنيف الأخطاء: الشبكة والخادم المشغول عابران، ورفض السجل نهائي', () {
      bool transient(Object e) => OfflineSyncQueueManager.isTransientError(e);

      expect(transient(const SocketException('Failed host lookup')), isTrue);
      expect(transient(Exception('ClientException: Connection closed')), isTrue);
      expect(transient(const PostgrestException(message: 'Bad Gateway', code: '502')), isTrue);
      expect(transient(const PostgrestException(message: 'Service Unavailable', code: '503')), isTrue);
      expect(transient(const PostgrestException(message: 'Too Many Requests', code: '429')), isTrue);
      expect(transient(const PostgrestException(message: 'JWT expired', code: 'PGRST301')), isTrue);
      expect(transient(const PostgrestException(message: 'no connection to db', code: 'PGRST000')), isTrue);
      expect(transient(const PostgrestException(message: 'too many connections', code: '53300')), isTrue);
      expect(transient(const PostgrestException(message: 'statement timeout', code: '57014')), isTrue);

      expect(transient(const PostgrestException(message: 'Bad Request', code: '400')), isFalse);
      expect(transient(const PostgrestException(message: 'unknown column', code: 'PGRST204')), isFalse);
      expect(transient(const PostgrestException(message: 'null value', code: '23502')), isFalse);
      expect(transient(const PostgrestException(message: 'row-level security', code: '42501')), isFalse);
    });

    test('انقطاع طويل: مئة محاولة فاشلة لا تُسقط شيئاً، وعند عودة الاتصال يُرفع الكل بترتيبه', () async {
      final queue = OfflineSyncQueueManager();
      final remote = ScriptedRemote()..failure = const SocketException('Failed host lookup');
      for (var i = 0; i < 5; i++) {
        queue.queueSync(table: 'students', action: 'upsert', data: {'id': 's$i', 'full_name': 'طالب $i'});
      }

      for (var attempt = 0; attempt < 100; attempt++) {
        await queue.processQueue(remote);
      }
      expect(queue.pendingQueue, hasLength(5));
      expect(remote.uploaded, isEmpty);
      for (var i = 0; i < 5; i++) {
        expect(queue.isPendingUpsert('students', 's$i'), isTrue);
      }

      remote.failure = null;
      await queue.processQueue(remote);

      expect(queue.pendingQueue, isEmpty);
      expect(remote.uploaded, [for (var i = 0; i < 5; i++) 'upsert:students:s$i']);
    });

    test('الخادم مشغول (503) كانقطاع الشبكة: لا إسقاط', () async {
      final queue = OfflineSyncQueueManager();
      final remote = ScriptedRemote()
        ..failure = const PostgrestException(message: 'Service Unavailable', code: '503');
      queue.queueSync(table: 'attendance', action: 'upsert', data: {'id': 'a1'});

      for (var attempt = 0; attempt < 20; attempt++) {
        await queue.processQueue(remote);
      }
      expect(queue.pendingQueue, hasLength(1));

      remote.failure = null;
      await queue.processQueue(remote);
      expect(remote.uploaded, ['upsert:attendance:a1']);
    });

    test('اتصال معلّق: المهلة تُنهيه ويبقى السجل في الطابور', () async {
      final queue = OfflineSyncQueueManager();
      final previous = OfflineSyncQueueManager.requestTimeout;
      OfflineSyncQueueManager.requestTimeout = const Duration(milliseconds: 40);
      addTearDown(() => OfflineSyncQueueManager.requestTimeout = previous);
      final remote = _HangingRemote();
      queue.queueSync(table: 'students', action: 'upsert', data: {'id': 'slow'});

      await queue.processQueue(remote);

      expect(queue.isProcessingQueue, isFalse);
      expect(queue.pendingQueue, hasLength(1));
    });

    test('سجل يرفضه الخادم نفسه يُزال ويُسجَّل، ولا يحجز ما بعده', () async {
      final queue = OfflineSyncQueueManager();
      final remote = ScriptedRemote()..rejectedIds.add('bad');
      queue.queueSync(table: 'students', action: 'upsert', data: {'id': 'ok1'});
      queue.queueSync(table: 'students', action: 'upsert', data: {'id': 'bad'});
      queue.queueSync(table: 'students', action: 'upsert', data: {'id': 'ok2'});

      await queue.processQueue(remote);

      expect(queue.pendingQueue, isEmpty);
      expect(remote.uploaded, ['upsert:students:ok1', 'upsert:students:ok2']);
      final rejected = await OfflineSyncQueueManager.rejectedLog();
      expect(rejected, hasLength(1));
      expect(rejected.single['id'], 'bad');
      expect(rejected.single['table'], 'students');
      expect(rejected.single['error'], contains('23514'));
    });

    test('سجل يردّ عليه الخادم بخطأ طويلاً لا يُسقط ولا يحجز غيره، وتعديلاته اللاحقة تنتظره', () async {
      final queue = OfflineSyncQueueManager();
      final remote = _OneRowBrokenRemote('poison');
      queue.queueSync(table: 'students', action: 'upsert', data: {'id': 'poison', 'v': 1});
      queue.queueSync(table: 'students', action: 'upsert', data: {'id': 'poison', 'v': 2});
      queue.queueSync(table: 'students', action: 'upsert', data: {'id': 'fine'});

      for (var attempt = 0; attempt < OfflineSyncQueueManager.stuckAfter + 2; attempt++) {
        await queue.processQueue(remote);
      }

      // السليم رُفع، والمعطوب باقٍ بنسختيه وبترتيبهما
      expect(remote.uploaded, ['upsert:students:fine']);
      expect(queue.pendingQueue.map((i) => i['data']['v']), [1, 2]);
      expect(queue.isPendingUpsert('students', 'poison'), isTrue);

      remote.broken = false;
      await queue.processQueue(remote);
      expect(queue.pendingQueue, isEmpty);
      expect(remote.uploaded, ['upsert:students:fine', 'upsert:students:poison', 'upsert:students:poison']);
    });

    test('سجل عالق لا يُسقط توابعه: حركة نقاط لطالب لم يُرفع بعد تبقى معه حتى يُرفع', () async {
      final queue = OfflineSyncQueueManager();
      final remote = _ParentStuckRemote();
      queue.queueSync(table: 'students', action: 'upsert', data: {'id': 'st1'});
      queue.queueSync(table: 'points_logs', action: 'upsert', data: {'id': 'log1', 'student_id': 'st1'});
      queue.queueSync(table: 'rewards', action: 'upsert', data: {'id': 'rw1'});

      for (var attempt = 0; attempt < OfflineSyncQueueManager.stuckAfter + 3; attempt++) {
        await queue.processQueue(remote);
      }

      // المستقل عن العالق رُفع، والعالق وتابعه باقيان بترتيبهما ولم يُسجَّل شيء مرفوضاً
      expect(remote.uploaded, ['upsert:rewards:rw1']);
      expect(queue.pendingQueue.map((i) => i['data']['id']), ['st1', 'log1']);
      expect(await OfflineSyncQueueManager.rejectedLog(), isEmpty);

      remote.parentStuck = false;
      await queue.processQueue(remote);
      expect(queue.pendingQueue, isEmpty);
      expect(remote.uploaded, ['upsert:rewards:rw1', 'upsert:students:st1', 'upsert:points_logs:log1']);
    });

    test('تابعٌ أصله محذوف من الخادم (لا شيء عالق): يُزال ويُسجَّل', () async {
      final queue = OfflineSyncQueueManager();
      final remote = _ParentStuckRemote()..parentStuck = false..parentExists = false;
      queue.queueSync(table: 'points_logs', action: 'upsert', data: {'id': 'orphan', 'student_id': 'gone'});

      await queue.processQueue(remote);

      expect(queue.pendingQueue, isEmpty);
      expect((await OfflineSyncQueueManager.rejectedLog()).single['id'], 'orphan');
    });

    test('الطابور يبقى بعد إغلاق التطبيق وفتحه بلا إنترنت', () async {
      final queue = OfflineSyncQueueManager();
      final remote = ScriptedRemote()..failure = const SocketException('offline');
      queue.queueSync(table: 'memorization_records', action: 'upsert', data: {'id': 'm1'});
      for (var attempt = 0; attempt < 10; attempt++) {
        await queue.processQueue(remote);
      }
      await queue.saveQueue();

      final reopened = OfflineSyncQueueManager();
      await reopened.loadQueue();

      expect(reopened.pendingQueue, hasLength(1));
      expect(reopened.isPendingUpsert('memorization_records', 'm1'), isTrue);
    });
  });

  group('المعرّفات لا تتكرر', () {
    test('ألف معرّف في اللحظة نفسها كلها مختلفة', () {
      final ids = {for (var i = 0; i < 1000; i++) AccessCodeGenerator.entityId('att')};
      expect(ids, hasLength(1000));
      expect(ids.every((id) => RegExp(r'^att-\d+-[A-Z2-9]{8}$').hasMatch(id)), isTrue);
    });

    test('تسجيل حضور حلقة كاملة دفعة واحدة: سجل ومعرّف لكل طالب', () async {
      final data = DataService();
      await data.init();
      final mosque = data.addMosque(name: 'جامع المعرّفات', address: '', city: 'دمشق', gender: 'male');
      final sheikh = data.addSheikh(mosque.id, 'الشيخ', '0999');
      final halaqa = data.addHalaqa(mosqueId: mosque.id, name: 'حلقة', sheikhId: sheikh.id);
      final students = [
        for (var i = 0; i < 40; i++)
          data.addStudent(
              mosqueId: mosque.id, halaqaId: halaqa.id, fullName: 'طالب $i', gender: 'male', phone: ''),
      ];

      for (final s in students) {
        data.recordAttendance(
            studentId: s.id, halaqaId: halaqa.id, sessionDate: '2026-10-06', status: 'present', pointsEarned: 5);
      }

      final records = data.getAttendanceForDate(halaqa.id, '2026-10-06');
      expect(records, hasLength(40));
      expect(records.map((r) => r.id).toSet(), hasLength(40));
      expect(records.map((r) => r.studentId).toSet(), hasLength(40));
      expect(students.map((s) => s.id).toSet(), hasLength(40));
      final logs = [for (final s in students) ...data.getStudentPointsLog(s.id)];
      expect(logs.map((l) => l.id).toSet(), hasLength(logs.length));
      expect(logs, hasLength(40));
    });
  });

  group('التخزين المحلي', () {
    test('سجل واحد تالف لا يُسقط بقية القائمة ولا القوائم التي بعدها', () async {
      final mosque = Mosque(id: 'm1', name: 'جامع', city: 'دمشق', gender: 'male', accessCode: 'MSQ-AAAA2222');
      final good = Student(
          id: 'st1', mosqueId: 'm1', halaqaId: 'h1', fullName: 'سليم', gender: 'male', phone: '', code: 'STD-1');
      SharedPreferences.setMockInitialValues({
        'real_mosques': jsonEncode([mosque.toJson()]),
        // سجل ليس خريطة أصلاً، بين سجلين سليمين
        'real_students': jsonEncode([
          good.toJson(),
          'تالف',
          (Student(
                  id: 'st2',
                  mosqueId: 'm1',
                  halaqaId: 'h1',
                  fullName: 'سليم آخر',
                  gender: 'male',
                  phone: '',
                  code: 'STD-2'))
              .toJson(),
        ]),
        // قائمة كاملة غير مقروءة
        'real_events': '{not json',
        'real_rewards': jsonEncode([
          Reward(id: 'r1', mosqueId: 'm1', title: 'حقيبة', pointsCost: 50, createdAt: DateTime(2026)).toJson(),
        ]),
      });

      final store = LocalStorageDataSource();
      await store.loadAllFromStorage();

      expect(store.mosques.map((m) => m.id), ['m1']);
      expect(store.students.map((s) => s.id), ['st1', 'st2']);
      // القائمة التي بعد التالفة ما زالت تُقرأ
      expect(store.rewards.map((r) => r.id), ['r1']);

      final prefs = await SharedPreferences.getInstance();
      // الأصل التالف محفوظ جانباً قبل أن يُكتب فوقه
      expect(prefs.getString('real_events.damaged'), '{not json');
      expect(prefs.getString('real_students.damaged'), contains('تالف'));

      await store.saveToStorage();
      final saved = jsonDecode(prefs.getString('real_students')!) as List;
      expect(saved, hasLength(2));
      expect((jsonDecode(prefs.getString('real_rewards')!) as List), hasLength(1));
    });

    test('الحفظ يكتب ما تغيّر فقط، ويقرأ التطبيق بعد إعادة فتحه ما حُفظ', () async {
      final store = LocalStorageDataSource();
      await store.loadAllFromStorage();
      store.mosques.add(Mosque(id: 'm1', name: 'جامع', city: 'دمشق', gender: 'male', accessCode: 'MSQ-AAAA2222'));
      await store.saveToStorage();

      final prefs = await SharedPreferences.getInstance();
      // قيمة حارسة: إن أعاد الحفظ كتابة المفتاح ستختفي
      await prefs.setString('real_sheikhs', 'SENTINEL');
      await prefs.setString('real_mosques', 'SENTINEL');

      // لا تغيير في الذاكرة: لا يُكتب شيء
      await store.saveToStorage();
      expect(prefs.getString('real_sheikhs'), 'SENTINEL');
      expect(prefs.getString('real_mosques'), 'SENTINEL');

      // تغيير في المساجد وحدها: تُكتب هي وحدها
      store.mosques[0] = store.mosques[0].copyWith(name: 'جامع الروضة');
      await store.saveToStorage();
      expect(prefs.getString('real_sheikhs'), 'SENTINEL');
      expect(prefs.getString('real_mosques'), contains('جامع الروضة'));

      await prefs.setString('real_sheikhs', '[]');
      final reopened = LocalStorageDataSource();
      await reopened.loadAllFromStorage();
      expect(reopened.mosques.single.name, 'جامع الروضة');
    });

    test('بعد المسح الكامل يُعاد حفظ كل شيء', () async {
      final store = LocalStorageDataSource();
      store.mosques.add(Mosque(id: 'm1', name: 'جامع', city: 'دمشق', gender: 'male', accessCode: 'MSQ-AAAA2222'));
      await store.saveToStorage();
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      store.forgetWrittenValues();

      await store.saveToStorage();

      expect(prefs.getString('real_mosques'), contains('m1'));
    });

    test('أكثر من صراف على الجهاز: الجلسات كلها تعود بعد إعادة الفتح', () async {
      final store = LocalStorageDataSource();
      store.savedSessions.addAll([
        ActiveSession(role: 'cashier', code: 'CSH-AAAA2222', mosqueId: 'm1', mosqueName: 'الأول'),
        ActiveSession(role: 'cashier', code: 'CSH-BBBB3333', mosqueId: 'm2', mosqueName: 'الثاني'),
        ActiveSession(role: 'mosque_admin', code: 'MSQ-CCCC4444', mosqueId: 'm3', mosqueName: 'الثالث'),
      ]);
      store.currentSession = store.savedSessions[1];
      await store.saveToStorage();

      final reopened = LocalStorageDataSource();
      await reopened.loadAllFromStorage();

      expect(reopened.savedSessions.map((s) => s.code), ['CSH-AAAA2222', 'CSH-BBBB3333', 'MSQ-CCCC4444']);
      expect(reopened.currentSession!.code, 'CSH-BBBB3333');
    });
  });

  group('حارس ملف الإعدادات على ويندوز (انقطاع الكهرباء)', () {
    late Directory dir;
    File file(String name) => File('${dir.path}${Platform.pathSeparator}$name');

    setUp(() => dir = Directory.systemTemp.createTempSync('mihrab_prefs_guard_'));
    tearDown(() {
      PrefsFileGuard.dispose();
      try {
        dir.deleteSync(recursive: true);
      } catch (_) {}
    });

    const good = '{"flutter.saved_sessions":"[]","flutter.palette_id":"kaaba"}';

    test('تثبيت جديد: لا ملف ولا مرآة، ولا يُنشأ شيء', () {
      expect(PrefsFileGuard.repair(dir), PrefsFileState.healthy);
      expect(file(PrefsFileGuard.fileName).existsSync(), isFalse);
    });

    test('ملف سليم يبقى كما هو', () {
      file(PrefsFileGuard.fileName).writeAsStringSync(good);
      expect(PrefsFileGuard.repair(dir), PrefsFileState.healthy);
      expect(file(PrefsFileGuard.fileName).readAsStringSync(), good);
    });

    for (final damaged in <String, List<int>>{
      'مبتور في منتصفه': utf8.encode(good.substring(0, good.length ~/ 2)),
      'فارغ': <int>[],
      'أصفار بعد انقطاع الكهرباء': List<int>.filled(4096, 0),
    }.entries) {
      test('ملف ${damaged.key}: يُستعاد من النسخة المرآة', () {
        file(PrefsFileGuard.fileName).writeAsBytesSync(damaged.value);
        file(PrefsFileGuard.mirrorName).writeAsStringSync(good);

        expect(PrefsFileGuard.repair(dir), PrefsFileState.restored);

        expect(file(PrefsFileGuard.fileName).readAsStringSync(), good);
        expect(jsonDecode(file(PrefsFileGuard.fileName).readAsStringSync()), isA<Map>());
      });
    }

    test('ملف تالف بلا مرآة: يُزاح جانباً ليبدأ التطبيق بدل أن يتعطل', () {
      file(PrefsFileGuard.fileName).writeAsStringSync('{"flutter.saved_ses');

      expect(PrefsFileGuard.repair(dir), PrefsFileState.reset);

      expect(file(PrefsFileGuard.fileName).existsSync(), isFalse);
      expect(file('shared_preferences.damaged.json').existsSync(), isTrue);
    });

    test('ملف محذوف والمرآة موجودة: يُستعاد', () {
      file(PrefsFileGuard.mirrorName).writeAsStringSync(good);
      expect(PrefsFileGuard.repair(dir), PrefsFileState.restored);
      expect(file(PrefsFileGuard.fileName).readAsStringSync(), good);
    });

    test('المرآة تتبع الملف، ولا تأخذ محتوى مبتوراً أبداً', () async {
      file(PrefsFileGuard.fileName).writeAsStringSync(good);
      expect(await PrefsFileGuard.init(directory: dir, mirrorEvery: const Duration(hours: 1)),
          PrefsFileState.healthy);

      await PrefsFileGuard.mirrorNow();
      expect(file(PrefsFileGuard.mirrorName).readAsStringSync(), good);
      expect(file('${PrefsFileGuard.mirrorName}.tmp').existsSync(), isFalse);

      // كتابة مبتورة (كأن الكهرباء انقطعت في منتصفها): المرآة تبقى على آخر نسخة سليمة
      file(PrefsFileGuard.fileName).writeAsStringSync('{"flutter.saved_sessions":"[{\\"role');
      await PrefsFileGuard.mirrorNow();
      expect(file(PrefsFileGuard.mirrorName).readAsStringSync(), good);

      // ثم عند الفتح التالي يُستعاد الملف منها
      PrefsFileGuard.dispose();
      expect(PrefsFileGuard.repair(dir), PrefsFileState.restored);
      expect(file(PrefsFileGuard.fileName).readAsStringSync(), good);

      // وتعديل سليم لاحق يصل إلى المرآة
      const newer = '{"flutter.saved_sessions":"[]","flutter.palette_id":"ruby"}';
      await PrefsFileGuard.init(directory: dir, mirrorEvery: const Duration(hours: 1));
      file(PrefsFileGuard.fileName).writeAsStringSync(newer);
      await PrefsFileGuard.mirrorNow();
      expect(file(PrefsFileGuard.mirrorName).readAsStringSync(), newer);
    });
  });
}

class _OneRowBrokenRemote extends ScriptedRemote {
  final String rowId;
  bool broken = true;

  _OneRowBrokenRemote(this.rowId);

  @override
  Future<void> upsert(String table, Map<String, dynamic> data) {
    if (broken && data['id'] == rowId) {
      throw const PostgrestException(message: 'Internal Server Error', code: '500');
    }
    return super.upsert(table, data);
  }
}

/// خادم يردّ بخطأ داخلي على سجل الطالب، ويرفض حركات النقاط ما دام الطالب غير موجود.
class _ParentStuckRemote extends ScriptedRemote {
  bool parentStuck = true;
  bool parentExists = true;

  @override
  Future<void> upsert(String table, Map<String, dynamic> data) {
    if (table == 'students' && parentStuck) {
      throw const PostgrestException(message: 'Internal Server Error', code: '500');
    }
    final parentUploaded = uploaded.any((u) => u.startsWith('upsert:students:'));
    if (table == 'points_logs' && (!parentExists || !parentUploaded)) {
      throw const PostgrestException(message: 'violates foreign key constraint', code: '23503');
    }
    return super.upsert(table, data);
  }
}

class _HangingRemote extends SupabaseRemoteDataSource {
  @override
  SupabaseClient? get client => Supabase.instance.client;

  @override
  Future<void> upsert(String table, Map<String, dynamic> data) =>
      Future<void>.delayed(const Duration(seconds: 30));
}
