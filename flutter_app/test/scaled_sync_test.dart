import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_app/data/datasources/datasources.dart';
import 'package:flutter_app/models/models.dart';
import 'package:flutter_app/services/sync/scaled_sync_engine.dart';
import 'package:flutter_app/services/sync/scope_reconciler.dart';
import 'package:flutter_app/services/sync/sync_scope.dart';

/// المزامنة بالنطاق: ما يحمله الجهاز، ما يطلبه من الخادم، وأهم من ذلك ما **لا** يحذفه.
/// الخطأ في هذه الطبقة يعني اختفاء بيانات مستخدم من جهازه، فأغلب الحالات هنا عن الحذف.

class _FakeRemote implements ScaledSyncRemote {
  ProbeResult probeResult;
  final Map<String, List<Map<String, dynamic>>?> tableRows = {};
  final Set<String> failingTables = {};
  List<Map<String, dynamic>>? mosqueRows = [];

  final List<(List<String>, String?)> probeCalls = [];
  final List<(String, List<String>, String?)> fetchCalls = [];
  final List<(List<String>, String?)> mosqueCalls = [];

  _FakeRemote(this.probeResult);

  @override
  Future<ProbeResult> probe(List<String> mosqueIds, String? since) async {
    probeCalls.add((mosqueIds, since));
    return probeResult;
  }

  @override
  Future<List<Map<String, dynamic>>?> fetchTable(String table, List<String> mosqueIds,
      {String? since}) async {
    fetchCalls.add((table, mosqueIds, since));
    if (failingTables.contains(table)) return null;
    return tableRows[table] ?? <Map<String, dynamic>>[];
  }

  @override
  Future<List<Map<String, dynamic>>?> fetchMosqueRows(Iterable<String> ids,
      {String? since}) async {
    mosqueCalls.add((ids.toList()..sort(), since));
    return mosqueRows;
  }

  final List<List<String>> cardCalls = [];

  @override
  Future<List<Map<String, dynamic>>?> fetchMosqueCardRows(Iterable<String> ids) async {
    cardCalls.add(ids.toList()..sort());
    return [
      for (final id in ids) {'id': id}
    ];
  }
}

SyncProbe _probe({
  String now = '2026-10-31T18:00:00+00:00',
  Set<String> changed = const {},
  List<SyncTombstone> tombs = const [],
  bool more = false,
}) =>
    SyncProbe(serverNow: now, changedTables: changed, tombstones: tombs, tombstonesMore: more);

ActiveSession _session(String role, {String? mosqueId, String? studentId, String code = 'C'}) =>
    ActiveSession(role: role, code: code, mosqueId: mosqueId, studentId: studentId);

Mosque _mosque(String id, {String? parent, String? womenBranch}) => Mosque(
      id: id,
      name: 'جامع $id',
      city: 'دمشق',
      gender: 'male',
      accessCode: 'MSQ-$id',
      parentMosqueId: parent,
      womenBranchId: womenBranch,
    );

Student _student(String id, String mosqueId) => Student(
      id: id,
      mosqueId: mosqueId,
      halaqaId: 'h-$mosqueId',
      fullName: 'طالب $id',
      gender: 'male',
      phone: '0',
      code: 'STU-$id',
    );

