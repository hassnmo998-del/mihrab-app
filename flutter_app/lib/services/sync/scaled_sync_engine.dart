import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'sync_scope.dart';

/// جداول المسجد التي تُزامَن بالنطاق (كلها فيها `mosque_id` و`updated_at` في الخادم
/// بعد `scale_sync.sql`). جدول `mosques` يُعامَل منفصلاً: مفتاحه `id` لا `mosque_id`.
const List<String> kScopedSyncTables = [
  'sheikhs',
  'halaqat',
  'students',
  'community_events',
  'memorization_records',
  'attendance',
  'messages',
  'competitions',
  'intensive_courses',
  'trips',
  'rewards',
  'reward_redemptions',
  'recitation_tracks',
  'subject_recitation_records',
  'points_logs',
  'event_questions',
];

/// صف محذوف في السحابة (شاهد حذف).
class SyncTombstone {
  final String table;
  final String id;
  const SyncTombstone(this.table, this.id);
}

/// جواب دالة `sync_changes`: أي الجداول فيها جديد منذ المؤشر، وما حُذف.
class SyncProbe {
  /// ساعة الخادم لحظة الفحص: هي المؤشر التالي (لا ساعة الجهاز، فقد تكون خاطئة).
  final String serverNow;
  final Set<String> changedTables;
  final List<SyncTombstone> tombstones;

  /// الشواهد أكثر مما يتّسع له الرد: يلزم جلب أساسي كامل بدل الاعتماد عليها.
  final bool tombstonesMore;

  const SyncProbe({
    required this.serverNow,
    required this.changedTables,
    required this.tombstones,
    required this.tombstonesMore,
  });
}

enum ProbeStatus {
  ok,

  /// دالة `sync_changes` غير موجودة: ترقية القاعدة لم تُطبَّق بعد (أو أُزيلت).
  unsupported,

  /// خطأ عابر (لا شبكة، مهلة): نعيد المحاولة في الدورة التالية دون تغيير الأسلوب.
  failed,
}

class ProbeResult {
  final ProbeStatus status;
  final SyncProbe? probe;
  const ProbeResult(this.status, [this.probe]);
}

/// ما يحتاجه المحرك من الخادم؛ الاختبارات تستبدله بنسخة وهمية.
abstract class ScaledSyncRemote {
  Future<ProbeResult> probe(List<String> mosqueIds, String? since);

  /// كل صفوف [table] لمسجد واحد (التي تغيّرت منذ [since] إن وُجد)، بكل الصفحات.
  /// `null` عند أي فشل: نصف جدول لا يُقبل.
  Future<List<Map<String, dynamic>>?> fetchTable(
    String table,
    String mosqueId, {
    String? since,
  });

  /// صفوف المساجد بمعرّفاتها.
  Future<List<Map<String, dynamic>>?> fetchMosqueRows(
    Iterable<String> ids, {
    String? since,
  });
}

/// مؤشر المزامنة المحفوظ على الجهاز.
class SyncCursor {
  /// النطاق الذي أُخذ فيه المؤشر؛ تغيّر النطاق يفرض جلباً أساسياً.
  final String scopeKey;

  /// آخر `server_now` طُبّقت تغييراته كاملة.
  final String serverNow;

  /// متى جرى آخر جلب أساسي كامل (ساعة الجهاز، تقريبية تكفي لجدولة التجديد).
  final DateTime baselineAt;

  /// متى حُفظ المؤشر.
  final DateTime savedAt;

  const SyncCursor({
    required this.scopeKey,
    required this.serverNow,
    required this.baselineAt,
    required this.savedAt,
  });

  Map<String, dynamic> toJson() => {
        'scope': scopeKey,
        'server_now': serverNow,
        'baseline_at': baselineAt.toIso8601String(),
        'saved_at': savedAt.toIso8601String(),
      };

  static SyncCursor? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final scope = raw['scope'];
    final serverNow = raw['server_now'];
    final baseline = DateTime.tryParse('${raw['baseline_at']}');
    final saved = DateTime.tryParse('${raw['saved_at']}');
    if (scope is! String || serverNow is! String || baseline == null || saved == null) {
      return null;
    }
    return SyncCursor(
      scopeKey: scope,
      serverNow: serverNow,
      baselineAt: baseline,
      savedAt: saved,
    );
  }
}

