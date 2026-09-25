import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../models/models.dart';
import '../services/data_service.dart';
import '../widgets/code_scanner_dialog.dart';
import 'student/widgets/student_header_banner.dart';
import 'student/widgets/student_locked_view.dart';
import 'student/widgets/student_multi_profile_bar.dart';
import 'student/tabs/student_progress_tab.dart';
import 'student/tabs/student_attendance_tab.dart';
import 'student/tabs/student_trips_tab.dart';
import 'student/tabs/student_rewards_tab.dart';
import 'student/tabs/student_points_tab.dart';
import 'student/tabs/student_contact_tab.dart';
import 'student/tabs/student_rankings_tab.dart';

class StudentScreen extends StatefulWidget {
  final ActiveSession? session;

  const StudentScreen({super.key, this.session});

  @override
  State<StudentScreen> createState() => _StudentScreenState();
}

class _StudentScreenState extends State<StudentScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _openAddStudentDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => CodeScannerDialog(
        targetRole: 'student',
        onSessionUnlocked: (newSession) {
          if (mounted) {
            setState(() {});
          }
        },
      ),
    );
  }

  void _handleUnlinkStudent(BuildContext context, ActiveSession session, DataService data) {
    final studentId = session.studentId ?? session.code;
    data.removeStudentSession(studentId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تم إلغاء ربط ملف الطالب (${session.name}) بنجاح'),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataService>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final studentSessions = data.getStudentSessions();
    final active = data.getActiveStudentSession() ??
        data.getSessionForRole('student') ??
        widget.session ??
        data.currentSession;

    final isStudentSession = active != null && active.role == 'student';
    Student? currentStudent;

    if (isStudentSession && active.studentId != null) {
      currentStudent = data.getStudents().where((s) => s.id == active.studentId).firstOrNull;
    }
    if (isStudentSession && currentStudent == null && active.code.isNotEmpty) {
      currentStudent = data.getStudents().where((s) => s.code == active.code).firstOrNull;
    }

    // Fallback student if record is not yet in local cache
    if (isStudentSession && currentStudent == null && active.code.isNotEmpty) {
      currentStudent = Student(
        id: active.studentId ?? 'std-${active.code}',
        mosqueId: active.mosqueId ?? '',
        halaqaId: active.halaqaId ?? '',
        sheikhId: active.sheikhId,
        fullName: active.name,
        gender: active.gender ?? 'male',
        phone: '',
        code: active.code,
      );
    }

    // If locked or no student session
    if (!isStudentSession || currentStudent == null || studentSessions.isEmpty) {
      return StudentLockedView(
        isDark: isDark,
        onSessionUnlocked: () => setState(() {}),
      );
    }

    // Lookup Mosque, Halaqa & Sheikh
    final mosque = data.getMosques().firstWhere(
          (m) => m.id == currentStudent!.mosqueId,
      orElse: () => Mosque(id: '', name: 'المسجد', city: 'دمشق', gender: currentStudent!.gender, accessCode: ''),
    );

    final halaqat = data.getHalaqat(mosqueId: currentStudent.mosqueId);
    final currentHalaqa = halaqat.firstWhere(
          (h) => h.id == currentStudent!.halaqaId,
      orElse: () => Halaqa(id: '', mosqueId: currentStudent!.mosqueId, name: 'الحلقة القرآنية'),
    );

    final sheikhs = data.getSheikhs(mosqueId: currentStudent.mosqueId);
    final currentSheikh = sheikhs.firstWhere(
          (s) => s.id == currentStudent!.sheikhId || s.id == currentHalaqa.sheikhId,
      orElse: () => Sheikh(id: '', mosqueId: currentStudent!.mosqueId, fullName: 'فضيلة الشيخ المشرف', code: ''),
    );

    final logs = data.getStudentPointsLog(currentStudent.id);

    return RefreshIndicator(
      onRefresh: () => data.syncWithSupabase(),
      child: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Column(
                  children: [
                    StudentMultiProfileBar(
                      studentSessions: studentSessions,
                      activeSession: active,
                      students: data.getStudents(),
                      mosques: data.getMosques(),
                      halaqat: data.getHalaqat(),
                      isDark: isDark,
                      onSelectStudent: (id) => data.setActiveStudent(id),
                      onAddStudent: () => _openAddStudentDialog(context),
                      onUnlinkStudent: (sess) => _handleUnlinkStudent(context, sess, data),
                    ),
                    StudentHeaderBanner(
                      student: currentStudent!,
                      mosque: mosque,
                      halaqa: currentHalaqa,
                      sheikh: currentSheikh,
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  labelColor: Theme.of(context).colorScheme.primary,
                  unselectedLabelColor: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  indicatorColor: Theme.of(context).colorScheme.primary,
                  indicatorWeight: 2.5,
                  indicatorSize: TabBarIndicatorSize.label,
                  labelStyle: AppTypography.font(fontWeight: FontWeight.bold, fontSize: 15),
                  unselectedLabelStyle: AppTypography.font(fontWeight: FontWeight.w600, fontSize: 15),
                  tabs: const [
                    Tab(icon: Icon(Icons.menu_book), text: 'تقدم حفظ القرآن والمناهج'),
                    Tab(icon: Icon(Icons.calendar_month_outlined), text: 'سجل الحضور والالتزام'),
                    Tab(icon: Icon(Icons.directions_bus_rounded), text: 'رحلاتي وأنشطتي'),
                    Tab(icon: Icon(Icons.card_giftcard), text: 'متجر الجوائز'),
                    Tab(icon: Icon(Icons.stars), text: 'سجل النقاط '),
                    Tab(icon: Icon(Icons.mark_email_unread_outlined), text: 'تواصل مع الشيخ'),
                    Tab(icon: Icon(Icons.leaderboard), text: 'ترتيب الطالب'),
                  ],
                ),
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            StudentProgressTab(student: currentStudent, logs: logs, isDark: isDark),
            StudentAttendanceTab(student: currentStudent, isDark: isDark),
            StudentTripsTab(student: currentStudent, isDark: isDark),
            StudentRewardsTab(student: currentStudent, isDark: isDark),
            StudentPointsTab(logs: logs, isDark: isDark),
            StudentContactTab(
              student: currentStudent,
              sheikh: currentSheikh,
              halaqa: currentHalaqa,
              isDark: isDark,
            ),
            StudentRankingsTab(student: currentStudent, isDark: isDark),
          ],
        ),
      ),
    );
  }
}