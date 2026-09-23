import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/models.dart';
import '../../../services/data_service.dart';
import '../../../presentation/widgets/widgets.dart';
import '../../../widgets/qr_dialogs.dart';

class StudentRewardsTab extends StatelessWidget {
  final Student student;
  final bool isDark;

  const StudentRewardsTab({
    super.key,
    required this.student,
    this.isDark = false,
  });

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataService>();
    // Student only sees active rewards
    final availableRewards = data.getRewards(mosqueId: student.mosqueId).where((r) => r.isActive).toList();
    final myRedemptions = data.getRedemptions(studentId: student.id);
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    final dividerColor = isDarkTheme ? Colors.white12 : Colors.black12;

    return RefreshIndicator(
      onRefresh: () => data.syncWithSupabase(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Points Balance Banner (Verve Sunset Twilight Gradient)
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: AppColors.sunsetTwilightGradient,
              borderRadius: BorderRadius.circular(20),
              boxShadow: AppShadows.heroBanner,
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.stars_rounded, color: Colors.white, size: 30),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'رصيد نقاطك المتاحة للاستبدال',
                        style: AppTypography.bodyRegular(
                          context,
                          color: const Color(0xFFF9EAE1),
                          fontSize: 12.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${student.totalPoints} نقطة',
                        style: AppTypography.titleBold(
                          context,
                          color: Colors.white,
                          fontSize: 26,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Available Rewards List Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                Text(
                  'الجوائز المتاحة للاستبدال',
                  style: AppTypography.verveHeaderTitle(context),
                ),
                Text(
                  '${availableRewards.length} جائزة معروضة',
                  style: AppTypography.bodyRegular(context, fontSize: 12.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'استعرض الجوائز المتاحة وتوجه للصراف المعتمد لمسح هويتك واستلام مكافأتك فوراً برصيد نقاطك.',
              style: AppTypography.verveSubtitle(context),
            ),
          ),
          const SizedBox(height: 14),

          // Rewards Verve List
          if (availableRewards.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'لم يقم مشرف المسجد بإضافة جوائز بعد',
                  style: AppTypography.verveSubtitle(context),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: availableRewards.length,
              separatorBuilder: (_, __) => Divider(height: 1, thickness: 0.8, color: dividerColor),
              itemBuilder: (context, index) {
                final reward = availableRewards[index];
                final canAfford = student.totalPoints >= reward.pointsCost;
                final studentRedemptions = myRedemptions.where((r) => r.rewardId == reward.id).toList();
                final redeemedTimes = studentRedemptions.length;
                final maxAffordable = reward.pointsCost > 0 ? (student.totalPoints ~/ reward.pointsCost) : 1;
                final serialNumber = (index + 1).toString().padLeft(2, '0');

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isMobile = constraints.maxWidth < 500;

                      final claimBtn = ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: canAfford ? AppColors.terracottaPrimary : (isDarkTheme ? Colors.white10 : const Color(0xFFE2E8F0)),
                          foregroundColor: canAfford ? Colors.white : (isDarkTheme ? Colors.white38 : Colors.grey.shade600),
                          shape: const StadiumBorder(),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          elevation: 0,
                        ),
                        onPressed: canAfford
                            ? () {
                          showDialog(
                            context: context,
                            builder: (_) => StudentRedemptionQrDialog(student: student, reward: reward),
                          );
                        }
                            : null,
                        child: Text(
                          canAfford ? 'استبدال الجائزة' : 'النقاط لا تكفي',
                          style: AppTypography.buttonText(
                            color: canAfford ? Colors.white : (isDarkTheme ? Colors.white38 : Colors.grey.shade600),
                          ),
                        ),
                      );

                      final badgesWrap = Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          UnifiedBadge(
                            label: '${reward.pointsCost} نقطة 🪙',
                            backgroundColor: AppColors.gold.withValues(alpha: 0.15),
                            textColor: AppColors.goldDark,
                          ),
                          if (canAfford && maxAffordable > 1)
                            UnifiedBadge(
                              label: 'متاح صرف حتى $maxAffordable مرات',
                              backgroundColor: AppColors.terracottaPrimary.withValues(alpha: 0.1),
                              textColor: AppColors.terracottaPrimary,
                            ),
                          if (redeemedTimes > 0)
                            UnifiedBadge(
                              label: 'صُرفت سابقاً $redeemedTimes مرة',
                              backgroundColor: isDarkTheme ? Colors.white10 : const Color(0xFFF1F5F9),
                              textColor: isDarkTheme ? Colors.white70 : AppColors.obsidianEspresso,
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
                                      Text(reward.title, style: AppTypography.verveTitle(context)),
                                      if (reward.description != null && reward.description!.isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(reward.description!, style: AppTypography.verveSubtitle(context)),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Padding(
                              padding: const EdgeInsets.only(right: 38),
                              child: badgesWrap,
                            ),
                            const SizedBox(height: 10),
                            Padding(
                              padding: const EdgeInsets.only(right: 38),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: claimBtn,
                              ),
                            ),
                          ],
                        );
                      }

                      return Row(
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

                          // Reward Details
                          Expanded(
                            flex: 4,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(reward.title, style: AppTypography.verveTitle(context)),
                                if (reward.description != null && reward.description!.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(reward.description!, style: AppTypography.verveSubtitle(context)),
                                ],
                                const SizedBox(height: 6),
                                badgesWrap,
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Claim Action Button
                          claimBtn,
                        ],
                      );
                    },
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