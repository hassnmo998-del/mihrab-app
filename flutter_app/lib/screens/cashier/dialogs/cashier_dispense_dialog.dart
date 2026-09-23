import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/models.dart';
import '../../../services/data_service.dart';

class CashierDispenseDialog {
  static void showAlreadyDispensed(BuildContext context, RewardRedemption item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
            const SizedBox(width: 8),
            Text('قسيمة مصروفة مسبقاً', style: AppTypography.titleBold(ctx, fontSize: 18)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('تم صرف هذه الجائزة مسبقاً للطالب (${item.studentName}).', style: AppTypography.bodyRegular(ctx)),
              const SizedBox(height: 8),
              Text('الجائزة: ${item.rewardTitle}', style: AppTypography.font(fontWeight: FontWeight.bold, fontSize: 13.5)),
              Text(
                'تاريخ الصرف: ${item.dispensedAt != null ? item.dispensedAt.toString().split('.')[0] : "غير محدد"}',
                style: AppTypography.bodyRegular(ctx, fontSize: 13),
              ),
              if (item.cashierName != null)
                Text('الصراف: ${item.cashierName}', style: AppTypography.bodyRegular(ctx, fontSize: 13)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('حسناً', style: AppTypography.buttonText(color: Theme.of(ctx).colorScheme.primary)),
          ),
        ],
      ),
    );
  }

  static void showConfirmDispense({
    required BuildContext context,
    required DataService ds,
    required RewardRedemption item,
    required String voucherCode,
    required VoidCallback onSuccess,
  }) {
    final currentSession = ds.currentSession;
    final cashierName = currentSession?.name ?? 'صراف معتمد';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        actionsOverflowButtonSpacing: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.redeem_rounded, color: Theme.of(ctx).colorScheme.primary, size: 28),
            const SizedBox(width: 8),
            Expanded(child: Text('تأكيد صرف الجائزة', style: AppTypography.titleBold(ctx, fontSize: 18))),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow(ctx, 'اسم الطالب:', item.studentName, Icons.person_outline),
              _buildDetailRow(ctx, 'المسجد:', item.mosqueName, Icons.mosque_outlined),
              _buildDetailRow(ctx, 'الجائزة:', item.rewardTitle, Icons.card_giftcard),
              _buildDetailRow(
                ctx,
                'النقاط المطلوبة:',
                '${item.pointsSpent} نقطة',
                Icons.stars_rounded,
                color: Colors.amber.shade800,
              ),
              const Divider(height: 24),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Theme.of(ctx).colorScheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Theme.of(ctx).colorScheme.primary, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'سيتم خصم النقاط من رصيد الطالب فور تأكيد الصرف وتوثيق العملية في الأرشيف.',
                        style: AppTypography.bodyRegular(ctx, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('إلغاء', style: AppTypography.buttonText(color: Colors.grey)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.primary,
              foregroundColor: Colors.white,
              shape: const StadiumBorder(),
            ),
            icon: const Icon(Icons.check_circle_outline, size: 18),
            label: Text('تأكيد الصرف والتسليم', style: AppTypography.buttonText()),
            onPressed: () {
              Navigator.pop(ctx);
              final res = ds.dispenseReward(
                voucherCode: voucherCode,
                cashierName: cashierName,
              );

              if (res['success'] == true) {
                onSuccess();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        const Icon(Icons.check_circle, color: Colors.white),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text('تم تسليم ${item.rewardTitle} للطالب ${item.studentName} بنجاح!'),
                        ),
                      ],
                    ),
                    backgroundColor: Colors.green.shade700,
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(res['error'] ?? 'تعذر صرف الجائزة'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  static void showConfirmDirectSale({
    required BuildContext context,
    required DataService ds,
    required Student student,
    required Reward reward,
    required VoidCallback onSuccess,
  }) {
    final currentSession = ds.currentSession;
    final cashierName = currentSession?.name ?? 'صراف معتمد';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        actionsOverflowButtonSpacing: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.shopping_cart_checkout_rounded,
                color: Theme.of(ctx).colorScheme.primary, size: 28),
            const SizedBox(width: 8),
            Expanded(child: Text('تأكيد البيع المباشر', style: AppTypography.titleBold(ctx, fontSize: 18))),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow(ctx, 'الطالب المشتري:', student.fullName, Icons.person),
              _buildDetailRow(ctx, 'الجائزة المطلوبة:', reward.title, Icons.card_giftcard),
              _buildDetailRow(
                ctx,
                'سعر الجائزة:',
                '${reward.pointsCost} نقطة',
                Icons.stars_rounded,
                color: Colors.amber.shade800,
              ),
              _buildDetailRow(
                ctx,
                'رصيد الطالب الحالي:',
                '${student.totalPoints} نقطة',
                Icons.account_balance_wallet_outlined,
              ),
              const Divider(height: 24),
              Text(
                'سيتم خصم ${reward.pointsCost} نقطة من رصيد الطالب فوراً وتسليمه الجائزة.',
                style: AppTypography.bodyRegular(ctx, fontSize: 12),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('إلغاء', style: AppTypography.buttonText(color: Colors.grey)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.primary,
              foregroundColor: Colors.white,
              shape: const StadiumBorder(),
            ),
            icon: const Icon(Icons.check_circle_outline, size: 18),
            label: Text('إتمام البيع والتسليم', style: AppTypography.buttonText()),
            onPressed: () {
              Navigator.pop(ctx);
              final res = ds.sellReward(
                studentId: student.id,
                rewardId: reward.id,
                cashierName: cashierName,
              );

              if (res['success'] == true) {
                onSuccess();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        'تم بيع ${reward.title} للطالب ${student.fullName} بنجاح!'),
                    backgroundColor: Colors.green.shade700,
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(res['message'] ?? 'فشلت عملية البيع'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  static Widget _buildDetailRow(BuildContext context, String label, String value, IconData icon, {Color? color}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: isDark ? Colors.white60 : Colors.grey.shade600),
          const SizedBox(width: 8),
          Text(label, style: AppTypography.bodyRegular(context, fontSize: 13)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
              style: AppTypography.font(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: color ?? (isDark ? Colors.white : AppColors.obsidianEspresso),
              ),
            ),
          ),
        ],
      ),
    );
  }
}