import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/models.dart';
import '../../../presentation/widgets/widgets.dart';
import '../../../services/data_service.dart';

class StudentTripsTab extends StatelessWidget {
  final Student student;
  final bool isDark;

  const StudentTripsTab({
    super.key,
    required this.student,
    this.isDark = false,
  });

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataService>();
    final myTrips = data.getTrips(studentId: student.id);
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
            runSpacing: 6,
            children: [
              Text(
                'الرحلات والأنشطة المدعو إليها (${myTrips.length})',
                style: AppTypography.verveHeaderTitle(context),
              ),
              UnifiedBadge(
                label: '${myTrips.length} رحلة',
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
            'تفاصيل الخرجات الترفيهية والتثقيفية، المواعيد، والمتطلبات الواجب إحضارها.',
            style: AppTypography.verveSubtitle(context),
          ),
        ),
        const SizedBox(height: 12),

        // Verve Minimalist List
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => context.read<DataService>().syncWithSupabase(),
            child: myTrips.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                      Center(
                        child: Text(
                          'لا توجد رحلات مجدولة حالياً',
                          style: AppTypography.verveSubtitle(context),
                        ),
                      ),
                    ],
                  )
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: myTrips.length,
                    separatorBuilder: (_, __) => Divider(height: 1, thickness: 0.8, color: dividerColor),
                    itemBuilder: (context, idx) {
              final trip = myTrips[idx];
              final serialNumber = (idx + 1).toString().padLeft(2, '0');
              final tripDateStr = DateFormat('yyyy/MM/dd').format(trip.tripDate);
              final deadlineStr = DateFormat('yyyy/MM/dd').format(trip.registrationDeadline);

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isMobile = constraints.maxWidth < 600;

                    final badgesColumn = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'التجمع: ${trip.meetingTime}',
                          style: AppTypography.bodyRegular(context),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            UnifiedBadge(
                              label: trip.isUpcoming ? 'رحلة قادمة 🚀' : 'مكتملة',
                              backgroundColor: trip.isUpcoming
                                  ? AppColors.terracottaPrimary.withValues(alpha: 0.1)
                                  : Colors.grey.withValues(alpha: 0.15),
                              textColor: trip.isUpcoming ? AppColors.terracottaPrimary : Colors.grey,
                            ),
                            UnifiedBadge(
                              label: 'آخر موعد: $deadlineStr',
                              backgroundColor: AppColors.gold.withValues(alpha: 0.15),
                              textColor: AppColors.goldDark,
                            ),
                            if (trip.requiredItems.isNotEmpty)
                              UnifiedBadge(
                                label: '🎒 ${trip.requiredItems}',
                                backgroundColor: isDarkTheme ? Colors.white10 : const Color(0xFFF1F5F9),
                                textColor: isDarkTheme ? Colors.white70 : AppColors.obsidianEspresso,
                              ),
                          ],
                        ),
                      ],
                    );

                    if (isMobile) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 32,
                                child: Text(
                                  serialNumber,
                                  style: AppTypography.verveNumber(context),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      trip.title,
                                      style: AppTypography.verveTitle(context),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'الوجهة: ${trip.destination} • الموعد: $tripDateStr',
                                      style: AppTypography.verveSubtitle(context),
                                    ),
                                    if (trip.leaderName != null && trip.leaderName!.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        'المشرف: ${trip.leaderName}${trip.leaderPhone != null ? " (${trip.leaderPhone})" : ""}',
                                        style: AppTypography.bodyRegular(context, fontSize: 12),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.only(right: 38),
                            child: badgesColumn,
                          ),
                        ],
                      );
                    }

                    return Row(
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

                        // Trip Title, Destination & Leader
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                trip.title,
                                style: AppTypography.verveTitle(context),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'الوجهة: ${trip.destination} • الموعد: $tripDateStr',
                                style: AppTypography.verveSubtitle(context),
                              ),
                              if (trip.leaderName != null && trip.leaderName!.isNotEmpty) ...[
                                const SizedBox(height: 3),
                                Text(
                                  'المشرف: ${trip.leaderName}${trip.leaderPhone != null ? " (${trip.leaderPhone})" : ""}',
                                  style: AppTypography.bodyRegular(context, fontSize: 12),
                                ),
                              ],
                            ],
                          ),
                        ),

                        // Badges & Logistics
                        Expanded(
                          flex: 4,
                          child: badgesColumn,
                        ),
                      ],
                    );
                  },
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