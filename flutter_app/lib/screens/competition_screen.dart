import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../services/data_service.dart';
import 'competition/tabs/competition_leaderboard_tab.dart';
import 'competition/tabs/competition_courses_tab.dart';

class CompetitionScreen extends StatefulWidget {
  final String? initialCompetitionId;

  const CompetitionScreen({super.key, this.initialCompetitionId});

  @override
  State<CompetitionScreen> createState() => _CompetitionScreenState();
}

class _CompetitionScreenState extends State<CompetitionScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataService>();
    final session = data.currentSession;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dividerColor = isDark ? Colors.white12 : Colors.black12;

    // الفرع يُستنتج من الجلسة فقط. سابقاً كان الزائر يستطيع اختيار "حلقات البنات"
    // بكبسة واحدة بلا أي كود فتُكشف أسماء الطالبات وحلقاتهن.
    final userGender = data.branchOfSession(session);

    return RefreshIndicator(
      onRefresh: () => data.syncWithSupabase(),
      child: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Hero Banner (Verve Sunset Twilight Gradient)
                    Container(
                      padding: EdgeInsets.all(
                        MediaQuery.of(context).size.width < 600 ? 14 : 24,
                      ),
                      decoration: BoxDecoration(
                        gradient: AppColors.sunsetTwilightGradient,
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: AppShadows.heroBanner,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(
                                AppRadius.rPill,
                              ),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.25),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.verified,
                                  color: AppColors.goldBright,
                                  size: 14,
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    'لوحة الشرف وتكريم الأبطال',
                                    style: AppTypography.font(
                                      color: AppColors.goldBright,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'لوحة الترتيب والدورات الاستثنائية',
                            style: AppTypography.font(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              height: 1.25,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'تكريم الطلاب المتميزين وأبطال الحلقات والمساجد، ومتابعة برامج الدورات القرآنية التخصصية والمكثفة بنظام تصفية ذكي.',
                            style: AppTypography.bodyRegular(
                              context,
                              color: const Color(0xFFF9EAE1),
                              fontSize: 13.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Divider(height: 1, thickness: 0.8, color: dividerColor),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: TabBar(
                  controller: _tabController,
                  labelColor: Theme.of(context).colorScheme.primary,
                  unselectedLabelColor: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                  indicatorColor: Theme.of(context).colorScheme.primary,
                  indicatorWeight: 2.5,
                  indicatorSize: TabBarIndicatorSize.label,
                  labelStyle: AppTypography.font(
                    fontWeight: FontWeight.bold,
                    fontSize: 15.5,
                  ),
                  unselectedLabelStyle: AppTypography.font(
                    fontWeight: FontWeight.w600,
                    fontSize: 15.5,
                  ),
                  tabs: const [
                    Tab(icon: Icon(Icons.leaderboard), text: 'لوحة الترتيب '),
                    Tab(
                      icon: Icon(Icons.workspace_premium),
                      text: 'الدورات الاستثنائية',
                    ),
                  ],
                ),
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            CompetitionLeaderboardTab(
              gender: userGender,
              isDark: isDark,
              initialCourseId: widget.initialCompetitionId,
            ),
            CompetitionCoursesTab(gender: userGender, isDark: isDark),
          ],
        ),
      ),
    );
  }
}
