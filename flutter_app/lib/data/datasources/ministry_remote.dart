import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_remote_datasource.dart';

/// أرقام الإشراف العام والقائمة بصفحات، يحسبها الخادم (`ministry_overview`
/// و`ministry_mosques` في `scale_sync.sql`) بدل أن يحمّل الجهاز بيانات الدولة كلها.

class MinistryCity {
  final String city;
  final int mosques;
  const MinistryCity(this.city, this.mosques);
}

class MinistryOverview {
  final int mosquesMen;
  final int mosquesWomen;
  final int sheikhs;
  final int halaqat;
  final int students;
  final int attendanceToday;
  final int activeMosques7d;
  final int newMosques30d;
  final List<MinistryCity> cities;

  const MinistryOverview({
    this.mosquesMen = 0,
    this.mosquesWomen = 0,
    this.sheikhs = 0,
    this.halaqat = 0,
    this.students = 0,
    this.attendanceToday = 0,
    this.activeMosques7d = 0,
    this.newMosques30d = 0,
    this.cities = const [],
  });

  int get mosques => mosquesMen + mosquesWomen;

  static int _i(Object? v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;

  factory MinistryOverview.fromJson(Map<String, dynamic> j) => MinistryOverview(
        mosquesMen: _i(j['mosques_men']),
        mosquesWomen: _i(j['mosques_women']),
        sheikhs: _i(j['sheikhs']),
        halaqat: _i(j['halaqat']),
        students: _i(j['students']),
        attendanceToday: _i(j['attendance_today']),
        activeMosques7d: _i(j['active_mosques_7d']),
        newMosques30d: _i(j['new_mosques_30d']),
        cities: [
          for (final c in (j['cities'] as List? ?? const []))
            if (c is Map) MinistryCity('${c['city']}', _i(c['mosques'])),
        ],
      );
}

class MinistryMosqueRow {
  final String id;
  final String name;
  final String city;
  final String? address;
  final String gender;
  final String? parentMosqueId;
  final DateTime? createdAt;

  /// لا يصل للقسم النسائي أبداً (يبقى عند إدارته).
  final String? accessCode;
  final int halaqatCount;
  final int sheikhsCount;
  final int studentsCount;
  final DateTime? lastActivity;

  const MinistryMosqueRow({
    required this.id,
    required this.name,
    this.city = '',
    this.address,
    this.gender = 'male',
    this.parentMosqueId,
    this.createdAt,
    this.accessCode,
    this.halaqatCount = 0,
    this.sheikhsCount = 0,
    this.studentsCount = 0,
    this.lastActivity,
  });

  bool get isWomenSection => gender == 'female';

  factory MinistryMosqueRow.fromJson(Map<String, dynamic> j) => MinistryMosqueRow(
        id: '${j['id']}',
        name: '${j['name'] ?? ''}',
        city: '${j['city'] ?? ''}',
        address: j['address'] as String?,
        gender: '${j['gender'] ?? 'male'}',
        parentMosqueId: j['parent_mosque_id'] as String?,
        createdAt: DateTime.tryParse('${j['created_at']}'),
        accessCode: j['access_code'] as String?,
        halaqatCount: MinistryOverview._i(j['halaqat_count']),
        sheikhsCount: MinistryOverview._i(j['sheikhs_count']),
        studentsCount: MinistryOverview._i(j['students_count']),
        lastActivity: DateTime.tryParse('${j['last_activity']}'),
      );
}

class MinistryPage {
  final int total;
  final List<MinistryMosqueRow> rows;
  const MinistryPage(this.total, this.rows);

  static MinistryPage fromJson(Map<String, dynamic> j) => MinistryPage(
        MinistryOverview._i(j['total']),
        [
          for (final r in (j['rows'] as List? ?? const []))
            if (r is Map) MinistryMosqueRow.fromJson(Map<String, dynamic>.from(r)),
        ],
      );
}

enum MinistryStatus {
  ok,

  /// دوال الخادم غير موجودة: ترقية القاعدة لم تُطبَّق، فتعرض الواجهة الطريقة القديمة.
  unsupported,

  /// الحساب ليس مشرفاً عاماً مسجَّلاً (أو انتهت جلسته).
  unauthorized,
  failed,
}

class MinistryResult<T> {
  final MinistryStatus status;
  final T? data;
  const MinistryResult(this.status, [this.data]);
  bool get ok => status == MinistryStatus.ok && data != null;
}

class MinistryRemote {
  final SupabaseRemoteDataSource _remote;
  MinistryRemote(this._remote);

  Future<MinistryResult<MinistryOverview>> overview() => _call(
        'ministry_overview',
        const {},
        (m) => MinistryOverview.fromJson(m),
      );

  Future<MinistryResult<MinistryPage>> mosques({
    String search = '',
    String? city,
    int limit = 40,
    int offset = 0,
  }) =>
      _call(
        'ministry_mosques',
        {
          'p_search': search.trim().isEmpty ? null : search.trim(),
          'p_city': (city == null || city.isEmpty) ? null : city,
          'p_limit': limit,
          'p_offset': offset,
        },
        MinistryPage.fromJson,
      );

  Future<MinistryResult<T>> _call<T>(
    String fn,
    Map<String, dynamic> params,
    T Function(Map<String, dynamic>) parse,
  ) async {
    final c = _remote.client;
    if (c == null) return const MinistryResult(MinistryStatus.failed);
    try {
      final dynamic res =
          await c.rpc(fn, params: params).timeout(const Duration(seconds: 20));
      if (res is! Map) return const MinistryResult(MinistryStatus.failed);
      return MinistryResult(MinistryStatus.ok, parse(Map<String, dynamic>.from(res)));
    } on PostgrestException catch (e) {
      final code = (e.code ?? '').toUpperCase();
      if (code == 'PGRST202' || code == '42883') {
        return const MinistryResult(MinistryStatus.unsupported);
      }
      if (code == '42501') return const MinistryResult(MinistryStatus.unauthorized);
      debugPrint('⚠️ $fn: $e');
      return const MinistryResult(MinistryStatus.failed);
    } catch (e) {
      debugPrint('⚠️ $fn: $e');
      return const MinistryResult(MinistryStatus.failed);
    }
  }
}
