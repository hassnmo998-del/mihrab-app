import 'package:flutter/foundation.dart';

import '../../core/utils/access_code_generator.dart';
import '../../domain/repositories/auth_session_repository.dart';
import '../../models/models.dart';
import '../datasources/local_storage_datasource.dart';
import '../datasources/supabase_remote_datasource.dart';

/// Helper extension — بديل خفيف لـ package:collection
extension _ListX<T> on List<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    for (final e in this) {
      if (test(e)) return e;
    }
    return null;
  }
}

/// Concrete implementation of [AuthSessionRepository] managing multi-role
/// sessions and hierarchical codeless verification.
///
/// Branch isolation invariant: no code resolved here may ever produce a session
/// whose `mosqueId` belongs to a branch other than the one the code was issued
/// for. In particular a women's provisioning token (`WMV-…`) resolves to **no
/// session at all** — it is redeemed through the provisioning flow, which
/// creates a separate women's mosque with its own access code.
class AuthSessionRepositoryImpl implements AuthSessionRepository {
  final LocalStorageDataSource _localDataSource;
  final SupabaseRemoteDataSource? _remoteDataSource;

  AuthSessionRepositoryImpl(
    this._localDataSource, {
    SupabaseRemoteDataSource? remoteDataSource,
  }) : _remoteDataSource = remoteDataSource;

  @override
  ActiveSession? get currentSession => _localDataSource.currentSession;

  @override
  List<ActiveSession> get savedSessions =>
      List.unmodifiable(_localDataSource.savedSessions);

  @override
  void switchSession(ActiveSession session) {
    if (!_localDataSource.savedSessions.any((s) => s.code == session.code)) {
      _localDataSource.savedSessions.add(session);
    }
    _localDataSource.currentSession = session;
    if (session.role == 'student') {
      _localDataSource.activeStudentId = session.studentId ?? session.code;
    }
    _localDataSource.saveToStorage();
  }

  @override
  void setRoleSession(ActiveSession session) {
    if (session.role == 'student') {
      addStudentSession(session);
      return;
    }
    _localDataSource.savedSessions.removeWhere((s) => s.role == session.role);
    _localDataSource.savedSessions.add(session);
    _localDataSource.currentSession = session;
    _localDataSource.saveToStorage();
  }

  @override
  List<ActiveSession> getStudentSessions() {
    final seen = <String>{};
    final list = <ActiveSession>[];
    for (final s in _localDataSource.savedSessions) {
      if (s.role == 'student') {
        final key = s.studentId ?? s.code;
        if (key.isNotEmpty && seen.add(key)) {
          list.add(s);
        }
      }
    }
    return List.unmodifiable(list);
  }

  @override
  ActiveSession? getActiveStudentSession() {
    final studentSessions = getStudentSessions();
    if (studentSessions.isEmpty) return null;

    if (_localDataSource.activeStudentId != null) {
      final matched = studentSessions.firstWhereOrNull(
        (s) => s.studentId == _localDataSource.activeStudentId || s.code == _localDataSource.activeStudentId,
      );
      if (matched != null) return matched;
    }

    if (_localDataSource.currentSession?.role == 'student') {
      final current = _localDataSource.currentSession!;
      final matched = studentSessions.firstWhereOrNull(
        (s) => (s.studentId != null && s.studentId == current.studentId) || s.code == current.code,
      );
      if (matched != null) {
        _localDataSource.activeStudentId = matched.studentId ?? matched.code;
        return matched;
      }
    }

    final first = studentSessions.first;
    _localDataSource.activeStudentId = first.studentId ?? first.code;
    return first;
  }

  @override
  void setActiveStudent(String studentId) {
    final studentSessions = getStudentSessions();
    final target = studentSessions.firstWhereOrNull(
      (s) => s.studentId == studentId || s.code == studentId,
    );
    if (target != null) {
      _localDataSource.activeStudentId = target.studentId ?? target.code;
      if (_localDataSource.currentSession?.role == 'student') {
        _localDataSource.currentSession = target;
      }
      _localDataSource.saveToStorage();
    }
  }

