import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/models.dart';

/// Dedicated remote data source wrapping all Supabase cloud client operations
/// across all 16 database tables with built-in fault tolerance.
class SupabaseRemoteDataSource {
  static const String defaultSupabaseUrl =
      'https://mltxsmonudbtnrloqawf.supabase.co';
  static const String defaultSupabaseAnonKey =
      'sb_publishable_yr45qpkrG5Fp20pAbS7NJg_DCIYQHuf';

  final String url;
  final String anonKey;

  SupabaseRemoteDataSource({
    this.url = defaultSupabaseUrl,
    this.anonKey = defaultSupabaseAnonKey,
  });

  /// Safe accessor to initialized SupabaseClient
  SupabaseClient? get client {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  /// Initialize Supabase Flutter SDK silently
  Future<void> initialize() async {
    try {
      await Supabase.initialize(url: url, anonKey: anonKey);
    } catch (e) {
      debugPrint('⚠️ Supabase initialize note: $e');
    }
  }

  /// ينتظر انتهاء استرجاع جلسة المصادقة المحفوظة على الجهاز.
  ///
  /// `Supabase.initialize()` لا ينتظر الاسترجاع: يشغّل `recoverSession()` في
  /// الخلفية ويعود فوراً، فتكون `auth.currentSession` فارغة لأجزاء من الثانية
  /// بعد الإقلاع. من يقرأها مباشرة يظن أن المستخدم غير مسجَّل دخوله.
  ///
  /// يعود فور ظهور الجلسة، أو بعد انتهاء المهلة إن لم تكن هناك جلسة محفوظة.
  /// نستطلع الحالة بدل انتظار حدث `onAuthStateChange`: الحدث قد يقع في الفجوة
  /// بين `initialize()` والاشتراك في البث فيضيع، أما الاستطلاع فلا يفوته شيء.
  static const Duration _sessionPollInterval = Duration(milliseconds: 100);

  Future<void> waitForSessionRestore({
    Duration timeout = const Duration(seconds: 6),
  }) async {
    final c = client;
    if (c == null) return;
    await waitUntil(() => c.auth.currentSession != null, timeout: timeout);
  }

  /// ينتظر تحقّق [ready] بالاستطلاع، ويعيد ما إذا تحقّق قبل انتهاء المهلة.
  @visibleForTesting
  static Future<bool> waitUntil(
    bool Function() ready, {
    Duration timeout = const Duration(seconds: 6),
    Duration interval = _sessionPollInterval,
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (!ready()) {
      if (!DateTime.now().isBefore(deadline)) return false;
      await Future.delayed(interval);
    }
    return true;
  }

  final Set<String> _missingTablesNotified = {};

  /// Generic query to fetch all records from a remote table
  Future<List<Map<String, dynamic>>?> fetchTable(String table) async {
    final c = client;
    if (c == null) return null;
    try {
      final res = await c.from(table).select();
      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      if (e is PostgrestException && e.code == 'PGRST205') {
        if (!_missingTablesNotified.contains(table)) {
          _missingTablesNotified.add(table);
          debugPrint(
            'ℹ️ جدول ($table) غير منشأ بعد في قاعدة بيانات Supabase. يمكن إنشاؤه من خلال تشغيل سكربت supabase_schema.sql',
          );
        }
        return null;
      }
      debugPrint('⚠️ Supabase fetchTable error ($table): $e');
      return null;
    }
  }

  /// Mosque rows for the periodic sync.
  Future<List<Map<String, dynamic>>?> fetchMosquesForSync() =>
      fetchTable('mosques');

  /// Resolves one mosque by an exact match on any of its codes (admin, women's
  /// handover token, cashier). Callers decide what the match grants.
  Future<Map<String, dynamic>?> resolveMosqueByCode(String code) async {
    final clean = code.trim();
    if (clean.isEmpty) return null;
    for (final column in const [
      'access_code',
      'women_access_code',
      'cashier_access_code',
    ]) {
      final row = await fetchOneByColumn('mosques', column, clean);
      if (row != null) return row;
    }
    return null;
  }

  /// Generic query to fetch a single record from a remote table by column value
  Future<Map<String, dynamic>?> fetchOneByColumn(
    String table,
    String column,
    dynamic value,
  ) async {
    final c = client;
    if (c == null) return null;
    try {
      final res = await c.from(table).select().eq(column, value).maybeSingle();
      return res;
    } catch (e) {
      debugPrint(
        '⚠️ Supabase fetchOneByColumn error ($table.$column=$value): $e',
      );
      return null;
    }
  }

  final Set<String> _missingColumnsNotified = {};

  /// Columns introduced by a migration that may not be applied yet. An upsert
  /// that fails on an unknown column is retried once without them, so shipping
  /// the app before running the SQL migration degrades instead of breaking.
  static const Map<String, Set<String>> _optionalColumns = {
    'mosques': Mosque.branchColumns,
  };

  /// Generic upsert record into a remote table
  Future<void> upsert(String table, Map<String, dynamic> data) async {
    final c = client;
    if (c == null) return;
    try {
      await c.from(table).upsert(data);
    } catch (e) {
      if (e is PostgrestException && e.code == 'PGRST205') {
        if (!_missingTablesNotified.contains(table)) {
          _missingTablesNotified.add(table);
          debugPrint(
            'ℹ️ تعذر رفع السجل لأن جدول ($table) غير موجود في Supabase. يرجى إنشاؤه.',
          );
        }
        return;
      }

      final optional = _optionalColumns[table];
      if (optional != null &&
          _isUnknownColumnError(e, optional) &&
          data.keys.any(optional.contains)) {
        final trimmed = Map<String, dynamic>.from(data)
          ..removeWhere((key, _) => optional.contains(key));
        if (_missingColumnsNotified.add(table)) {
          debugPrint(
            'ℹ️ جدول ($table) لم تُطبَّق عليه ترقية عزل الفروع بعد. '
            'شغّل supabase/migrations/women_branch_isolation.sql لتُحفظ حقول الفرع سحابياً.',
          );
        }
        try {
          await c.from(table).upsert(trimmed);
          return;
        } catch (retryError) {
          debugPrint('⚠️ Supabase upsert retry error ($table): $retryError');
          rethrow;
        }
      }

      debugPrint('⚠️ Supabase upsert error ($table): $e');
      rethrow;
    }
  }

  bool _isUnknownColumnError(Object error, Set<String> columns) {
    if (error is! PostgrestException) return false;
    // PGRST204: column not found in schema cache · 42703: undefined_column
    if (error.code == 'PGRST204' || error.code == '42703') return true;
    final message = error.message.toLowerCase();
    return columns.any((c) => message.contains(c));
  }

  /// Generic insert record into a remote table
  Future<void> insert(String table, Map<String, dynamic> data) async {
    final c = client;
    if (c == null) return;
    try {
      await c.from(table).insert(data);
    } catch (e) {
      debugPrint('⚠️ Supabase insert error ($table): $e');
      rethrow;
    }
  }

  /// Generic update record in a remote table matching a specific column
  Future<void> update(
    String table,
    Map<String, dynamic> data, {
    required String matchingColumn,
    required dynamic matchingValue,
  }) async {
    final c = client;
    if (c == null) return;
    try {
      await c.from(table).update(data).eq(matchingColumn, matchingValue);
    } catch (e) {
      debugPrint('⚠️ Supabase update error ($table): $e');
      rethrow;
    }
  }

  /// Generic delete record from a remote table matching a specific column
  Future<void> delete(
    String table, {
    required String matchingColumn,
    required dynamic matchingValue,
  }) async {
    final c = client;
    if (c == null) return;
    try {
      await c.from(table).delete().eq(matchingColumn, matchingValue);
    } catch (e) {
      debugPrint('⚠️ Supabase delete error ($table): $e');
      rethrow;
    }
  }
}
