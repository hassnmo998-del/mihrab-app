import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/models.dart';
import '../../../presentation/widgets/widgets.dart';
import '../../../services/data_service.dart';

class StudentPointsTab extends StatelessWidget {
  final List<PointsLog> logs;
  final bool isDark;

  const StudentPointsTab({
    super.key,
    required this.logs,
    this.isDark = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    final dividerColor = isDarkTheme ? Colors.white12 : Colors.black12;

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
              runSpacing: 4,
              children: [
                Text(
                  'سجل النقاط  (${logs.length})',
                  style: AppTypography.verveHeaderTitle(context),
                ),
                UnifiedBadge(
                  label: '${logs.length} حركة مسجلة',
                  backgroundColor: AppColors.terracottaPrimary.withValues(alpha: 0.1),
                  textColor: AppColors.terracottaPrimary,
                ),
              ],
            ),
          ),
        const SizedBox(height: 4),

        // Verve Minimal Note
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text(
            'سجل تفصيلي يوضح كل نقطة مكتسبة من جلسات التسميع، الحضور، والمشاركات التفاعلية.',
            style: AppTypography.verveSubtitle(context),
          ),
        ),
        const SizedBox(height: 12),

        // Verve Minimalist List
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => context.read<DataService>().syncWithSupabase(),
            child: logs.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                      Center(
                        child: Text(
                          'لا توجد نقاط مسجلة بعد في السجل',
                          style: AppTypography.verveSubtitle(context),
                        ),
                      ),
                    ],
                  )
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: logs.length,
                    separatorBuilder: (_, __) => Divider(height: 1, thickness: 0.8, color: dividerColor),
                    itemBuilder: (context, idx) {
              final log = logs[idx];
              final serialNumber = (idx + 1).toString().padLeft(2, '0');
              final dateFormatted = DateFormat('yyyy/MM/dd - hh:mm a').format(log.createdAt);
              final isDeduction = log.points < 0;
              final pointsLabel = isDeduction
                  ? '- ${log.points.abs()} نقطة'
                  : '+${log.points} نقطة 🪙';

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
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

                    // Log Reason & Date
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            log.reason,
                            style: AppTypography.verveTitle(context),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            dateFormatted,
                            style: AppTypography.verveSubtitle(context),
                          ),
                        ],
                      ),
                    ),

                    // Points Badge
                    UnifiedBadge(
                      label: pointsLabel,
                      backgroundColor: isDeduction
                          ? AppColors.attendanceAbsent.withValues(alpha: 0.12)
                          : AppColors.gold.withValues(alpha: 0.15),
                      textColor:
                          isDeduction ? AppColors.attendanceAbsent : AppColors.goldDark,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    ],
  );
}
}