  @override
  void addStudentSession(ActiveSession session) {
    if (session.role != 'student') {
      setRoleSession(session);
      return;
    }
    _localDataSource.savedSessions.removeWhere(
      (s) => s.role == 'student' && (
        (session.studentId != null && s.studentId == session.studentId) ||
        (session.studentId == null && s.code == session.code)
      ),
    );
    _localDataSource.savedSessions.add(session);
    _localDataSource.activeStudentId = session.studentId ?? session.code;
    if (_localDataSource.currentSession?.role == 'student' || _localDataSource.currentSession == null) {
      _localDataSource.currentSession = session;
    }
    _localDataSource.saveToStorage();
  }

  @override
  void removeStudentSession(String studentId) {
    _localDataSource.savedSessions.removeWhere(
      (s) => s.role == 'student' && (s.studentId == studentId || s.code == studentId),
    );
    if (_localDataSource.activeStudentId == studentId) {
      final remaining = getStudentSessions();
      if (remaining.isNotEmpty) {
        _localDataSource.activeStudentId = remaining.first.studentId ?? remaining.first.code;
        if (_localDataSource.currentSession?.role == 'student') {
          _localDataSource.currentSession = remaining.first;
        }
      } else {
        _localDataSource.activeStudentId = null;
        if (_localDataSource.currentSession?.role == 'student') {
          _localDataSource.currentSession = _localDataSource.savedSessions.isNotEmpty
              ? _localDataSource.savedSessions.last
              : null;
        }
      }
    }
    _localDataSource.saveToStorage();
  }

  @override
  ActiveSession? getSessionForRole(String role) {
    if (role == 'student') {
      return getActiveStudentSession();
    }
    if (_localDataSource.currentSession?.role == role) {
      return _localDataSource.currentSession;
    }
    for (final s in _localDataSource.savedSessions) {
      if (s.role == role) return s;
    }
    return null;
  }

  @override
  bool hasRole(String role) {
    if (role == 'student') {
      return getStudentSessions().isNotEmpty || _localDataSource.currentSession?.role == 'student';
    }
    return getSessionForRole(role) != null;
  }

  @override
  void disconnectRole(String role) {
    if (role == 'student') {
      _localDataSource.activeStudentId = null;
    }
    _localDataSource.savedSessions.removeWhere((s) => s.role == role);
    if (_localDataSource.currentSession?.role == role) {
      _localDataSource.currentSession =
          _localDataSource.savedSessions.isNotEmpty
          ? _localDataSource.savedSessions.last
          : null;
    }
    _localDataSource.saveToStorage();
  }

  @override
  void clearSession() {
    _localDataSource.currentSession = null;
    _localDataSource.saveToStorage();
  }

  /// True when the saved session still matches a live record.
  ///
  /// Mosque sessions are matched against the mosque's own access code *or* its
  /// cashier code, so a branch admin logged in with the branch code stays valid
  /// while a code that was rotated away is dropped.
  bool _isSessionStillValid(ActiveSession s) {
    switch (s.role) {
      case 'sheikh':
        return _localDataSource.sheikhs.any(
          (sh) =>
              (s.sheikhId != null && sh.id == s.sheikhId) || sh.code == s.code,
        );
      case 'student':
        return _localDataSource.students.any(
          (st) =>
              (s.studentId != null && st.id == s.studentId) ||
              st.code == s.code,
        );
      case 'mosque_admin':
        final m = _localDataSource.mosques.firstWhereOrNull(
          (m) => m.id == s.mosqueId,
        );
        if (m == null) return false;
        return m.accessCode.isNotEmpty &&
            m.accessCode.toUpperCase() == s.code.trim().toUpperCase();
      case 'cashier':
        // يكفي بقاء المسجد: كود الصراف يُفرض عند الدخول (يُطابَق مع كود المسجد
        // نفسه لا بمجرد البادئة)، والتشديد هنا كان سيُخرج صرافين تحمل بطاقاتهم
        // أكواداً صدرت قبل التحصين.
        return _localDataSource.mosques.any((m) => m.id == s.mosqueId);
      default:
        return true;
    }
  }

