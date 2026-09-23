import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/models.dart';

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

  static int _idCounter = 0;
  static String genId(String prefix) =>
      '$prefix-${DateTime.now().microsecondsSinceEpoch}-${_idCounter++}';

  /// Loads all collections and states from SharedPreferences into in-memory cache
  Future<void> loadAllFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      isDarkMode = prefs.getBool('is_dark_mode') ?? false;
      appMode = prefs.getString('app_mode') ?? 'personal';
      hasCompletedOnboarding = prefs.getBool('has_completed_onboarding') ?? false;
      isSuperAdminAuthenticated = prefs.getBool('super_admin_authenticated') ?? false;

      // Load Sessions
      final savedStr = prefs.getString('saved_sessions');
      if (savedStr != null) {
        final List list = jsonDecode(savedStr);
        savedSessions.clear();
        for (var item in list) {
          final s = ActiveSession.fromJson(item);
          if (s.role != 'super_admin') {
            savedSessions.add(s);
          }
        }
      }
      final currentCode = prefs.getString('current_session_code');
      if (currentCode != null && savedSessions.isNotEmpty) {
        currentSession = savedSessions.firstWhere(
          (s) => s.code == currentCode,
          orElse: () => savedSessions.first,
        );
      }

      // Load Real Mosques
      final mosquesStr = prefs.getString('real_mosques');
      if (mosquesStr != null) {
        final List list = jsonDecode(mosquesStr);
        mosques.clear();
        for (var item in list) {
          mosques.add(Mosque.fromJson(item));
        }
      }

      // Load Real Sheikhs
      final sheikhsStr = prefs.getString('real_sheikhs');
      if (sheikhsStr != null) {
        final List list = jsonDecode(sheikhsStr);
        sheikhs.clear();
        for (var item in list) {
          sheikhs.add(Sheikh.fromJson(item));
        }
      }

      // Load Real Halaqat
      final halaqatStr = prefs.getString('real_halaqat');
      if (halaqatStr != null) {
        final List list = jsonDecode(halaqatStr);
        halaqat.clear();
        for (var item in list) {
          halaqat.add(Halaqa.fromJson(item));
        }
      }

      // Load Real Students
      final studentsStr = prefs.getString('real_students');
      if (studentsStr != null) {
        final List list = jsonDecode(studentsStr);
        students.clear();
        for (var item in list) {
          students.add(Student.fromJson(item));
        }
      }

      // Load Real Community Events
      final eventsStr = prefs.getString('real_events');
      if (eventsStr != null) {
        final List list = jsonDecode(eventsStr);
        communityEvents.clear();
        for (var item in list) {
          communityEvents.add(CommunityEvent.fromJson(item));
        }
      }

      // Load Real Points Logs
      final pointsStr = prefs.getString('real_points_logs');
      if (pointsStr != null) {
        final List list = jsonDecode(pointsStr);
        pointsLogs.clear();
        for (var item in list) {
          pointsLogs.add(PointsLog.fromJson(item));
        }
      }

      // Load Real Competitions
      final compsStr = prefs.getString('real_competitions');
      if (compsStr != null) {
        final List list = jsonDecode(compsStr);
        competitions.clear();
        for (var item in list) {
          competitions.add(Competition.fromJson(item));
        }
      }

      // Load Memorization Records
      final memStr = prefs.getString('real_memorization_records');
      if (memStr != null) {
        final List list = jsonDecode(memStr);
        memorizationRecords.clear();
        for (var item in list) {
          memorizationRecords.add(MemorizationRecord.fromJson(item));
        }
      }

      // Load Attendance Records
      final attStr = prefs.getString('real_attendance_records');
      if (attStr != null) {
        final List list = jsonDecode(attStr);
        attendanceRecords.clear();
        for (var item in list) {
          attendanceRecords.add(AttendanceRecord.fromJson(item));
        }
      }

      // Load Messages
      final msgStr = prefs.getString('real_messages');
      if (msgStr != null) {
        final List list = jsonDecode(msgStr);
        messages.clear();
        for (var item in list) {
          messages.add(AppMessage.fromJson(item));
        }
      }

      // Load Rewards
      final rewStr = prefs.getString('real_rewards');
      if (rewStr != null) {
        final List list = jsonDecode(rewStr);
        rewards.clear();
        for (var item in list) {
          rewards.add(Reward.fromJson(item));
        }
      }

      // Load Redemptions
      final redStr = prefs.getString('real_redemptions');
      if (redStr != null) {
        final List list = jsonDecode(redStr);
        redemptions.clear();
        for (var item in list) {
          redemptions.add(RewardRedemption.fromJson(item));
        }
      }

      // Load Intensive Courses
      final crsStr = prefs.getString('real_intensive_courses');
      if (crsStr != null) {
        final List list = jsonDecode(crsStr);
        intensiveCourses.clear();
        for (var item in list) {
          intensiveCourses.add(IntensiveCourse.fromJson(item));
        }
      }

      // Load Trips
      final tripsStr = prefs.getString('real_trips');
      if (tripsStr != null) {
        final List list = jsonDecode(tripsStr);
        trips.clear();
        for (var item in list) {
          trips.add(Trip.fromJson(item));
        }
      }

      // Load Recitation Tracks
      final tracksStr = prefs.getString('real_recitation_tracks');
      if (tracksStr != null) {
        final List list = jsonDecode(tracksStr);
        recitationTracks.clear();
        for (var item in list) {
          recitationTracks.add(RecitationTrack.fromJson(item));
        }
      }

      // Load Registration Tokens
      final tokensStr = prefs.getStringList('registration_tokens');
      if (tokensStr != null) {
        registrationTokens.clear();
        registrationTokens.addAll(tokensStr);
      }

      // Load Token Usage History
      final historyStr = prefs.getString('token_usage_history');
      if (historyStr != null) {
        final List list = jsonDecode(historyStr);
        tokenUsageHistory.clear();
        for (var item in list) {
          tokenUsageHistory.add(Map<String, dynamic>.from(item));
        }
      }

      // Load Subject Recitation Records
      final sRecStr = prefs.getString('real_subject_recitation_records');
      if (sRecStr != null) {
        final List list = jsonDecode(sRecStr);
        subjectRecitationRecords.clear();
        for (var item in list) {
          subjectRecitationRecords.add(SubjectRecitationRecord.fromJson(item));
        }
      }

      // Load Real Event Questions
      final eqStr = prefs.getString('real_event_questions');
      if (eqStr != null) {
        final List list = jsonDecode(eqStr);
        eventQuestions.clear();
        for (var item in list) {
          eventQuestions.add(EventQuestion.fromJson(item));
        }
      }
    } catch (_) {}
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

  /// Persists all in-memory collections and session state to SharedPreferences
  Future<void> saveToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'saved_sessions',
        jsonEncode(savedSessions.map((s) => s.toJson()).toList()),
      );
      if (currentSession != null) {
        await prefs.setString('current_session_code', currentSession!.code);
      } else {
        await prefs.remove('current_session_code');
      }
      await prefs.setBool('super_admin_authenticated', isSuperAdminAuthenticated);

      await prefs.setString(
        'real_mosques',
        jsonEncode(mosques.map((m) => m.toJson()).toList()),
      );
      await prefs.setString(
        'real_sheikhs',
        jsonEncode(sheikhs.map((s) => s.toJson()).toList()),
      );
      await prefs.setString(
        'real_halaqat',
        jsonEncode(halaqat.map((h) => h.toJson()).toList()),
      );
      await prefs.setString(
        'real_students',
        jsonEncode(students.map((s) => s.toJson()).toList()),
      );
      await prefs.setString(
        'real_events',
        jsonEncode(communityEvents.map((e) => e.toJson()).toList()),
      );
      await prefs.setString(
        'real_points_logs',
        jsonEncode(pointsLogs.map((p) => p.toJson()).toList()),
      );
      await prefs.setString(
        'real_competitions',
        jsonEncode(competitions.map((c) => c.toJson()).toList()),
      );
      await prefs.setString(
        'real_memorization_records',
        jsonEncode(memorizationRecords.map((m) => m.toJson()).toList()),
      );
      await prefs.setString(
        'real_attendance_records',
        jsonEncode(attendanceRecords.map((a) => a.toJson()).toList()),
      );
      await prefs.setString(
        'real_messages',
        jsonEncode(messages.map((m) => m.toJson()).toList()),
      );
      await prefs.setString(
        'real_rewards',
        jsonEncode(rewards.map((r) => r.toJson()).toList()),
      );
      await prefs.setString(
        'real_redemptions',
        jsonEncode(redemptions.map((r) => r.toJson()).toList()),
      );
      await prefs.setString(
        'real_intensive_courses',
        jsonEncode(intensiveCourses.map((c) => c.toJson()).toList()),
      );
      // Legacy key from the pre-isolation "unlock women section" flow; the
      // women's branch is now a separate mosque, so nothing is ever unlocked.
      await prefs.remove('unlocked_women_mosques');
      await prefs.setStringList(
        'registration_tokens',
        registrationTokens,
      );
      await prefs.setString(
        'token_usage_history',
        jsonEncode(tokenUsageHistory),
      );
      await prefs.setString(
        'real_trips',
        jsonEncode(trips.map((t) => t.toJson()).toList()),
      );
      await prefs.setString(
        'real_recitation_tracks',
        jsonEncode(recitationTracks.map((t) => t.toJson()).toList()),
      );
      await prefs.setString(
        'real_subject_recitation_records',
        jsonEncode(subjectRecitationRecords.map((r) => r.toJson()).toList()),
      );
      await prefs.setString(
        'real_event_questions',
        jsonEncode(eventQuestions.map((q) => q.toJson()).toList()),
      );
    } catch (_) {}
  }
}