AttendanceRecord _att(String id, String studentId) => AttendanceRecord(
      id: id,
      studentId: studentId,
      halaqaId: 'h',
      sessionDate: '2026-10-31',
      status: 'present',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SyncScope', () {
    test('جلسة طالب وإدارة: مسجداهما فقط، وجلسة المشرف العام والزائر لا تضيف شيئاً', () {
      final scope = SyncScope.fromSessions(
        sessions: [
          _session('student', mosqueId: 'm1', studentId: 's1'),
          _session('mosque_admin', mosqueId: 'm2'),
          _session('super_admin'),
          _session('visitor'),
        ],
        students: const [],
        sheikhs: const [],
        mosques: const [],
      )!;
      expect(scope.dataMosqueIds, {'m1', 'm2'});
      expect(scope.isEmpty, isFalse);
      expect(scope.key, 'm1,m2');
    });

    test('المفتاح لا يتأثر بترتيب الجلسات', () {
      SyncScope scopeOf(List<String> ids) => SyncScope.fromSessions(
            sessions: [for (final i in ids) _session('mosque_admin', mosqueId: i)],
            students: const [],
            sheikhs: const [],
            mosques: const [],
          )!;
      expect(scopeOf(['b', 'a', 'c']).key, scopeOf(['c', 'a', 'b']).key);
    });

    test('زائر ومشرف عام فقط: نطاق فارغ (لا بيانات مسجد)', () {
      final scope = SyncScope.fromSessions(
        sessions: [_session('visitor'), _session('super_admin')],
        students: const [],
        sheikhs: const [],
        mosques: const [],
      )!;
      expect(scope.isEmpty, isTrue);
    });

    test('جلسة قديمة بلا مسجد تُحلّ من سجل الطالب المحلي', () {
      final scope = SyncScope.fromSessions(
        sessions: [_session('student', studentId: 's7')],
        students: [_student('s7', 'm9')],
        sheikhs: const [],
        mosques: const [],
      )!;
      expect(scope.dataMosqueIds, {'m9'});
    });

    test('جلسة لا نعرف مسجدها: null (يعني الجلب الكامل، لا تخميناً يحذف بيانات)', () {
      final scope = SyncScope.fromSessions(
        sessions: [_session('student', studentId: 'ghost', code: 'NOPE')],
        students: [_student('s1', 'm1')],
        sheikhs: const [],
        mosques: const [],
      );
      expect(scope, isNull);
    });

    test('أكثر من الحد: null', () {
      final scope = SyncScope.fromSessions(
        sessions: [
          for (var i = 0; i <= SyncScope.maxDataMosques; i++)
            _session('cashier', mosqueId: 'm$i'),
        ],
        students: const [],
        sheikhs: const [],
        mosques: const [],
      );
      expect(scope, isNull);
    });

    test('الفرع النسائي والأب: صفّ المسجد فقط بلا بياناته', () {
      final scope = SyncScope.fromSessions(
        sessions: [_session('mosque_admin', mosqueId: 'men')],
        students: const [],
        sheikhs: const [],
        mosques: [_mosque('men', womenBranch: 'women')],
      )!;
      expect(scope.dataMosqueIds, {'men'});
      expect(scope.rowOnlyMosqueIds, {'women'});
      expect(scope.allMosqueRowIds, {'men', 'women'});
      expect(scope.contains('women'), isFalse);
    });
  });

  group('SupabaseScaledSyncRemote.parseProbe', () {
    test('يفك الرد الصحيح', () {
      final p = SupabaseScaledSyncRemote.parseProbe({
        'server_now': '2026-10-31T18:21:06.862693+00:00',
        'changed': {'students': true, 'attendance': false, 'mosques': true},
        'tombstones': [
          {'t': 'students', 'id': 's1'},
          {'t': 'attendance', 'id': 'a1'},
        ],
        'tombstones_more': false,
      });
      expect(p.serverNow, '2026-10-31T18:21:06.862693+00:00');
      expect(p.changedTables, {'students', 'mosques'});
      expect(p.tombstones.map((t) => '${t.table}/${t.id}'), ['students/s1', 'attendance/a1']);
      expect(p.tombstonesMore, isFalse);
    });

    test('رد مشوّه يرمي بدل أن يُفسَّر تغييراً', () {
      expect(() => SupabaseScaledSyncRemote.parseProbe(null), throwsFormatException);
      expect(() => SupabaseScaledSyncRemote.parseProbe({'changed': {}}), throwsFormatException);
    });

    test('دالة غير موجودة تُعرف من الرمز لا من نص الرسالة وحده', () {
      expect(
        SupabaseScaledSyncRemote.isMissingFunction(
          const PostgrestException(message: 'x', code: 'PGRST202'),
        ),
        isTrue,
      );
      expect(
        SupabaseScaledSyncRemote.isMissingFunction(
          const PostgrestException(message: 'timeout', code: '57014'),
        ),
        isFalse,
      );
      expect(SupabaseScaledSyncRemote.isMissingFunction(Exception('boom')), isFalse);
    });
  });

  group('ScaledSyncEngine', () {
    late MemorySyncCursorStore store;
    late DateTime now;
    const scope = SyncScope(dataMosqueIds: {'m1'});

    ScaledSyncEngine engineWith(_FakeRemote r) =>
        ScaledSyncEngine(r, store, now: () => now);

    setUp(() {
      store = MemorySyncCursorStore();
      now = DateTime.utc(2026, 10, 31, 18);
    });

    test('أول مرة: جلب أساسي لكل الجداول لكل مسجد، والمؤشر هو ساعة الخادم', () async {
      final remote = _FakeRemote(ProbeResult(ProbeStatus.ok, _probe()));
      remote.tableRows['students'] = [
        {'id': 's1', 'mosque_id': 'm1'}
      ];
      final outcome = await engineWith(remote).pull(scope);

      expect(outcome.status, ScaledSyncStatus.ok);
      final r = outcome.result!;
      expect(r.baseline, isTrue);
      expect(r.complete, isTrue);
      expect(remote.probeCalls.single.$2, isNull, reason: 'الفحص الأول بلا مؤشر');
      expect(remote.fetchCalls.map((c) => c.$1).toSet(), kScopedSyncTables.toSet());
      expect(remote.fetchCalls.every((c) => c.$3 == null), isTrue);
      // كل جدول حاضر في الخريطة ولو فارغاً: الغياب هنا يعني «لا شيء في السحابة»
      expect(r.rows.keys.toSet(), {...kScopedSyncTables, 'mosques'});
      expect(r.rows['students']!.single['id'], 's1');
      expect(r.nextCursor.serverNow, '2026-10-31T18:00:00+00:00');
      expect(r.nextCursor.scopeKey, 'm1');
      expect(await store.load(), isNull, reason: 'لا يُحفظ قبل commit');
    });

    test('commit يحفظ المؤشر، والدورة التالية تزايدية: الجداول المتغيرة وحدها', () async {
      final first = _FakeRemote(ProbeResult(ProbeStatus.ok, _probe()));
      final res1 = (await engineWith(first).pull(scope)).result!;
      await engineWith(first).commit(res1);
      expect((await store.load())!.serverNow, '2026-10-31T18:00:00+00:00');

      now = now.add(const Duration(minutes: 1));
      final second = _FakeRemote(ProbeResult(
        ProbeStatus.ok,
        _probe(
          now: '2026-10-31T18:01:00+00:00',
          changed: {'attendance'},
          tombs: [const SyncTombstone('students', 's9')],
        ),
      ));
      second.tableRows['attendance'] = [
        {'id': 'a1', 'mosque_id': 'm1'}
      ];
      final out = await engineWith(second).pull(scope);
      final r = out.result!;

      expect(r.baseline, isFalse);
      expect(second.probeCalls.single.$2, '2026-10-31T18:00:00+00:00');
      expect(second.fetchCalls.map((c) => c.$1).toList(), ['attendance']);
      // ناقص نافذة التداخل (دقيقتان) وبصيغة UTC
      expect(second.fetchCalls.single.$3, '2026-10-31T17:58:00.000Z');
      expect(second.mosqueCalls, isEmpty, reason: 'صف المسجد لم يتغير');
      expect(r.rows.keys.toSet(), {'attendance'});
      expect(r.tombstones.single.id, 's9');
    });

    test('لا تغيير: طلب الفحص وحده ولا جلب', () async {
      await store.save(SyncCursor(
        scopeKey: 'm1',
        serverNow: '2026-10-31T17:59:00+00:00',
        baselineAt: now,
        savedAt: now,
      ));
      final remote = _FakeRemote(ProbeResult(ProbeStatus.ok, _probe()));
      final r = (await engineWith(remote).pull(scope)).result!;
      expect(remote.probeCalls, hasLength(1));
      expect(remote.fetchCalls, isEmpty);
      expect(r.rows, isEmpty);
      expect(r.complete, isTrue);
    });

    test('تغيّر النطاق أو تقادم الجلب الأساسي أو المؤشر أو فيض الشواهد: جلب أساسي', () async {
      Future<bool> baselineWith(SyncCursor c, {bool more = false, SyncScope s = scope}) async {
        await store.save(c);
        final remote = _FakeRemote(ProbeResult(ProbeStatus.ok, _probe(more: more)));
        return (await engineWith(remote).pull(s)).result!.baseline;
      }

      SyncCursor cursor({String key = 'm1', Duration baselineAge = Duration.zero, Duration age = Duration.zero}) =>
          SyncCursor(
            scopeKey: key,
            serverNow: '2026-10-31T17:59:00+00:00',
            baselineAt: now.subtract(baselineAge),
            savedAt: now.subtract(age),
          );

      expect(await baselineWith(cursor()), isFalse);
      expect(await baselineWith(cursor(key: 'm1,m2')), isTrue, reason: 'نطاق آخر');
      expect(await baselineWith(cursor(baselineAge: const Duration(days: 8))), isTrue);
      expect(await baselineWith(cursor(age: const Duration(days: 15))), isTrue);
      expect(await baselineWith(cursor(), more: true), isTrue, reason: 'شواهد ناقصة');
    });

    test('عدة مساجد: دفعات من 10 مساجد لكل طلب وجدول (لا طلب لكل مسجد)', () async {
      final remote = _FakeRemote(ProbeResult(ProbeStatus.ok, _probe()));
      await engineWith(remote).pull(const SyncScope(dataMosqueIds: {'m2', 'm1'}));
      expect(remote.fetchCalls.where((c) => c.$1 == 'students').map((c) => c.$2).toList(), [
        ['m1', 'm2']
      ]);
      expect(remote.probeCalls.single.$1, ['m1', 'm2']);

      // 25 مسجداً: ثلاث دفعات لكل جدول (10 و10 و5)
      final many = _FakeRemote(ProbeResult(ProbeStatus.ok, _probe()));
      await engineWith(many).pull(SyncScope(dataMosqueIds: {for (var i = 0; i < 25; i++) 'x${i.toString().padLeft(2, '0')}'}));
      final students = many.fetchCalls.where((c) => c.$1 == 'students').map((c) => c.$2.length).toList();
      expect(students, [10, 10, 5]);
      expect(many.fetchCalls.length, kScopedSyncTables.length * 3);
    });

    test('المساجد المرتبطة (الفرع النسائي) بأعمدة البطاقة العامة لا الصف الكامل بأكواده', () async {
      final remote = _FakeRemote(ProbeResult(ProbeStatus.ok, _probe()));
      remote.mosqueRows = [
        {'id': 'm1', 'access_code': 'MSQ-OWN'}
      ];
      final out = await engineWith(remote).pull(
        const SyncScope(dataMosqueIds: {'m1'}, rowOnlyMosqueIds: {'women'}),
      );
      final r = out.result!;
      expect(remote.mosqueCalls.single.$1, ['m1'], reason: 'الصف الكامل لمسجد الجهاز وحده');
      expect(remote.cardCalls, [
        ['women']
      ], reason: 'الفرع المرتبط بأعمدة البطاقة');
      expect(r.rows['mosques']!.map((m) => m['id']).toSet(), {'m1', 'women'});
      expect(r.complete, isTrue);
    });

    test('بلا مساجد مرتبطة: لا طلب بطاقات', () async {
      final remote = _FakeRemote(ProbeResult(ProbeStatus.ok, _probe()));
      await engineWith(remote).pull(scope);
      expect(remote.cardCalls, isEmpty);
    });

    test('دالة الخادم غير موجودة: unsupported ولا جلب', () async {
      final remote = _FakeRemote(const ProbeResult(ProbeStatus.unsupported));
      final out = await engineWith(remote).pull(scope);
      expect(out.status, ScaledSyncStatus.unsupported);
      expect(remote.fetchCalls, isEmpty);
    });

    test('خطأ عابر في الفحص: failed ولا جلب', () async {
      final remote = _FakeRemote(const ProbeResult(ProbeStatus.failed));
      final out = await engineWith(remote).pull(scope);
      expect(out.status, ScaledSyncStatus.failed);
      expect(remote.fetchCalls, isEmpty);
    });

    test('جدول فشل جلبه: النتيجة غير مكتملة ولا يتقدّم المؤشر', () async {
      final remote = _FakeRemote(ProbeResult(ProbeStatus.ok, _probe()))
        ..failingTables.add('attendance');
      final engine = engineWith(remote);
      final r = (await engine.pull(scope)).result!;
      expect(r.complete, isFalse);
      await engine.commit(r);
      expect(await store.load(), isNull);
    });

    test('مؤشر تالف على القرص يُعامل كأنه غير موجود', () async {
      SharedPreferences.setMockInitialValues({'scaled_sync_cursor_v1': '{not json'});
      expect(await PrefsSyncCursorStore().load(), isNull);
      SharedPreferences.setMockInitialValues({});
      final prefsStore = PrefsSyncCursorStore();
      final c = SyncCursor(
        scopeKey: 'm1',
        serverNow: 'x',
        baselineAt: DateTime.utc(2026),
        savedAt: DateTime.utc(2026),
      );
      await prefsStore.save(c);
      expect((await prefsStore.load())!.scopeKey, 'm1');
    });
  });

  group('ScopeReconciler', () {
    late LocalStorageDataSource ds;
    final pending = <String>{};
    bool isPending(String table, String id) => pending.contains('$table/$id');

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      ds = LocalStorageDataSource();
      pending.clear();
    });

    test('شاهد الحذف يزيل الصف، ولا يزيل ما ينتظر الرفع', () {
      ds.students.addAll([_student('s1', 'm1'), _student('s2', 'm1')]);
      ds.attendanceRecords.add(_att('a1', 's1'));
      pending.add('students/s2');

      final n = ScopeReconciler.applyTombstones(
        ds,
        const [
          SyncTombstone('students', 's1'),
          SyncTombstone('students', 's2'),
          SyncTombstone('attendance', 'a1'),
          SyncTombstone('students', 'لا-وجود-له'),
          SyncTombstone('جدول_غريب', 'x'),
        ],
        isPendingUpsert: isPending,
      );
      expect(n, 2);
      expect(ds.students.map((s) => s.id), ['s2']);
      expect(ds.attendanceRecords, isEmpty);
    });

    test('الجلب الأساسي: يمسح ما خرج من النطاق، ويُبقي ما في النطاق وما في السحابة', () {
      // جهاز بنسخة قديمة كانت تحمل كل المساجد
      ds.mosques.addAll([_mosque('m1'), _mosque('other')]);
      ds.students.addAll([_student('mine', 'm1'), _student('theirs', 'other')]);
      ds.attendanceRecords.addAll([_att('a-mine', 'mine'), _att('a-theirs', 'theirs')]);

      final removed = ScopeReconciler.reconcileBaseline(
        ds,
        const SyncScope(dataMosqueIds: {'m1'}),
        {
          'mosques': [
            {'id': 'm1'}
          ],
          'students': [
            {'id': 'mine'}
          ],
          'attendance': [
            {'id': 'a-mine'}
          ],
        },
        isPendingUpsert: isPending,
      );

      expect(ds.mosques.map((m) => m.id), ['m1']);
      expect(ds.students.map((s) => s.id), ['mine']);
      expect(ds.attendanceRecords.map((a) => a.id), ['a-mine']);
      expect(removed, 3, reason: 'مسجد وطالب وسجل حضور من خارج النطاق');
    });

    test('ما حُذف في السحابة ضمن نطاقي يُحذف محلياً بالجلب الأساسي', () {
      ds.mosques.add(_mosque('m1'));
      ds.students.addAll([_student('alive', 'm1'), _student('gone', 'm1')]);
      ds.attendanceRecords.addAll([_att('a1', 'alive'), _att('a2', 'gone')]);

      ScopeReconciler.reconcileBaseline(
        ds,
        const SyncScope(dataMosqueIds: {'m1'}),
        {
          'mosques': [
            {'id': 'm1'}
          ],
          'students': [
            {'id': 'alive'}
          ],
          'attendance': [
            {'id': 'a1'}
          ],
        },
        isPendingUpsert: isPending,
      );
      expect(ds.students.map((s) => s.id), ['alive']);
      expect(ds.attendanceRecords.map((a) => a.id), ['a1']);
    });

    test('تعديل أُجري بلا إنترنت (في طابور الرفع) لا يُمسّ أبداً، داخل النطاق أو خارجه', () {
      ds.mosques.add(_mosque('m1'));
      ds.students.addAll([_student('offline-new', 'm1'), _student('offline-elsewhere', 'other')]);
      ds.attendanceRecords.add(_att('offline-att', 'offline-new'));
      pending.addAll(['students/offline-new', 'students/offline-elsewhere', 'attendance/offline-att']);

      ScopeReconciler.reconcileBaseline(
        ds,
        const SyncScope(dataMosqueIds: {'m1'}),
        {
          'mosques': [
            {'id': 'm1'}
          ],
        },
        isPendingUpsert: isPending,
      );
      expect(ds.students.map((s) => s.id).toSet(), {'offline-new', 'offline-elsewhere'});
      expect(ds.attendanceRecords.map((a) => a.id), ['offline-att']);
    });

    test('نطاق فارغ: لا يُمسح شيء إطلاقاً', () {
      ds.mosques.add(_mosque('m1'));
      ds.students.add(_student('s1', 'm1'));
      final removed = ScopeReconciler.reconcileBaseline(
        ds,
        const SyncScope(),
        const {},
        isPendingUpsert: isPending,
      );
      expect(removed, 0);
      expect(ds.students, hasLength(1));
      expect(ds.mosques, hasLength(1));
    });

    test('صف المسجد المرتبط (الفرع النسائي) يبقى وبياناته لا تصل', () {
      ds.mosques.addAll([_mosque('men', womenBranch: 'women'), _mosque('women', parent: 'men')]);
      ds.students.addAll([_student('m-stu', 'men'), _student('w-stu', 'women')]);

      ScopeReconciler.reconcileBaseline(
        ds,
        const SyncScope(dataMosqueIds: {'men'}, rowOnlyMosqueIds: {'women'}),
        {
          'mosques': [
            {'id': 'men'},
            {'id': 'women'}
          ],
          'students': [
            {'id': 'm-stu'}
          ],
        },
        isPendingUpsert: isPending,
      );
      expect(ds.mosques.map((m) => m.id).toSet(), {'men', 'women'});
      expect(ds.students.map((s) => s.id), ['m-stu']);
    });

    test('دروس اكتشف من مساجد أخرى ومساجدها تبقى رغم خروجها من النطاق', () {
      ds.mosques.addAll([_mosque('m1'), _mosque('far')]);
      ds.communityEvents.add(CommunityEvent.fromJson({'id': 'ev-far', 'mosque_id': 'far'}));
      ds.communityEvents.add(CommunityEvent.fromJson({'id': 'ev-stale', 'mosque_id': 'far'}));

      ScopeReconciler.reconcileBaseline(
        ds,
        const SyncScope(dataMosqueIds: {'m1'}),
        {
          'mosques': [
            {'id': 'm1'}
          ],
        },
        isPendingUpsert: isPending,
        keepEventIds: {'ev-far'},
        keepMosqueIds: {'far'},
      );
      expect(ds.communityEvents.map((e) => e.id), ['ev-far']);
      expect(ds.mosques.map((m) => m.id).toSet(), {'m1', 'far'});
    });
  });
}