  @override
  void validateActiveSessions() {
    // An empty cache means "not loaded yet" (offline boot, failed sync), never
    // "everything was deleted" — pruning here would log the admin out for free.
    if (_localDataSource.mosques.isEmpty &&
        _localDataSource.sheikhs.isEmpty &&
        _localDataSource.students.isEmpty) {
      return;
    }

    bool changed = false;
    final toRemove = <ActiveSession>[];

    for (final s in _localDataSource.savedSessions) {
      if (s.role == 'super_admin' || s.role == 'visitor') continue;
      if (!_isSessionStillValid(s)) {
        toRemove.add(s);
        changed = true;
      }
    }

    if (toRemove.isNotEmpty) {
      _localDataSource.savedSessions.removeWhere((s) => toRemove.contains(s));
    }

    // Re-point the active session only when it is the one that went invalid.
    final cur = _localDataSource.currentSession;
    if (cur != null &&
        cur.role != 'super_admin' &&
        cur.role != 'visitor' &&
        !_isSessionStillValid(cur)) {
      _localDataSource.currentSession =
          _localDataSource.savedSessions.isNotEmpty
          ? _localDataSource.savedSessions.last
          : null;
      changed = true;
    }

    if (_localDataSource.activeStudentId != null) {
      final stillExists = _localDataSource.savedSessions.any(
        (s) => s.role == 'student' && (s.studentId == _localDataSource.activeStudentId || s.code == _localDataSource.activeStudentId),
      );
      if (!stillExists) {
        final remaining = _localDataSource.savedSessions.where((s) => s.role == 'student');
        _localDataSource.activeStudentId = remaining.isNotEmpty
            ? (remaining.first.studentId ?? remaining.first.code)
            : null;
        changed = true;
      }
    }

    if (changed) {
      _localDataSource.saveToStorage();
    }
  }

  @override
  Future<ActiveSession?> verifyCode(String code) async {
    final cleanCode = code.trim().toUpperCase();
    if (cleanCode.isEmpty) return null;

    // ─────────────────────────────────────────────
    // Branch provisioning tokens are never login credentials. They are redeemed
    // through DataService.redeemWomenProvisionToken, which creates a separate
    // women's mosque. Legacy `WM-` codes (derivable from the mosque code) are
    // refused outright.
    // ─────────────────────────────────────────────
    if (AccessCodeGenerator.isWomenProvisionToken(cleanCode) ||
        AccessCodeGenerator.isLegacyWomenCode(cleanCode)) {
      debugPrint(
        '⛔ رمز قسم نسائي لا يُستخدم للدخول — يُستبدل بإنشاء إدارة مستقلة.',
      );
      return null;
    }

    ActiveSession? session = _lookupLocal(cleanCode);

    // إذا ما لقينا محلياً → نسأل Supabase مع timeout
    // هذا يضمن أي جهاز جديد يقدر يمسح الباركود حتى لو ما عنده cache
    if (session == null && _remoteDataSource != null) {
      session = await _lookupRemote(
        cleanCode,
      ).timeout(const Duration(seconds: 8), onTimeout: () => null);
    }

    if (session != null) {
      _saveSession(session);
      await _localDataSource.saveToStorage();
    }

    return session;
  }

