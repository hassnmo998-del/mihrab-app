import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/utils/access_code_generator.dart';
import '../../models/models.dart';
import '../../services/points_ledger.dart';

/// Dedicated local data source handling instant in-memory cache and
/// synchronous SharedPreferences serialization across all 17 entity lists,
/// sessions, and theme preferences.
class LocalStorageDataSource {
  // Theme state
  bool isDarkMode = false;

  // Super Admin persistent auth flag
  bool isSuperAdminAuthenticated = false;

  // Active Session & Saved Sessions
  ActiveSession? currentSession;
  final List<ActiveSession> savedSessions = [];
  String? activeStudentId;
  final List<String> registrationTokens = [];
  final List<Map<String, dynamic>> tokenUsageHistory = [];

  // App Mode & Onboarding
  String appMode = 'personal'; // 'personal' or 'management'
  bool hasCompletedOnboarding = false;

  // Real Dynamic In-Memory Collections
  final List<Mosque> mosques = [];
  final List<Sheikh> sheikhs = [];
  final List<Halaqa> halaqat = [];
  final List<Student> students = [];
  final List<CommunityEvent> communityEvents = [];
  final List<PointsLog> pointsLogs = [];
  final List<Competition> competitions = [];
  final List<MemorizationRecord> memorizationRecords = [];
  final List<AttendanceRecord> attendanceRecords = [];
  final List<AppMessage> messages = [];
  final List<Reward> rewards = [];
  final List<RewardRedemption> redemptions = [];
  final List<IntensiveCourse> intensiveCourses = [];
  final List<Trip> trips = [];
  final List<RecitationTrack> recitationTracks = [];
  final List<SubjectRecitationRecord> subjectRecitationRecords = [];
  final List<EventQuestion> eventQuestions = [];

  // Persistent deleted entity tombstones to prevent resurrecting deleted entities
  final Set<String> deletedEntityIds = {};

  static String genId(String prefix) => AccessCodeGenerator.entityId(prefix);

  /// سجل النقاط على هذا الجهاز مكتمل: جُلب كاملاً من السحابة مرة على الأقل. قبلها
  /// (جهاز جديد لم يُكمل أول مزامنة) يُعرض عدّاد الرصيد كما ورد، كي لا يظهر الرصيد
  /// صفراً لأن الحركات لم تصل بعد.
  bool pointsLedgerComplete = false;

  static const String _ledgerCompleteKey = 'points_ledger_complete';

  /// يُستدعى حين ينجح جلب جدول الحركات كاملاً.
  void markPointsLedgerComplete() {
    if (pointsLedgerComplete) return;
    pointsLedgerComplete = true;
    SharedPreferences.getInstance()
        .then((prefs) => prefs.setBool(_ledgerCompleteKey, true))
        .catchError((_) => false);
  }

  /// يشتق رصيد كل طالب من سجل النقاط، ويعيد true إن تغيّر رصيد.
  ///
  /// السجل هو مصدر الحقيقة (انظر [PointsLedger]): عدّاد الرصيد القادم مع سجل الطالب
  /// من السحابة قد يكون كتبه جهاز بنسخة قديمة.
  bool recomputePointBalances() {
    if (!pointsLedgerComplete) return false;
    final sums = PointsLedger.balances(pointsLogs);
    var changed = false;
    for (final student in students) {
      final balance = sums[student.id] ?? 0;
      if (student.totalPoints != balance) {
        student.totalPoints = balance;
        changed = true;
      }
    }
    return changed;
  }

  /// آخر ما كُتب تحت كل مفتاح: مفتاح لم يتغير لا يُعاد حفظه.
  ///
  /// على ويندوز كل `setString` يعيد كتابة ملف الإعدادات كله على القرص، فحفظ كل
  /// القوائم مع كل تعديل كان يعيد كتابة الملف خمساً وعشرين مرة متتالية.
  final Map<String, String> _lastWritten = {};

  /// يُنسى ما كُتب بعد مسح التخزين كله، ليُعاد حفظ كل شيء في المرة التالية.
  void forgetWrittenValues() => _lastWritten.clear();

