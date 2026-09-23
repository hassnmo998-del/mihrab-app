import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/models.dart';
import '../../../presentation/widgets/widgets.dart';
import '../../../services/data_service.dart';

class StudentRankingsTab extends StatelessWidget {
  final Student student;
  final bool isDark;

  const StudentRankingsTab({
    super.key,
    required this.student,
    this.isDark = false,
  });

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataService>();
    // فرع المسجد هو المرجع: طالبة سُجّلت سابقاً بقيمة 'male' كانت سترى ترتيب الرجال
    final rankings = data.getRankings(
      mosqueId: student.mosqueId,
      gender: data.branchOfMosque(student.mosqueId),
    );
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    final dividerColor = isDarkTheme ? Colors.white12 : Colors.black12;

    // Find current student's rank
    final myRankIndex = rankings.indexWhere((item) {
      final st = item['student'] as Student;
      return st.id == student.id;
    });
    final myRankNumber = myRankIndex != -1 ? (myRankIndex + 1) : null;

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
                'لوحة الشرف وترتيب الطلاب (${rankings.length})',
                style: AppTypography.verveHeaderTitle(context),
              ),
              if (myRankNumber != null)
                UnifiedBadge(
                  label: 'ترتيبك الحالي: المركز #$myRankNumber 🌟',
                  backgroundColor: AppColors.gold.withValues(alpha: 0.15),
                  textColor: AppColors.goldDark,
                ),
            ],
          ),
        ),
        const SizedBox(height: 4),

        // Verve Minimal Note
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text(
            'سلم الترتيب التنافسي المعتمد في المسجد وفق مجموع نقاط التسميع والالتزام.',
            style: AppTypography.verveSubtitle(context),
          ),
        ),
        const SizedBox(height: 12),

        // Verve Open Rankings List
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => context.read<DataService>().syncWithSupabase(),
            child: rankings.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.2,
                      ),
                      Center(
                        child: Text(
                          'لا توجد تصنيفات مسجلة حالياً',
                          style: AppTypography.verveSubtitle(context),
                        ),
                      ),
                    ],
                  )
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: rankings.length,
                    separatorBuilder: (_, __) =>
                        Divider(height: 1, thickness: 0.8, color: dividerColor),
                    itemBuilder: (context, idx) {
                      final item = rankings[idx];
                      final st = item['student'] as Student;
                      final score = item['score'] as int;
                      final rank = item['rank'] as int;
                      final isCurrent = st.id == student.id;

                      // Rank Color Accents
                      Color? rankColor;
                      if (rank == 1) {
                        rankColor = const Color(0xFFD97706); // Gold
                      } else if (rank == 2) {
                        rankColor = const Color(0xFF64748B); // Silver
                      } else if (rank == 3) {
                        rankColor = const Color(0xFFB45309); // Bronze
                      }

                      final rankStr = rank.toString().padLeft(2, '0');

                      return Container(
                        decoration: BoxDecoration(
                          color: isCurrent
                              ? AppColors.terracottaPrimary.withValues(
                                  alpha: isDarkTheme ? 0.12 : 0.06,
                                )
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(
                          vertical: 16,
                          horizontal: 12,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Rank Number (01, 02, 03, ...)
                            SizedBox(
                              width: 48,
                              child: Row(
                                children: [
                                  // الرقم + كأس المراكز الثلاثة قد يتجاوزان العرض الثابت
                                  // مع خطوط أعرض، فيجب أن ينضغط لا أن يفيض.
                                  Flexible(
                                    child: Text(
                                      rankStr,
                                      maxLines: 1,
                                      softWrap: false,
                                      overflow: TextOverflow.clip,
                                      style: AppTypography.verveNumber(context)
                                          .copyWith(
                                            color:
                                                rankColor ??
                                                (isCurrent
                                                    ? AppColors
                                                          .terracottaPrimary
                                                    : null),
                                            fontWeight: rank <= 3
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                          ),
                                    ),
                                  ),
                                  if (rank <= 3) ...[
                                    const SizedBox(width: 4),
                                    Icon(
                                      Icons.emoji_events_rounded,
                                      size: 14,
                                      color: rankColor,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),

                            // Student Name & Halaqa
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Wrap(
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    spacing: 6,
                                    runSpacing: 2,
                                    children: [
                                      Text(
                                        st.fullName,
                                        style: AppTypography.verveTitle(context)
                                            .copyWith(
                                              fontWeight: isCurrent
                                                  ? FontWeight.bold
                                                  : FontWeight.w600,
                                              color: isCurrent
                                                  ? AppColors.terracottaPrimary
                                                  : null,
                                            ),
                                      ),
                                      if (isCurrent)
                                        UnifiedBadge(
                                          label: 'أنت ✨',
                                          backgroundColor: AppColors
                                              .terracottaPrimary
                                              .withValues(alpha: 0.15),
                                          textColor:
                                              AppColors.terracottaPrimary,
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    '${item['mosqueName']} • ${item['halaqaName']}',
                                    style: AppTypography.verveSubtitle(context),
                                  ),
                                ],
                              ),
                            ),

                            // Points Badge
                            UnifiedBadge(
                              label: '$score نقطة 🪙',
                              backgroundColor: rank <= 3
                                  ? AppColors.gold.withValues(alpha: 0.15)
                                  : (isDarkTheme
                                        ? Colors.white10
                                        : const Color(0xFFF1F5F9)),
                              textColor: rank <= 3
                                  ? AppColors.goldDark
                                  : (isDarkTheme
                                        ? Colors.white70
                                        : AppColors.obsidianEspresso),
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
