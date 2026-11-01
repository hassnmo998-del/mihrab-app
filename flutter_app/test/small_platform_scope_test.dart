import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/models/models.dart';
import 'package:flutter_app/services/sync/scaled_sync_engine.dart';
import 'package:flutter_app/services/sync/sync_scope.dart';

/// المنصة الصغيرة (حتى 40 مسجداً): الجهاز يحمّل كل المساجد كما قبل المزامنة بالنطاق، فتبقى
/// «المنافسة» و«التبرع» و«اكتشف» كاملة؛ لكن صف مسجد غير مسجده يصل بلا أكواد.
class _Remote implements ScaledSyncRemote {
  final List<List<String>> fullCalls = [];
  final List<List<String>> cardCalls = [];
  final List<(String, List<String>)> tableCalls = [];

  @override
  Future<ProbeResult> probe(List<String> mosqueIds, String? since) async => ProbeResult(
        ProbeStatus.ok,
        const SyncProbe(
          serverNow: '2026-11-01T10:00:00+00:00',
          changedTables: {},
          tombstones: [],
          tombstonesMore: false,
        ),
      );

  @override
  Future<List<Map<String, dynamic>>?> fetchTable(String table, List<String> mosqueIds,
      {String? since}) async {
    tableCalls.add((table, mosqueIds));
    return [];
  }

  @override
  Future<List<Map<String, dynamic>>?> fetchMosqueRows(Iterable<String> ids,
      {String? since}) async {
    fullCalls.add(ids.toList()..sort());
    return [for (final id in ids) {'id': id, 'access_code': 'MSQ-$id'}];
  }

  @override
  Future<List<Map<String, dynamic>>?> fetchMosqueCardRows(Iterable<String> ids) async {
    cardCalls.add(ids.toList()..sort());
    return [for (final id in ids) {'id': id}];
  }
}

ActiveSession _session(String mosqueId) =>
    ActiveSession(role: 'mosque_admin', code: 'C', mosqueId: mosqueId);

