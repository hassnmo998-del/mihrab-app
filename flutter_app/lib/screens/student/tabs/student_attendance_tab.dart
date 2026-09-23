import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/models.dart';
import '../../../services/data_service.dart';
import '../../../presentation/widgets/widgets.dart';

class StudentAttendanceTab extends StatelessWidget {
  final Student student;
  final bool isDark;

  const StudentAttendanceTab({
    super.key,
    required this.student,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataService>();
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    final dividerColor = isDarkTheme ? Colors.white12 : Colors.black12;

    final summary = data.getStudentAttendanceSummary(student.id);
    final rate = summary['attendanceRate'] as String;
    final total = summary['total'] as int;
    final present = summary['present'] as int;
    final late = summary['late'] as int;
    final absent = summary['absent'] as int;
    final records = summary['records'] as List<AttendanceRecord>;

    return RefreshIndicator(
      onRefresh: () => data.syncWithSupabase(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                Text(
                  'سجل الالتزام والحضور بالحلقة',
                  style: AppTypography.verveHeaderTitle(context),
                ),
                UnifiedBadge(
                  label: '$rate% نسبة الالتزام',
                  backgroundColor: AppColors.terracottaPrimary.withValues(alpha: 0.1),
                  textColor: AppColors.terracottaPrimary,
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'متابعة دورية وتفصيلية لحضور الطالب في كافة جلسات التحفيظ الرسمية والإضافية.',
              style: AppTypography.verveSubtitle(context),
            ),
          ),
          const SizedBox(height: 16),

          // Verve Open Metrics Row
          Divider(height: 1, thickness: 0.8, color: dividerColor),
          IntrinsicHeight(
            child: Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    child: Column(
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '$present',
                            style: AppTypography.verveNumber(context).copyWith(
                              fontSize: 30,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'حاضر ✅',
                          style: AppTypography.verveSubtitle(context),
                        ),
                      ],
                    ),
                  ),
                ),
                VerticalDivider(width: 1, thickness: 0.8, color: dividerColor),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    child: Column(
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '$late',
                            style: AppTypography.verveNumber(context).copyWith(
                              fontSize: 30,
                              color: AppColors.goldDark,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'متأخر ⏳',
                          style: AppTypography.verveSubtitle(context),
                        ),
                      ],
                    ),
                  ),
                ),
                VerticalDivider(width: 1, thickness: 0.8, color: dividerColor),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    child: Column(
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '$absent',
                            style: AppTypography.verveNumber(context).copyWith(
                              fontSize: 30,
                              color: Colors.redAccent,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'غائب ❌',
                          style: AppTypography.verveSubtitle(context),
                        ),
                      ],
                    ),
                  ),
                ),
                VerticalDivider(width: 1, thickness: 0.8, color: dividerColor),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    child: Column(
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '$total',
                            style: AppTypography.verveNumber(context).copyWith(
                              fontSize: 30,
                              color: isDarkTheme ? Colors.white70 : AppColors.obsidianEspresso,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'إجمالي الجلسات',
                          style: AppTypography.verveSubtitle(context),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, thickness: 0.8, color: dividerColor),
          const SizedBox(height: 24),

          // Detailed Attendance History Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'سجل الجلسات السابقة',
                  style: AppTypography.verveHeaderTitle(context),
                ),
                Text(
                  '$total جلسة مسجلة',
                  style: AppTypography.bodyRegular(context, fontSize: 12.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Open Attendance List
          if (records.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'لا يوجد سجل حضور مسجل للطالب حتى الآن',
                  style: AppTypography.verveSubtitle(context),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: records.length,
              separatorBuilder: (_, __) => Divider(height: 1, thickness: 0.8, color: dividerColor),
              itemBuilder: (ctx, idx) {
                final rec = records[idx];
                final serialNumber = (idx + 1).toString().padLeft(2, '0');

                String statusText = 'حاضر ✅';
                Color statusBg = Colors.green.withValues(alpha: 0.1);
                Color statusColor = Colors.green.shade800;

                if (rec.status == 'late') {
                  statusText = 'متأخر ⏳';
                  statusBg = AppColors.gold.withValues(alpha: 0.15);
                  statusColor = AppColors.goldDark;
                } else if (rec.status == 'absent') {
                  statusText = 'غائب ❌';
                  statusBg = Colors.redAccent.withValues(alpha: 0.1);
                  statusColor = Colors.redAccent;
                }

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // 01, 02 Serial Number
                      SizedBox(
                        width: 44,
                        child: Text(
                          serialNumber,
                          style: AppTypography.verveNumber(context),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Session Date & Notes
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'جلسة تاريخ: ${rec.sessionDate}',
                              style: AppTypography.verveTitle(context),
                            ),
                            if (rec.notes != null && rec.notes!.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                rec.notes!,
                                style: AppTypography.verveSubtitle(context),
                              ),
                            ],
                          ],
                        ),
                      ),

                      // Status Badge
                      UnifiedBadge(
                        label: statusText,
                        backgroundColor: statusBg,
                        textColor: statusColor,
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    ),
    );
  }
}