  /// يقرأ قائمة محفوظة عنصراً عنصراً: سجل واحد تالف يُتخطّى ولا يُسقط بقية القائمة
  /// ولا القوائم التي بعدها.
  ///
  /// كان التحميل كله داخل `try` واحدة: خطأ في سجل واحد يوقفه عند تلك النقطة، فتبقى
  /// القوائم التالية فارغة في الذاكرة، ثم يكتب أول حفظ هذا الفراغ فوق البيانات.
  void _readList<T>(
    SharedPreferences prefs,
    String key,
    List<T> target,
    T Function(Map<String, dynamic>) fromJson, {
    bool Function(T)? keep,
  }) {
    String? raw;
    try {
      raw = prefs.getString(key);
      if (raw == null) return;
      final decoded = jsonDecode(raw) as List;
      final parsed = <T>[];
      var skipped = 0;
      for (final item in decoded) {
        try {
          final value = fromJson(Map<String, dynamic>.from(item as Map));
          if (keep == null || keep(value)) parsed.add(value);
        } catch (_) {
          skipped++;
        }
      }
      target
        ..clear()
        ..addAll(parsed);
      if (skipped == 0) {
        _lastWritten[key] = raw;
      } else {
        debugPrint('⚠️ التخزين المحلي: تُخطّي $skipped سجل تالف في $key');
        _keepDamagedCopy(prefs, key, raw);
      }
    } catch (e) {
      debugPrint('⚠️ التخزين المحلي: تعذّرت قراءة $key ($e)');
      if (raw != null) _keepDamagedCopy(prefs, key, raw);
    }
  }

  /// نسخة من قائمة تعذّرت قراءتها (كلها أو بعضها) قبل أن يُكتب فوقها.
  void _keepDamagedCopy(SharedPreferences prefs, String key, String raw) {
    prefs.setString('$key.damaged', raw).catchError((_) => false);
  }

  /// Loads all collections and states from SharedPreferences into in-memory cache
  Future<void> loadAllFromStorage() async {
    final SharedPreferences prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } catch (e) {
      debugPrint('⚠️ التخزين المحلي غير متاح: $e');
      return;
    }

    // كل جزء مستقل عن غيره: تعذّر قراءة أحدها لا يمنع قراءة الباقي
    void guarded(String what, void Function() read) {
      try {
        read();
      } catch (e) {
        debugPrint('⚠️ التخزين المحلي: تعذّرت قراءة $what ($e)');
      }
    }

    guarded('الإعدادات', () {
      isDarkMode = prefs.getBool('is_dark_mode') ?? false;
      appMode = prefs.getString('app_mode') ?? 'personal';
      hasCompletedOnboarding = prefs.getBool('has_completed_onboarding') ?? false;
      isSuperAdminAuthenticated = prefs.getBool('super_admin_authenticated') ?? false;
      pointsLedgerComplete = prefs.getBool(_ledgerCompleteKey) ?? false;
    });

    // Load Sessions
    _readList<ActiveSession>(
      prefs,
      'saved_sessions',
      savedSessions,
      ActiveSession.fromJson,
      keep: (s) => s.role != 'super_admin',
    );
    guarded('الجلسة النشطة', () {
      final currentCode = prefs.getString('current_session_code');
      if (currentCode != null && savedSessions.isNotEmpty) {
        currentSession = savedSessions.firstWhere(
          (s) => s.code == currentCode,
          orElse: () => savedSessions.first,
        );
      }
      activeStudentId = prefs.getString('active_student_id');
      if (activeStudentId == null && savedSessions.isNotEmpty) {
        final firstStudent = savedSessions.where((s) => s.role == 'student').firstOrNull;
        if (firstStudent != null) {
          activeStudentId = firstStudent.studentId ?? firstStudent.code;
        }
      }
    });

