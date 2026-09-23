import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../models/models.dart';
import '../services/data_service.dart';
import 'admin/widgets/admin_header_banner.dart';
import 'admin/widgets/admin_locked_view.dart';
import 'admin/tabs/admin_sheikhs_tab.dart';
import 'admin/tabs/admin_halaqat_tab.dart';
import 'admin/tabs/admin_students_tab.dart';
import 'admin/tabs/admin_messages_tab.dart';
import 'admin/tabs/admin_courses_tab.dart';
import 'admin/tabs/admin_trips_tab.dart';
import 'admin/tabs/admin_tracks_tab.dart';
import 'admin/tabs/admin_rewards_tab.dart';
import 'admin/tabs/admin_overview_tab.dart';
import 'admin/tabs/admin_events_tab.dart';
import 'admin/tabs/admin_design_studio_tab.dart';

class MosqueAdminScreen extends StatefulWidget {
  final ActiveSession? session;

  const MosqueAdminScreen({super.key, this.session});

  @override
  State<MosqueAdminScreen> createState() => _MosqueAdminScreenState();
}

class _MosqueAdminScreenState extends State<MosqueAdminScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 11, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataService>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final session = data.getSessionForRole('mosque_admin') ?? widget.session ?? data.currentSession;

    final isUnlocked = session != null && session.role == 'mosque_admin';
    final mosqueId = session?.mosqueId ?? '';

    // Mosque lookup
    final mosque = data.getMosques().where((m) => m.id == mosqueId).firstOrNull;

    if (!isUnlocked || mosque == null || mosque.accessCode.isEmpty) {
      return AdminLockedView(
        isDark: isDark,
        onSessionUnlocked: () => setState(() {}),
      );
    }

    final sheikhs = data.getSheikhs(mosqueId: mosque.id);
    final halaqat = data.getHalaqat(mosqueId: mosque.id);
    final students = data.getStudents(mosqueId: mosque.id);
    final courses = data.getIntensiveCourses(mosqueId: mosque.id);
    final trips = data.getTrips(mosqueId: mosque.id);
    final tracks = data.getRecitationTracks(mosqueId: mosque.id, activeOnly: false);
    // استثناء الجوائز المعطلة من العدد الإجمالي في لوحة التحكم
    final rewards = data.getRewards(mosqueId: mosque.id).where((r) => r.isActive).toList();
    final events = data.getCommunityEvents(mosqueId: mosque.id).where((e) => e.eventStatus != 'archived').toList();

    return RefreshIndicator(
      onRefresh: () => data.syncWithSupabase(),
      child: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: AdminHeaderBanner(
                  mosque: mosque,
                  sheikhsCount: sheikhs.length,
                  halaqatCount: halaqat.length,
                  studentsCount: students.length,
                  coursesCount: courses.length,
                  tripsCount: trips.length,
                  tracksCount: tracks.length,
                  rewardsCount: rewards.length,
                  eventsCount: events.length,
                  isDark: isDark,
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
                    Tab(icon: Icon(Icons.people_outline), text: 'المشايخ والمعلمات'),
                    Tab(icon: Icon(Icons.menu_book), text: 'الحلقات القرآنية'),
                    Tab(icon: Icon(Icons.person_search), text: 'إدارة الطلاب'),
                    Tab(icon: Icon(Icons.mail_outline), text: 'رسائل وتواصل الطلاب'),
                    Tab(icon: Icon(Icons.workspace_premium), text: 'الدورات الاستثنائية'),
                    Tab(icon: Icon(Icons.directions_bus_rounded), text: 'رحلات وأنشطة المسجد'),
                    Tab(icon: Icon(Icons.auto_stories), text: 'المناهج والمتون'),
                    Tab(icon: Icon(Icons.card_giftcard), text: 'بنك الجوائز'),
                    Tab(icon: Icon(Icons.table_chart), text: 'لوحة المتابعة الشاملة'),
                    Tab(icon: Icon(Icons.event_available), text: 'الفعاليات ومجالس العلم'),
                    Tab(icon: Icon(Icons.palette_outlined), text: 'مركز التصاميم والطباعة'),
                  ],
                ),
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            AdminSheikhsTab(mosque: mosque, sheikhs: sheikhs, isDark: isDark),
            AdminHalaqatTab(mosque: mosque, halaqat: halaqat, sheikhs: sheikhs, isDark: isDark),
            AdminStudentsTab(mosque: mosque, students: students, halaqat: halaqat, isDark: isDark),
            AdminMessagesTab(mosque: mosque, isDark: isDark),
            AdminCoursesTab(mosque: mosque, sheikhs: sheikhs, halaqat: halaqat, allStudents: students, isDark: isDark),
            AdminTripsTab(mosque: mosque, halaqat: halaqat, students: students, sheikhs: sheikhs, isDark: isDark),
            AdminTracksTab(mosque: mosque, isDark: isDark),
            AdminRewardsTab(mosque: mosque, isDark: isDark),
            AdminOverviewTab(mosque: mosque, isDark: isDark),
            AdminEventsTab(mosque: mosque, isDark: isDark),
            AdminDesignStudioTab(mosque: mosque, isDark: isDark),
          ],
        ),
      ),
    );
  }
}