abstract class SyncCursorStore {
  Future<SyncCursor?> load();
  Future<void> save(SyncCursor cursor);
  Future<void> clear();
}

class MemorySyncCursorStore implements SyncCursorStore {
  SyncCursor? _cursor;
  @override
  Future<SyncCursor?> load() async => _cursor;
  @override
  Future<void> save(SyncCursor cursor) async => _cursor = cursor;
  @override
  Future<void> clear() async => _cursor = null;
}

class PrefsSyncCursorStore implements SyncCursorStore {
  static const String _key = 'scaled_sync_cursor_v1';

  @override
  Future<SyncCursor?> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return null;
      return SyncCursor.fromJson(jsonDecode(raw));
    } catch (_) {
      return null; // مؤشر تالف = جلب أساسي جديد، لا خطأ
    }
  }

  @override
  Future<void> save(SyncCursor cursor) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(cursor.toJson()));
    } catch (_) {}
  }

  @override
  Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (_) {}
  }
}

enum ScaledSyncStatus { ok, unsupported, failed }

class ScaledSyncResult {
  /// جلب أساسي كامل للنطاق: يصحّ معه حذف ما غاب من السحابة ومسح ما خرج من النطاق.
  final bool baseline;

  /// كل الجلبات المطلوبة نجحت. غير ذلك: تُدمج الصفوف الواصلة لكن لا يتقدّم المؤشر
  /// ولا يُحذف شيء بالغياب.
  final bool complete;

  /// جدول ← صفوفه التي جُلبت (الجداول التي لم يتغير فيها شيء غائبة عن الخريطة).
  /// يشمل `mosques`.
  final Map<String, List<Map<String, dynamic>>> rows;
  final List<SyncTombstone> tombstones;

  /// المؤشر الذي يُحفظ بعد نجاح الدمج والحفظ المحلي.
  final SyncCursor nextCursor;

  const ScaledSyncResult({
    required this.baseline,
    required this.complete,
    required this.rows,
    required this.tombstones,
    required this.nextCursor,
  });
}

class ScaledSyncOutcome {
  final ScaledSyncStatus status;
  final ScaledSyncResult? result;
  const ScaledSyncOutcome(this.status, [this.result]);
}

/// مزامنة بالنطاق وبالتزايد.
///
/// ما يفعله كل دورة: طلب واحد صغير (`sync_changes`) يقول أي الجداول تغيّرت في مساجد
/// هذا الجهاز منذ آخر مرة وما الذي حُذف، ثم جلب الجداول المتغيّرة وحدها. لا يلمس
/// التخزين المحلي ولا الواجهة؛ يعيد [ScaledSyncResult] ليطبّقه [DataService] ثم يؤكّد
/// المؤشر بـ[commit] بعد أن يُحفظ الدمج على القرص (انقطاع بينهما = إعادة جلب آمنة).
class ScaledSyncEngine {
  /// نجدّد الجلب الأساسي أسبوعياً: يلتقط ما فات الشواهد، ويعيد ضبط أي انحراف.
  static const Duration baselineEvery = Duration(days: 7);

  /// مؤشر أقدم من هذا لا يُوثَق به (الخادم ينظّف الشواهد بعد 45 يوماً).
  static const Duration maxCursorAge = Duration(days: 14);

  /// نافذة التداخل مع المؤشر: معاملات تُثبَّت متأخرة لا تضيع (تطابق الخادم).
  static const Duration overlap = Duration(minutes: 2);

  /// أقصى جلبات متوازية (بعدد الجداول: كالجلب القديم الذي كان يرسل 17 معاً). كانت 6
  /// فأخذ أول جلب على شبكة بطيئة نحو ثلاثة أضعاف الوقت.
  static const int _parallel = 16;

  final ScaledSyncRemote remote;
  final SyncCursorStore cursorStore;
  final DateTime Function() _now;