    _readList<Mosque>(prefs, 'real_mosques', mosques, Mosque.fromJson);
    _readList<Sheikh>(prefs, 'real_sheikhs', sheikhs, Sheikh.fromJson);
    _readList<Halaqa>(prefs, 'real_halaqat', halaqat, Halaqa.fromJson);
    _readList<Student>(prefs, 'real_students', students, Student.fromJson);
    _readList<CommunityEvent>(prefs, 'real_events', communityEvents, CommunityEvent.fromJson);
    _readList<PointsLog>(prefs, 'real_points_logs', pointsLogs, PointsLog.fromJson);
    _readList<Competition>(prefs, 'real_competitions', competitions, Competition.fromJson);
    _readList<MemorizationRecord>(
        prefs, 'real_memorization_records', memorizationRecords, MemorizationRecord.fromJson);
    _readList<AttendanceRecord>(prefs, 'real_attendance_records', attendanceRecords, AttendanceRecord.fromJson);
    _readList<AppMessage>(prefs, 'real_messages', messages, AppMessage.fromJson);
    _readList<Reward>(prefs, 'real_rewards', rewards, Reward.fromJson);
    _readList<RewardRedemption>(prefs, 'real_redemptions', redemptions, RewardRedemption.fromJson);
    _readList<IntensiveCourse>(prefs, 'real_intensive_courses', intensiveCourses, IntensiveCourse.fromJson);
    _readList<Trip>(prefs, 'real_trips', trips, Trip.fromJson);
    _readList<RecitationTrack>(prefs, 'real_recitation_tracks', recitationTracks, RecitationTrack.fromJson);
    _readList<SubjectRecitationRecord>(
        prefs, 'real_subject_recitation_records', subjectRecitationRecords, SubjectRecitationRecord.fromJson);
    _readList<EventQuestion>(prefs, 'real_event_questions', eventQuestions, EventQuestion.fromJson);
    _readList<Map<String, dynamic>>(prefs, 'token_usage_history', tokenUsageHistory, (m) => m);

    guarded('رموز التسجيل', () {
      final tokensStr = prefs.getStringList('registration_tokens');
      if (tokensStr != null) {
        registrationTokens
          ..clear()
          ..addAll(tokensStr);
      }
    });
    guarded('سجل المحذوفات', () {
      final delList = prefs.getStringList('deleted_entity_tombstones');
      if (delList != null) {
        deletedEntityIds
          ..clear()
          ..addAll(delList);
      }
    });

