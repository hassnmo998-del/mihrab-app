import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../models/models.dart';
import '../services/data_service.dart';
import 'sheikh/widgets/sheikh_header_banner.dart';
import 'sheikh/widgets/sheikh_locked_view.dart';
import 'sheikh/tabs/sheikh_attendance_tab.dart';
import 'sheikh/tabs/sheikh_memorization_tab.dart';
import 'sheikh/tabs/sheikh_tracks_tab.dart';
import 'sheikh/tabs/sheikh_trips_tab.dart';
import 'sheikh/tabs/sheikh_overview_tab.dart';
import 'sheikh/tabs/sheikh_students_tab.dart';
import 'sheikh/tabs/sheikh_messages_tab.dart';
import 'sheikh/tabs/sheikh_events_tab.dart';

class SheikhScreen extends StatefulWidget {
  final ActiveSession? session;

  const SheikhScreen({super.key, this.session});

  @override
  State<SheikhScreen> createState() => _SheikhScreenState();
}

class _SheikhScreenState extends State<SheikhScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 8, vsync: this);
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
    final session = data.getSessionForRole('sheikh') ?? widget.session ?? data.currentSession;

    final isUnlocked = session != null && session.role == 'sheikh';
    final sheikhId = session?.sheikhId ?? '';

    // Sheikh lookup with strict validation - no dummy fallback
    final activeSheikh = data.getSheikhs().where(
      (s) => s.id == sheikhId || (session != null && s.code == session.code),
    ).firstOrNull;

    if (!isUnlocked || activeSheikh == null) {
      return SheikhLockedView(
        isDark: isDark,
        onSessionUnlocked: () => setState(() {}),
      );
    }
    final sheikh = activeSheikh;

    final sheikhs = data.getSheikhs(mosqueId: sheikh.mosqueId);
    final halaqat = data.getHalaqat(sheikhId: sheikh.id);
    final students = data.getStudents(sheikhId: sheikh.id);

    return RefreshIndicator(
      onRefresh: () => data.syncWithSupabase(),
      child: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: SheikhHeaderBanner(
                  sheikh: sheikh,
                  mosqueName: session.mosqueName ?? 'المسجد',
                  halaqatCount: halaqat.length,
                  studentsCount: students.length,
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
                    Tab(icon: Icon(Icons.check_circle_outline), text: 'رصد الحضور اليومي'),
                    Tab(icon: Icon(Icons.menu_book), text: 'رصد التسميع والقرآن'),
                    Tab(icon: Icon(Icons.auto_stories), text: 'المناهج والمتون'),
                    Tab(icon: Icon(Icons.directions_bus_rounded), text: 'رحلات وأنشطة الحلقة'),
                    Tab(icon: Icon(Icons.table_chart), text: 'لوحة المتابعة الشاملة'),
                    Tab(icon: Icon(Icons.event_available), text: 'إدارة دروسي العامة'),
                    Tab(icon: Icon(Icons.groups), text: 'طلاب الحلقة والـ QR'),
                    Tab(icon: Icon(Icons.mark_email_unread_outlined), text: 'رسائل وتواصل الأهل'),
                  ],
                ),
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            SheikhAttendanceTab(
              sheikh: sheikh,
              students: students,
              halaqat: halaqat,
              isDark: isDark,
            ),
            SheikhMemorizationTab(
              sheikh: sheikh,
              students: students,
              halaqat: halaqat,
              isDark: isDark,
            ),
            SheikhTracksTab(
              sheikh: sheikh,
              halaqat: halaqat,
              isDark: isDark,
              onReciteTrack: (trackId) {
                setState(() {
                  _tabController.index = 1;
                });
              },
            ),
            SheikhTripsTab(
              sheikh: sheikh,
              students: students,
              halaqat: halaqat,
              allSheikhs: sheikhs,
              isDark: isDark,
            ),
            SheikhOverviewTab(
              sheikh: sheikh,
              halaqat: halaqat,
              isDark: isDark,
            ),
            SheikhEventsTab(
              sheikh: sheikh,
              isDark: isDark,
            ),
            SheikhStudentsTab(
              sheikh: sheikh,
              students: students,
              halaqat: halaqat,
              isDark: isDark,
            ),
            SheikhMessagesTab(
              sheikh: sheikh,
              halaqat: halaqat,
              isDark: isDark,
            ),
          ],
        ),
      ),
    );
  }
}