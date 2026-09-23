import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../presentation/widgets/widgets.dart';
import '../../../services/data_service.dart';

class CompetitionCoursesTab extends StatefulWidget {
  final String gender;
  final bool isDark;

  const CompetitionCoursesTab({
    super.key,
    required this.gender,
    this.isDark = false,
  });

  @override
  State<CompetitionCoursesTab> createState() => _CompetitionCoursesTabState();
}

class _CompetitionCoursesTabState extends State<CompetitionCoursesTab> {
  String _courseSearchQuery = '';
  String _courseMosqueFilter = 'all';

  static String _getDayName(int day) {
    switch (day) {
      case 6:
        return 'السبت';
      case 7:
        return 'الأحد';
      case 1:
        return 'الإثنين';
      case 2:
        return 'الثلاثاء';
      case 3:
        return 'الأربعاء';
      case 4:
        return 'الخميس';
      case 5:
        return 'الجمعة';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataService>();
    final mosques = data.getMosques(gender: widget.gender);
    final branchMosqueIds = mosques.map((m) => m.id).toSet();
    // الدورات كانت تُعرض من الفرعين معاً لأن الفلتر كان على قائمة المساجد فقط
    var courses = data
        .getIntensiveCourses()
        .where((c) => branchMosqueIds.contains(c.mosqueId))
        .toList();
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    final dividerColor = isDarkTheme ? Colors.white12 : Colors.black12;

    if (_courseMosqueFilter != 'all') {
      courses = courses.where((c) => c.mosqueId == _courseMosqueFilter).toList();
    }

    if (_courseSearchQuery.isNotEmpty) {
      final q = _courseSearchQuery.toLowerCase();
      courses = courses
          .where((c) =>
      c.name.toLowerCase().contains(q) ||
          (c.description?.toLowerCase().contains(q) ?? false))
          .toList();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header & Count
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Text(
                'الدورات القرآنية الاستثنائية (${courses.length})',
                style: AppTypography.verveHeaderTitle(context),
              ),
              UnifiedBadge(
                label: '${courses.length} دورة مسجلة',
                backgroundColor: AppColors.terracottaPrimary.withValues(alpha: 0.1),
                textColor: AppColors.terracottaPrimary,
              ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            'برامج مكثفة ودورات نوعية لتسريع الحفظ والإتقان.',
            style: AppTypography.verveSubtitle(context),
          ),
        ),
        const SizedBox(height: 12),

        // Search & Mosque Filter Row (Verve Open Style)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'بحث باسم الدورة القرآنية أو محاورها...',
                    prefixIcon: Icon(Icons.search, size: 20),
                    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                  onChanged: (val) => setState(() => _courseSearchQuery = val.trim()),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  key: ValueKey('course_filter_$_courseMosqueFilter'),
                  initialValue: _courseMosqueFilter,
                  decoration: const InputDecoration(
                    labelText: 'المسجد',
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 'all',
                      child: Text('جميع المساجد', style: AppTypography.bodyRegular(context, fontSize: 13)),
                    ),
                    ...mosques.map((m) => DropdownMenuItem(
                      value: m.id,
                      child: Text(m.name, style: AppTypography.bodyRegular(context, fontSize: 13), overflow: TextOverflow.ellipsis),
                    )),
                  ],
                  onChanged: (val) => setState(() => _courseMosqueFilter = val ?? 'all'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Verve Open Courses List
        Expanded(
          child: courses.isEmpty
              ? Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                'لا توجد دورات استثنائية مطابقة للبحث حالياً',
                style: AppTypography.verveSubtitle(context),
              ),
            ),
          )
              : ListView.separated(
            itemCount: courses.length,
            separatorBuilder: (_, __) => Divider(height: 1, thickness: 0.8, color: dividerColor),
            itemBuilder: (context, idx) {
              final c = courses[idx];
              final mosque = data.getMosqueById(c.mosqueId);
              final startStr = '${c.startDate.year}/${c.startDate.month}/${c.startDate.day}';
              final endStr = '${c.endDate.year}/${c.endDate.month}/${c.endDate.day}';
              final isCounts = c.countsTowardsQuranProgress;
              final daysStr = c.daysOfWeek.map((d) => _getDayName(d)).where((s) => s.isNotEmpty).join('، ');
              final serialNumber = (idx + 1).toString().padLeft(2, '0');

              final now = DateTime.now();
              final isCurrent = !now.isBefore(c.startDate) && !now.isAfter(c.endDate.add(const Duration(days: 1)));
              final isUpcoming = now.isBefore(c.startDate);

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // 01, 02 Serial Number
                    SizedBox(
                      width: 48,
                      child: Text(
                        serialNumber,
                        style: AppTypography.verveNumber(context),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Course Title, Dates & Description
                    Expanded(
                      flex: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            c.name,
                            style: AppTypography.verveTitle(context),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${mosque?.name ?? "المسجد"} • من $startStr إلى $endStr',
                            style: AppTypography.verveSubtitle(context),
                          ),
                          if (c.description != null && c.description!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              c.description!,
                              style: AppTypography.bodyRegular(context, fontSize: 12.5),
                            ),
                          ],
                          const SizedBox(height: 6),
                          Text(
                            'أيام الجلسات: ${daysStr.isEmpty ? "كل الأيام" : daysStr} (${c.startTime ?? "16:00"} - ${c.endTime ?? "18:00"})',
                            style: AppTypography.titleBold(context, color: AppColors.terracottaPrimary, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Badges & Intelligence Window
                    Expanded(
                      flex: 3,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          UnifiedBadge(
                            label: isCurrent ? 'جارية حالياً 🟢' : (isUpcoming ? 'قريباً ⏳' : 'منتهية ⚪'),
                            backgroundColor: isCurrent
                                ? AppColors.terracottaPrimary.withValues(alpha: 0.1)
                                : (isUpcoming ? AppColors.gold.withValues(alpha: 0.15) : (isDarkTheme ? Colors.white10 : const Color(0xFFF1F5F9))),
                            textColor: isCurrent
                                ? AppColors.terracottaPrimary
                                : (isUpcoming ? AppColors.goldDark : (isDarkTheme ? Colors.white70 : AppColors.obsidianEspresso)),
                          ),
                          UnifiedBadge(
                            label: isCounts ? 'ضمن خطة الـ 30 جزء 📖' : 'نقاط تنافسية تشجيعية ⭐',
                            backgroundColor: isCounts
                                ? Colors.green.withValues(alpha: 0.12)
                                : AppColors.gold.withValues(alpha: 0.15),
                            textColor: isCounts ? Colors.green.shade800 : AppColors.goldDark,
                          ),
                          UnifiedBadge(
                            label: c.studentIds.isEmpty ? 'لعموم طلاب المسجد' : '${c.studentIds.length} طلاب مسجلين',
                            backgroundColor: isDarkTheme ? Colors.white10 : const Color(0xFFF1F5F9),
                            textColor: isDarkTheme ? Colors.white70 : AppColors.obsidianEspresso,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}