  ScaledSyncEngine(
    this.remote,
    this.cursorStore, {
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  /// يحدد هل الدورة جلب أساسي أم تزايدي (مكشوف للاختبار).
  bool needsBaseline(SyncCursor? cursor, SyncScope scope, {bool force = false}) {
    if (force || cursor == null) return true;
    if (cursor.scopeKey != scope.key) return true;
    final now = _now();
    if (now.difference(cursor.baselineAt) > baselineEvery) return true;
    if (now.difference(cursor.savedAt) > maxCursorAge) return true;
    return false;
  }

  Future<ScaledSyncOutcome> pull(SyncScope scope, {bool forceBaseline = false}) async {
    final cursor = await cursorStore.load();
    var baseline = needsBaseline(cursor, scope, force: forceBaseline);

    final ids = scope.dataMosqueIds.toList()..sort();
    final probeRes = await remote.probe(ids, baseline ? null : cursor!.serverNow);
    if (probeRes.status == ProbeStatus.unsupported) {
      return const ScaledSyncOutcome(ScaledSyncStatus.unsupported);
    }
    final probe = probeRes.probe;
    if (probeRes.status != ProbeStatus.ok || probe == null) {
      return const ScaledSyncOutcome(ScaledSyncStatus.failed);
    }

    // شواهد أكثر من حدّ الرد: لا نثق بقائمة ناقصة، نجلب كل شيء ونُسقط الغائب.
    if (!baseline && probe.tombstonesMore) baseline = true;

    final sinceForRows = baseline ? null : _withOverlap(cursor!.serverNow);

    final tables = baseline
        ? kScopedSyncTables
        : kScopedSyncTables.where(probe.changedTables.contains).toList();

    final fetchMosques = baseline ||
        probe.changedTables.contains('mosques') ||
        scope.rowOnlyMosqueIds.isNotEmpty && _rowOnlyDue();

    var complete = true;
    final rows = <String, List<Map<String, dynamic>>>{};

    // المهام: (جدول، مسجد). كل مسجد باستعلام مستقل = ترتيب الفهرس مباشرة بلا فرز.
    final jobs = <(String, String)>[
      for (final t in tables)
        for (final m in ids) (t, m),
    ];

    for (var i = 0; i < jobs.length; i += _parallel) {
      final batch = jobs.skip(i).take(_parallel).toList();
      final results = await Future.wait(
        batch.map((j) => remote.fetchTable(j.$1, j.$2, since: sinceForRows)),
      );
      for (var k = 0; k < batch.length; k++) {
        final r = results[k];
        if (r == null) {
          complete = false;
        } else {
          rows.putIfAbsent(batch[k].$1, () => []).addAll(r);
        }
      }
    }

    if (fetchMosques) {
      final r = await remote.fetchMosqueRows(scope.allMosqueRowIds, since: sinceForRows);
      if (r == null) {
        complete = false;
      } else {
        rows['mosques'] = r;
        _lastRowOnlyRefresh = _now();
      }
    }

    // جلب أساسي: كل جدول مطلوب يجب أن يظهر في الخريطة ولو فارغاً، فالغياب هنا يعني
    // «لا شيء في السحابة» ويُحذف به ما بقي محلياً.
    if (baseline && complete) {
      for (final t in kScopedSyncTables) {
        rows.putIfAbsent(t, () => []);
      }
    }

    final now = _now();
    return ScaledSyncOutcome(
      ScaledSyncStatus.ok,
      ScaledSyncResult(
        baseline: baseline,
        complete: complete,
        rows: rows,
        tombstones: baseline ? const [] : probe.tombstones,
        nextCursor: SyncCursor(
          scopeKey: scope.key,
          serverNow: probe.serverNow,
          baselineAt: baseline ? now : cursor!.baselineAt,
          savedAt: now,
        ),
      ),
    );
  }

  /// يثبّت المؤشر بعد أن طُبّق الدمج وحُفظ محلياً.
  Future<void> commit(ScaledSyncResult result) async {
    if (!result.complete) return;
    await cursorStore.save(result.nextCursor);
  }

  Future<void> resetCursor() => cursorStore.clear();

  DateTime? _lastRowOnlyRefresh;
  static const Duration _rowOnlyEvery = Duration(hours: 6);
  bool _rowOnlyDue() =>
      _lastRowOnlyRefresh == null ||
      _now().difference(_lastRowOnlyRefresh!) > _rowOnlyEvery;

  /// المؤشر ناقص نافذة التداخل، بصيغة UTC بلا `+` (تسلم من ترميز الروابط).
  String _withOverlap(String serverNow) {
    final t = DateTime.tryParse(serverNow);
    if (t == null) return serverNow;
    return t.subtract(overlap).toUtc().toIso8601String();
  }
}