  /// البحث الفوري في الذاكرة المحلية
  ActiveSession? _lookupLocal(String cleanCode) {
    // 1. Mosque administration — the branch's own access code only.
    final mosque = _localDataSource.mosques.firstWhereOrNull(
      (m) => m.accessCode.isNotEmpty && m.accessCode.toUpperCase() == cleanCode,
    );
    if (mosque != null) return _mosqueAdminSession(mosque);

    // 2. Cashier — matched against the mosque that owns the code, never the
    //    first mosque in the cache.
    final cashierMosque = _localDataSource.mosques.firstWhereOrNull(
      (m) => m.effectiveCashierCode.toUpperCase() == cleanCode,
    );
    if (cashierMosque != null) return _cashierSession(cashierMosque);

    // 3. Sheikh
    final sheikh = _localDataSource.sheikhs.firstWhereOrNull(
      (s) => s.code.toUpperCase() == cleanCode,
    );
    if (sheikh != null) {
      final m = _localDataSource.mosques.firstWhereOrNull(
        (m) => m.id == sheikh.mosqueId,
      );
      return ActiveSession(
        role: 'sheikh',
        code: sheikh.code,
        name: sheikh.fullName,
        sheikhId: sheikh.id,
        mosqueId: sheikh.mosqueId,
        mosqueName: m?.name ?? 'المسجد',
        gender: m?.gender ?? 'male',
      );
    }

    // 4. Student
    final student = _localDataSource.students.firstWhereOrNull(
      (s) => s.code.toUpperCase() == cleanCode,
    );
    if (student != null) {
      final m = _localDataSource.mosques.firstWhereOrNull(
        (m) => m.id == student.mosqueId,
      );
      // The mosque branch wins over a stale per-student gender value so a girl
      // registered in a women's branch can never be pulled into the men's side.
      return ActiveSession(
        role: 'student',
        code: student.code,
        name: student.fullName,
        studentId: student.id,
        halaqaId: student.halaqaId,
        mosqueId: student.mosqueId,
        mosqueName: m?.name ?? 'المسجد',
        gender: m?.gender ?? student.gender,
      );
    }

    return null;
  }

  ActiveSession _mosqueAdminSession(Mosque mosque) => ActiveSession(
    role: 'mosque_admin',
    code: mosque.accessCode,
    name: mosque.isWomenSection
        ? 'إدارة ${mosque.name} (القسم النسائي)'
        : 'مدير ${mosque.name}',
    mosqueId: mosque.id,
    mosqueName: mosque.name,
    gender: mosque.gender,
  );

  ActiveSession _cashierSession(Mosque mosque) => ActiveSession(
    role: 'cashier',
    code: mosque.effectiveCashierCode,
    name: 'صراف جوائز ${mosque.name}',
    mosqueId: mosque.id,
    mosqueName: mosque.name,
    gender: mosque.gender,
  );

  /// البحث في Supabase + تحديث الـ cache المحلي
  Future<ActiveSession?> _lookupRemote(String cleanCode) async {
    if (_remoteDataSource == null) return null;
    final remote = _remoteDataSource;

    // 1. Mosque administration / cashier — one exact-match lookup, so a scanned
    //    code never pulls a list of mosques with their codes.
    final rMosque = await remote.resolveMosqueByCode(cleanCode);
    if (rMosque != null) {
      final m = Mosque.fromJson(rMosque);
      _upsertLocal(_localDataSource.mosques, m, (e) => e.id == m.id);
      if (m.accessCode.isNotEmpty && m.accessCode.toUpperCase() == cleanCode) {
        return _mosqueAdminSession(m);
      }
      if (m.effectiveCashierCode.toUpperCase() == cleanCode) {
        return _cashierSession(m);
      }
      // رمز تسليم القسم النسائي لا يمنح جلسة — يُعالج في مسار الإنشاء
      return null;
    }

    // 2. Cashier badges printed before the hardening carried a code derived from
    //    the mosque code; يُقبل عبر مطابقة كود المسجد المقابل فقط.
    if (cleanCode.startsWith(AccessCodeGenerator.cashierPrefix)) {
      final legacy = await remote.resolveMosqueByCode(
        cleanCode.replaceFirst(
          AccessCodeGenerator.cashierPrefix,
          AccessCodeGenerator.mosquePrefix,
        ),
      );
      if (legacy != null) {
        final m = Mosque.fromJson(legacy);
        _upsertLocal(_localDataSource.mosques, m, (e) => e.id == m.id);
        if (m.effectiveCashierCode.toUpperCase() == cleanCode) {
          return _cashierSession(m);
        }
      }
    }

    // 3. Sheikh Remote
    final rSheikh = await remote.fetchOneByColumn('sheikhs', 'code', cleanCode);
    if (rSheikh != null) {
      final s = Sheikh.fromJson(rSheikh);
      _upsertLocal(_localDataSource.sheikhs, s, (e) => e.id == s.id);
      final m = await _resolveRemoteMosque(remote, s.mosqueId);
      return ActiveSession(
        role: 'sheikh',
        code: s.code,
        name: s.fullName,
        sheikhId: s.id,
        mosqueId: s.mosqueId,
        mosqueName: m?.name ?? 'المسجد',
        gender: m?.gender ?? 'male',
      );
    }

    // 4. Student Remote
    final rStudent = await remote.fetchOneByColumn(
      'students',
      'code',
      cleanCode,
    );
    if (rStudent != null) {
      final st = Student.fromJson(rStudent);
      _upsertLocal(_localDataSource.students, st, (e) => e.id == st.id);
      final m = await _resolveRemoteMosque(remote, st.mosqueId);
      if (st.halaqaId.isNotEmpty) {
        await _resolveRemoteHalaqa(remote, st.halaqaId);
      }
      if (st.sheikhId != null && st.sheikhId!.isNotEmpty) {
        await _resolveRemoteSheikh(remote, st.sheikhId!);
      }
      return ActiveSession(
        role: 'student',
        code: st.code,
        name: st.fullName,
        studentId: st.id,
        halaqaId: st.halaqaId,
        mosqueId: st.mosqueId,
        mosqueName: m?.name ?? 'المسجد',
        gender: m?.gender ?? st.gender,
      );
    }

    return null;
  }

