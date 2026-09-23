import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/models.dart';
import '../../../services/data_service.dart';
import '../dialogs/admin_course_form_dialog.dart';
import '../../../presentation/widgets/widgets.dart';

class AdminCoursesTab extends StatelessWidget {
  final Mosque mosque;
  final List<Sheikh> sheikhs;
  final List<Halaqa> halaqat;
  final List<Student> allStudents;
  final bool isDark;

  const AdminCoursesTab({
    super.key,
    required this.mosque,
    required this.sheikhs,
    required this.halaqat,
    required this.allStudents,
    this.isDark = false,
  });

  void _confirmDeleteCourse(BuildContext context, DataService data, IntensiveCourse course) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('تأكيد حذف الدورة', style: AppTypography.dialogTitle(context)),
        content: Text(
          'هل أنت متأكد من حذف دورة "${course.name}"؟',
          style: AppTypography.verveSubtitle(context),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('إلغاء', style: AppTypography.buttonText(color: AppColors.terracottaPrimary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: const StadiumBorder(),
            ),
            onPressed: () {
              data.deleteIntensiveCourse(course.id);
              Navigator.pop(ctx);
            },
            child: Text('حذف', style: AppTypography.buttonText()),
          ),
        ],
      ),
    );
  }

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
    final courses = data.getIntensiveCourses(mosqueId: mosque.id);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dividerColor = isDark ? Colors.white12 : Colors.black12;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header Row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              Text(
                'الدورات القرآنية الاستثنائية (${courses.length})',
                style: AppTypography.verveHeaderTitle(context),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  AdminCourseFormDialog.show(
                    context: context,
                    mosque: mosque,
                    sheikhs: sheikhs,
                    halaqat: halaqat,
                    allStudents: allStudents,
                  );
                },
                icon: const Icon(Icons.add, size: 18),
                label: Text('إضافة دورة استثنائية', style: AppTypography.buttonText()),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.terracottaPrimary,
                  foregroundColor: Colors.white,
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),

        // Subtle Note in Verve Style
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text(
            'معسكرات ومراجعات مكثفة محددة بأيام وساعات وأهداف واضحة؛ مرتبطة بجدول زمني محدد للتسميع.',
            style: AppTypography.verveSubtitle(context),
          ),
        ),
        const SizedBox(height: 12),

        // Verve Minimalist List
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => context.read<DataService>().syncWithSupabase(),
            child: courses.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                      Center(
                        child: Text(
                          'لا توجد دورات استثنائية مسجلة حالياً بالمسجد',
                          style: AppTypography.verveSubtitle(context),
                        ),
                      ),
                    ],
                  )
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: courses.length,
                    separatorBuilder: (_, __) => Divider(height: 1, thickness: 0.8, color: dividerColor),
                    itemBuilder: (context, idx) {
              final c = courses[idx];
              final startStr = '${c.startDate.year}/${c.startDate.month}/${c.startDate.day}';
              final endStr = '${c.endDate.year}/${c.endDate.month}/${c.endDate.day}';
              final isCounts = c.countsTowardsQuranProgress;
              final daysStr = c.daysOfWeek.map((d) => _getDayName(d)).where((s) => s.isNotEmpty).join('، ');
              final serialNumber = (idx + 1).toString().padLeft(2, '0');

              return LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 600;

                  final serialWidget = SizedBox(
                    width: isNarrow ? 36 : 48,
                    child: Text(
                      serialNumber,
                      style: AppTypography.verveNumber(context),
                    ),
                  );

                  final titleWidget = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        c.name,
                        style: AppTypography.verveTitle(context),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'من $startStr إلى $endStr',
                        style: AppTypography.verveSubtitle(context),
                      ),
                    ],
                  );

                  final scheduleWidget = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'الجلسات: ${daysStr.isEmpty ? "كل الأيام" : daysStr} (${c.startTime ?? "16:00"} - ${c.endTime ?? "18:00"})',
                        style: AppTypography.bodyRegular(context),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          UnifiedBadge(
                            label: c.studentIds.isEmpty
                                ? 'جميع طلاب المسجد'
                                : '${c.studentIds.length} طالب مشارك',
                            backgroundColor: AppColors.terracottaPrimary.withValues(alpha: 0.1),
                            textColor: AppColors.terracottaPrimary,
                          ),
                          UnifiedBadge(
                            label: isCounts ? 'تُحتسب بالختمة الرسمية' : 'نقاط تنافسية إضافية',
                            backgroundColor: isCounts ? AppColors.gold.withValues(alpha: 0.15) : Colors.orange.withValues(alpha: 0.15),
                            textColor: isCounts ? AppColors.goldDark : Colors.orange,
                          ),
                        ],
                      ),
                    ],
                  );

                  final actionsWidget = Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'تعديل الدورة',
                        icon: Icon(Icons.edit_outlined, color: AppTheme.gold, size: 20),
                        onPressed: () => AdminCourseFormDialog.show(
                          context: context,
                          mosque: mosque,
                          course: c,
                          sheikhs: sheikhs,
                          halaqat: halaqat,
                          allStudents: allStudents,
                        ),
                      ),
                      IconButton(
                        tooltip: 'حذف الدورة',
                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                        onPressed: () => _confirmDeleteCourse(context, data, c),
                      ),
                    ],
                  );

                  if (isNarrow) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              serialWidget,
                              const SizedBox(width: 8),
                              Expanded(child: titleWidget),
                              actionsWidget,
                            ],
                          ),
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsetsDirectional.only(start: 44),
                            child: scheduleWidget,
                          ),
                        ],
                      ),
                    );
                  }

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        serialWidget,
                        const SizedBox(width: 8),
                        Expanded(flex: 3, child: titleWidget),
                        Expanded(flex: 4, child: scheduleWidget),
                        actionsWidget,
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    ],
  );
}
}