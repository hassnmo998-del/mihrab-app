import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/sync/scaled_sync_engine.dart';
import 'supabase_remote_datasource.dart';

/// تنفيذ [ScaledSyncRemote] فوق Supabase: دالة `sync_changes` وجلب بالصفحات بمفتاح
/// (updated_at، id) لكل مسجد على حدة (انظر `supabase/migrations/scale_sync.sql`).
class SupabaseScaledSyncRemote implements ScaledSyncRemote {
  final SupabaseRemoteDataSource _remote;
  SupabaseScaledSyncRemote(this._remote);

  /// حجم الصفحة. الخادم يقصّ كل طلب عند ألف صف.
  @visibleForTesting
  static int pageSize = 1000;

  /// الدالة غير موجودة في الخادم = الترقية لم تُطبَّق (أو القاعدة جديدة بلا الملف).
  @visibleForTesting
  static bool isMissingFunction(Object error) {
    if (error is! PostgrestException) return false;
    final code = (error.code ?? '').toUpperCase();
    if (code == 'PGRST202' || code == '42883') return true;
    return error.message.contains('Could not find the function');
  }

  /// يفكّ جواب `sync_changes`؛ يرمي [FormatException] إن لم يطابق الشكل المتوقع.
  @visibleForTesting
  static SyncProbe parseProbe(Object? raw) {
    if (raw is! Map) throw const FormatException('sync_changes: not an object');
    final now = raw['server_now'];
    if (now is! String || now.isEmpty) {
      throw const FormatException('sync_changes: missing server_now');
    }
    final changed = <String>{};
    final rawChanged = raw['changed'];
    if (rawChanged is Map) {
      rawChanged.forEach((k, v) {
        if (v == true) changed.add('$k');
      });
    }
    final tombs = <SyncTombstone>[];
    final rawTombs = raw['tombstones'];
    if (rawTombs is List) {
      for (final t in rawTombs) {
        if (t is Map && t['t'] is String && t['id'] is String) {
          tombs.add(SyncTombstone(t['t'] as String, t['id'] as String));
        }
      }
    }
    return SyncProbe(
      serverNow: now,
      changedTables: changed,
      tombstones: tombs,
      tombstonesMore: raw['tombstones_more'] == true,
    );
  }

  @override
  Future<ProbeResult> probe(List<String> mosqueIds, String? since) async {
    final c = _remote.client;
    if (c == null) return const ProbeResult(ProbeStatus.failed);
    try {
      final dynamic res = await c
          .rpc('sync_changes', params: {'p_mosque_ids': mosqueIds, 'p_since': since})
          .timeout(const Duration(seconds: 10));
      return ProbeResult(ProbeStatus.ok, parseProbe(res));
    } catch (e) {
      if (isMissingFunction(e)) return const ProbeResult(ProbeStatus.unsupported);
      if (e is TimeoutException) {
        debugPrint('⏱️ sync_changes timeout');
      } else {
        debugPrint('⚠️ sync_changes error: $e');
      }
      return const ProbeResult(ProbeStatus.failed);
    }
  }

  @override
  Future<List<Map<String, dynamic>>?> fetchTable(
    String table,
    String mosqueId, {
    String? since,
  }) async {
    final c = _remote.client;
    if (c == null) return null;
    try {
      final rows = <Map<String, dynamic>>[];
      String? lastUpdated;
      String? lastId;
      while (true) {
        var q = c.from(table).select().eq('mosque_id', mosqueId);
        if (since != null) q = q.gte('updated_at', since);
        if (lastUpdated != null) {
          // صفحة تالية بعد آخر (updated_at، id): إضافة صف أثناء الجلب لا تُسقط غيره
          q = q.or(
            'updated_at.gt.$lastUpdated,'
            'and(updated_at.eq.$lastUpdated,id.gt."$lastId")',
          );
        }
        final page = await q
            .order('updated_at', ascending: true)
            .order('id', ascending: true)
            .limit(pageSize)
            .timeout(const Duration(seconds: 15));
        rows.addAll(List<Map<String, dynamic>>.from(page));
        if (page.length < pageSize) return rows;
        lastUpdated = page.last['updated_at']?.toString();
        lastId = page.last['id']?.toString();
        if (lastUpdated == null || lastId == null) return null;
      }
    } catch (e) {
      debugPrint('⚠️ scoped fetch error ($table/$mosqueId): $e');
      return null;
    }
  }

  @override
  Future<List<Map<String, dynamic>>?> fetchMosqueRows(
    Iterable<String> ids, {
    String? since,
  }) async {
    final list = ids.toList();
    if (list.isEmpty) return const [];
    final c = _remote.client;
    if (c == null) return null;
    try {
      var q = c.from('mosques').select().inFilter('id', list);
      if (since != null) q = q.gte('updated_at', since);
      final page = await q.limit(pageSize).timeout(const Duration(seconds: 15));
      return List<Map<String, dynamic>>.from(page);
    } catch (e) {
      debugPrint('⚠️ scoped mosques fetch error: $e');
      return null;
    }
  }

  /// دروس «اكتشف» العامة قرب موقع الزائر: مربع حول الإحداثيات بدل كل دروس الدولة.
  /// دون موقع: أحدث الدروس تعديلاً. `null` عند الفشل.
  Future<List<Map<String, dynamic>>?> fetchDiscoverEvents({
    double? latitude,
    double? longitude,
    double span = 0.25,
    int limit = 400,
  }) async {
    final c = _remote.client;
    if (c == null) return null;
    try {
      var q = c
          .from('community_events')
          .select()
          .eq('is_active', true)
          .neq('event_type', 'system_donation_config');
      if (latitude != null && longitude != null) {
        q = q
            .gte('latitude', latitude - span)
            .lte('latitude', latitude + span)
            .gte('longitude', longitude - span)
            .lte('longitude', longitude + span);
      }
      final page = await q
          .order('updated_at', ascending: false)
          .limit(limit)
          .timeout(const Duration(seconds: 15));
      return List<Map<String, dynamic>>.from(page);
    } catch (e) {
      debugPrint('⚠️ discover events fetch error: $e');
      return null;
    }
  }
}