  /// جلب بيانات المسجد من Remote أو من الـ cache المحلي
  Future<Mosque?> _resolveRemoteMosque(dynamic remote, String mosqueId) async {
    final local = _localDataSource.mosques.firstWhereOrNull(
      (m) => m.id == mosqueId,
    );
    if (local != null) return local;
    final rm = await remote.fetchOneByColumn('mosques', 'id', mosqueId);
    if (rm != null) {
      final m = Mosque.fromJson(rm);
      _localDataSource.mosques.add(m);
      return m;
    }
    return null;
  }

  /// جلب بيانات الحلقة من Remote أو من الـ cache المحلي
  Future<Halaqa?> _resolveRemoteHalaqa(dynamic remote, String halaqaId) async {
    final local = _localDataSource.halaqat.firstWhereOrNull(
      (h) => h.id == halaqaId,
    );
    if (local != null) return local;
    final rh = await remote.fetchOneByColumn('halaqat', 'id', halaqaId);
    if (rh != null) {
      final h = Halaqa.fromJson(rh);
      _localDataSource.halaqat.add(h);
      return h;
    }
    return null;
  }

  /// جلب بيانات الشيخ المشرف من Remote أو من الـ cache المحلي
  Future<Sheikh?> _resolveRemoteSheikh(dynamic remote, String sheikhId) async {
    final local = _localDataSource.sheikhs.firstWhereOrNull(
      (s) => s.id == sheikhId,
    );
    if (local != null) return local;
    final rs = await remote.fetchOneByColumn('sheikhs', 'id', sheikhId);
    if (rs != null) {
      final s = Sheikh.fromJson(rs);
      _localDataSource.sheikhs.add(s);
      return s;
    }
    return null;
  }

  /// إضافة أو تحديث عنصر في الـ list المحلية (upsert)
  void _upsertLocal<T>(List<T> list, T item, bool Function(T) predicate) {
    final idx = list.indexWhere(predicate);
    if (idx >= 0) {
      list[idx] = item; // تحديث البيانات الموجودة بأحدث نسخة من Remote
    } else {
      list.add(item);
    }
  }

  /// حفظ الجلسة — يستبدل نفس الرتبة القديمة تلقائياً (setRoleSession semantics)
  void _saveSession(ActiveSession session) {
    if (session.role == 'student') {
      addStudentSession(session);
      return;
    }
    _localDataSource.savedSessions.removeWhere((s) => s.role == session.role);
    _localDataSource.savedSessions.add(session);
    _localDataSource.currentSession = session;
  }
}