void main() {
  group('SyncScope على منصة صغيرة', () {
    const everyone = SyncScope(
      dataMosqueIds: {'a', 'b', 'c'},
      ownMosqueIds: {'a'},
      wholePlatform: true,
    );

    test('بيانات الكل، وصف مسجد الجهاز وحده كامل', () {
      expect(everyone.dataMosqueIds, {'a', 'b', 'c'});
      expect(everyone.ownMosqueIds, {'a'});
      expect(everyone.cardMosqueIds, {'b', 'c'});
      expect(everyone.contains('c'), isTrue, reason: 'بياناته تصل');
      expect(everyone.wholePlatform, isTrue);
    });

    test('النطاق العادي: مساجد الجهاز كلها كاملة ولا بطاقات', () {
      final s = SyncScope.fromSessions(
        sessions: [_session('a'), _session('b')],
        students: const [],
        sheikhs: const [],
        mosques: const [],
      )!;
      expect(s.ownMosqueIds, s.dataMosqueIds);
      expect(s.cardMosqueIds, isEmpty);
      expect(s.wholePlatform, isFalse);
    });

    test('المفتاح يتغير باتساع النطاق وبمن هو مسجد الجهاز (فيُجلب أساسياً من جديد)', () {
      const narrow = SyncScope(dataMosqueIds: {'a'});
      const wide = SyncScope(dataMosqueIds: {'a', 'b', 'c'}, ownMosqueIds: {'a'});
      const wideOtherOwn = SyncScope(dataMosqueIds: {'a', 'b', 'c'}, ownMosqueIds: {'b'});
      expect(narrow.key, isNot(wide.key));
      expect(wide.key, isNot(wideOtherOwn.key));
      // الترتيب لا يغيّر المفتاح
      expect(
        const SyncScope(dataMosqueIds: {'c', 'a', 'b'}, ownMosqueIds: {'a'}).key,
        wide.key,
      );
    });

    test('زائر بلا جلسات على منصة صغيرة: كل المساجد بلا مسجد خاص به', () {
      const visitor = SyncScope(dataMosqueIds: {'a', 'b'}, ownMosqueIds: {}, wholePlatform: true);
      expect(visitor.isEmpty, isFalse);
      expect(visitor.ownMosqueIds, isEmpty);
      expect(visitor.cardMosqueIds, {'a', 'b'});
    });

    List<String> mosques(int n) => [for (var i = 0; i < n; i++) 'm${i.toString().padLeft(3, '0')}'];
    const own = SyncScope(dataMosqueIds: {'m000'});

    test('منصة صغيرة (مسجدان): كل المساجد، ومسجد الجهاز هو الكامل', () {
      final s = SyncScope.forPlatform(own: own, platformIds: mosques(2), wasWholePlatform: false);
      expect(s.wholePlatform, isTrue);
      expect(s.dataMosqueIds, {'m000', 'm001'});
      expect(s.ownMosqueIds, {'m000'});
    });

    test('زائر بلا جلسات على منصة صغيرة: كل المساجد، وبلا مسجد خاص', () {
      final s = SyncScope.forPlatform(
          own: const SyncScope(), platformIds: mosques(3), wasWholePlatform: false);
      expect(s.wholePlatform, isTrue);
      expect(s.ownMosqueIds, isEmpty);
      expect(s.dataMosqueIds, hasLength(3));
    });

    test('الحدّ: 40 صغيرة، 41 كبيرة (والنطاق يبقى مسجد الجهاز كما هو)', () {
      expect(
        SyncScope.forPlatform(own: own, platformIds: mosques(40), wasWholePlatform: false).wholePlatform,
        isTrue,
      );
      final big = SyncScope.forPlatform(own: own, platformIds: mosques(41), wasWholePlatform: false);
      expect(big.wholePlatform, isFalse);
      expect(big.dataMosqueIds, {'m000'});
      expect(identical(big, own), isTrue);
    });

    test('لا تذبذب: من كان على كل المنصة يبقى حتى يتجاوز 50، ومن لم يكن لا يدخلها عند 45', () {
      expect(
        SyncScope.forPlatform(own: own, platformIds: mosques(45), wasWholePlatform: true).wholePlatform,
        isTrue,
      );
      expect(
        SyncScope.forPlatform(own: own, platformIds: mosques(50), wasWholePlatform: true).wholePlatform,
        isTrue,
      );
      expect(
        SyncScope.forPlatform(own: own, platformIds: mosques(51), wasWholePlatform: true).wholePlatform,
        isFalse,
      );
      expect(
        SyncScope.forPlatform(own: own, platformIds: mosques(45), wasWholePlatform: false).wholePlatform,
        isFalse,
      );
    });

    test('منصة ضخمة: القائمة المجلوبة مقطوعة عند 51 فتُقرأ كبيرة دائماً', () {
      // الخادم لا يعيد أكثر من الحدّ المطلوب؛ 51 معرّفاً يعني «أكثر من 50»
      expect(
        SyncScope.forPlatform(own: own, platformIds: mosques(51), wasWholePlatform: false).wholePlatform,
        isFalse,
      );
    });

    test('مسجد الجهاز الذي لم يُرفع بعد (غير موجود في القائمة) يُضمّ، ولا يُنسى', () {
      final s = SyncScope.forPlatform(
        own: const SyncScope(dataMosqueIds: {'offline-new'}),
        platformIds: mosques(3),
        wasWholePlatform: false,
      );
      expect(s.dataMosqueIds, contains('offline-new'));
      expect(s.ownMosqueIds, {'offline-new'});
    });

    test('سقف الخادم 100: جلسات كثيرة على منصة صغيرة تعود لمساجد الجهاز وحدها', () {
      final manyOwn = SyncScope(dataMosqueIds: {for (var i = 0; i < 70; i++) 'own$i'});
      final s = SyncScope.forPlatform(own: manyOwn, platformIds: mosques(40), wasWholePlatform: false);
      expect(s.wholePlatform, isFalse);
      expect(s.dataMosqueIds, hasLength(70));
    });

    test('حدود الانتقال: 40 دخولاً و50 خروجاً (لا تذبذب حول الحدّ)', () {
      expect(SyncScope.smallPlatformMosques, 40);
      expect(SyncScope.smallPlatformKeepMosques, greaterThan(SyncScope.smallPlatformMosques));
      expect(SyncScope.smallPlatformKeepMosques, lessThanOrEqualTo(SyncScope.maxDataMosques));
    });
  });

  group('المحرك على منصة صغيرة', () {
    test('بيانات كل المساجد، صف الجهاز كاملاً والبقية بالبطاقة بلا أكواد', () async {
      final remote = _Remote();
      final engine = ScaledSyncEngine(remote, MemorySyncCursorStore());
      const scope = SyncScope(
        dataMosqueIds: {'a', 'b', 'c'},
        ownMosqueIds: {'a'},
        wholePlatform: true,
      );

      final out = await engine.pull(scope);
      final r = out.result!;

      expect(r.complete, isTrue);
      expect(remote.fullCalls.single, ['a'], reason: 'الصف الكامل لمسجد الجهاز وحده');
      expect(remote.cardCalls.single, ['b', 'c']);
      // جداول المساجد الثلاثة كلها تُجلب
      expect({for (final c in remote.tableCalls) ...c.$2}, {'a', 'b', 'c'});
      final byId = {for (final m in r.rows['mosques']!) m['id']: m};
      expect(byId['a']!['access_code'], 'MSQ-a');
      expect(byId['b']!.containsKey('access_code'), isFalse);
      expect(byId['c']!.containsKey('access_code'), isFalse);
    });

    test('زائر (بلا مسجد خاص): لا صف كامل لأي مسجد، والكل بطاقات', () async {
      final remote = _Remote();
      final engine = ScaledSyncEngine(remote, MemorySyncCursorStore());
      const scope = SyncScope(dataMosqueIds: {'a', 'b'}, ownMosqueIds: {}, wholePlatform: true);

      final r = (await engine.pull(scope)).result!;
      expect(remote.fullCalls.single, isEmpty);
      expect(remote.cardCalls.single, ['a', 'b']);
      expect(r.rows['mosques']!.every((m) => !m.containsKey('access_code')), isTrue);
    });
  });
}