    recomputePointBalances();
  }

  /// Persists theme mode to SharedPreferences
  Future<void> saveThemeMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_dark_mode', isDarkMode);
    } catch (_) {}
  }

  /// Persists app mode to SharedPreferences
  Future<void> saveAppMode(String mode) async {
    try {
      appMode = mode;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('app_mode', mode);
    } catch (_) {}
  }

  /// Marks onboarding as completed and sets mode
  Future<void> completeOnboarding(String mode) async {
    try {
      appMode = mode;
      hasCompletedOnboarding = true;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('app_mode', mode);
      await prefs.setBool('has_completed_onboarding', true);
    } catch (_) {}
  }

  /// Resets onboarding state (e.g. from settings for testing)
  Future<void> resetOnboarding() async {
    try {
      hasCompletedOnboarding = false;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('has_completed_onboarding', false);
    } catch (_) {}
  }

  /// يكتب القيمة إن تغيّرت عمّا كُتب آخر مرة.
  Future<void> _putString(SharedPreferences prefs, String key, String value) async {
    if (_lastWritten[key] == value) return;
    if (await prefs.setString(key, value)) _lastWritten[key] = value;
  }

  /// يحوّل قائمة إلى JSON ويحفظها؛ فشل قائمة لا يمنع حفظ ما بعدها.
  Future<void> _putJson(SharedPreferences prefs, String key, Object? Function() build) async {
    try {
      await _putString(prefs, key, jsonEncode(build()));
    } catch (e) {
      debugPrint('⚠️ التخزين المحلي: تعذّر حفظ $key ($e)');
    }
  }

  Future<void> _putStringList(SharedPreferences prefs, String key, List<String> value) async {
    try {
      final signature = jsonEncode(value);
      if (_lastWritten[key] == signature) return;
      if (await prefs.setStringList(key, value)) _lastWritten[key] = signature;
    } catch (e) {
      debugPrint('⚠️ التخزين المحلي: تعذّر حفظ $key ($e)');
    }
  }

  /// Persists all in-memory collections and session state to SharedPreferences
  Future<void> saveToStorage() async {
    final SharedPreferences prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } catch (e) {
      debugPrint('⚠️ التخزين المحلي غير متاح للحفظ: $e');
      return;
    }

    await _putJson(prefs, 'saved_sessions', () => savedSessions.map((s) => s.toJson()).toList());
    try {
      final code = currentSession?.code;
      if (code != null) {
        await _putString(prefs, 'current_session_code', code);
      } else if (prefs.containsKey('current_session_code')) {
        await prefs.remove('current_session_code');
        _lastWritten.remove('current_session_code');
      }
      final student = activeStudentId;
      if (student != null) {
        await _putString(prefs, 'active_student_id', student);
      } else if (prefs.containsKey('active_student_id')) {
        await prefs.remove('active_student_id');
        _lastWritten.remove('active_student_id');
      }
      if (prefs.getBool('super_admin_authenticated') != isSuperAdminAuthenticated) {
        await prefs.setBool('super_admin_authenticated', isSuperAdminAuthenticated);
      }
      // Legacy key from the pre-isolation "unlock women section" flow; the
      // women's branch is now a separate mosque, so nothing is ever unlocked.
      if (prefs.containsKey('unlocked_women_mosques')) {
        await prefs.remove('unlocked_women_mosques');
      }
    } catch (e) {
      debugPrint('⚠️ التخزين المحلي: تعذّر حفظ حالة الجلسة ($e)');
    }

    await _putJson(prefs, 'real_mosques', () => mosques.map((m) => m.toJson()).toList());
    await _putJson(prefs, 'real_sheikhs', () => sheikhs.map((s) => s.toJson()).toList());
    await _putJson(prefs, 'real_halaqat', () => halaqat.map((h) => h.toJson()).toList());
    await _putJson(prefs, 'real_students', () => students.map((s) => s.toJson()).toList());
    await _putJson(prefs, 'real_events', () => communityEvents.map((e) => e.toJson()).toList());
    await _putJson(prefs, 'real_points_logs', () => pointsLogs.map((p) => p.toJson()).toList());
    await _putJson(prefs, 'real_competitions', () => competitions.map((c) => c.toJson()).toList());
    await _putJson(
        prefs, 'real_memorization_records', () => memorizationRecords.map((m) => m.toJson()).toList());
    await _putJson(prefs, 'real_attendance_records', () => attendanceRecords.map((a) => a.toJson()).toList());
    await _putJson(prefs, 'real_messages', () => messages.map((m) => m.toJson()).toList());
    await _putJson(prefs, 'real_rewards', () => rewards.map((r) => r.toJson()).toList());
    await _putJson(prefs, 'real_redemptions', () => redemptions.map((r) => r.toJson()).toList());
    await _putJson(prefs, 'real_intensive_courses', () => intensiveCourses.map((c) => c.toJson()).toList());
    await _putStringList(prefs, 'registration_tokens', registrationTokens);
    await _putJson(prefs, 'token_usage_history', () => tokenUsageHistory);
    await _putJson(prefs, 'real_trips', () => trips.map((t) => t.toJson()).toList());
    await _putJson(prefs, 'real_recitation_tracks', () => recitationTracks.map((t) => t.toJson()).toList());
    await _putJson(prefs, 'real_subject_recitation_records',
        () => subjectRecitationRecords.map((r) => r.toJson()).toList());
    await _putJson(prefs, 'real_event_questions', () => eventQuestions.map((q) => q.toJson()).toList());
    await _putStringList(prefs, 'deleted_entity_tombstones', deletedEntityIds.toList());
  }

  /// Records a tombstone for a deleted entity so it is never re-imported or resurrected.
  void recordDeletedId(String id) {
    if (id.isEmpty) return;
    deletedEntityIds.add(id);
    // Keep max 1000 tombstones to prevent unbounded growth over time
    if (deletedEntityIds.length > 1000) {
      deletedEntityIds.remove(deletedEntityIds.first);
    }
    // Async persistent backup immediately
    SharedPreferences.getInstance().then((prefs) {
      _putStringList(prefs, 'deleted_entity_tombstones', deletedEntityIds.toList());
    }).catchError((_) {});
  }

  /// Whether this entity was deleted on this device
  bool isEntityDeleted(String id) => deletedEntityIds.contains(id);
}
