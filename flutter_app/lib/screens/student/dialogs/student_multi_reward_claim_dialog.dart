import 'package:flutter/material.dart';
import '../../../models/models.dart';
import '../../../services/data_service.dart';
import '../../../widgets/qr_dialogs.dart';

void showStudentMultiRewardClaimDialog(
  BuildContext context,
  DataService data,
  Student student,
  Reward reward,
  int maxAffordable,
) {
  int quantity = 1;

  showDialog(
    context: context,
    builder: (ctx) {
      final theme = Theme.of(ctx);
      final primaryColor = theme.colorScheme.primary;

      return StatefulBuilder(
        builder: (ctx, setDState) => AlertDialog(
          actionsOverflowButtonSpacing: 8,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.card_giftcard, color: primaryColor),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('استبدال الجائزة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'الجائزة: ${reward.title}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 6),
                Text(
                  'سعر القسيمة الواحدة: ${reward.pointsCost} نقطة\nرصيدك الحالي: ${student.totalPoints} نقطة\nالحد الأقصى المتاح لك: $maxAffordable قسيمة',
                  style: const TextStyle(fontSize: 12, height: 1.4),
                ),
                const SizedBox(height: 16),
                const Text('حدد العدد المطلوب صرفه:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    style: IconButton.styleFrom(
                      backgroundColor: theme.brightness == Brightness.dark
                          ? Colors.white10
                          : Colors.grey.shade200,
                    ),
                    icon: const Icon(Icons.remove),
                    onPressed: quantity > 1 ? () => setDState(() => quantity--) : null,
                  ),
                  const SizedBox(width: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: primaryColor, width: 1.5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$quantity',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryColor),
                    ),
                  ),
                  const SizedBox(width: 16),
                  IconButton(
                    style: IconButton.styleFrom(
                      backgroundColor: theme.brightness == Brightness.dark
                          ? Colors.white10
                          : Colors.grey.shade200,
                    ),
                    icon: const Icon(Icons.add),
                    onPressed: quantity < maxAffordable ? () => setDState(() => quantity++) : null,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Center(
                child: Text(
                  'الإجمالي: ${quantity * reward.pointsCost} نقطة',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber.shade900, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
        actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(ctx);
                RewardRedemption? lastRed;
                for (int i = 0; i < quantity; i++) {
                  lastRed = data.claimReward(
                    studentId: student.id,
                    rewardId: reward.id,
                  );
                }
                if (lastRed != null) {
                  showDialog(
                    context: context,
                    builder: (_) => RewardVoucherQrDialog(redemption: lastRed!),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('تم استخراج $quantity قسائم بنجاح! تجدها في تبويب قسائمي.'),
                      backgroundColor: primaryColor,
                    ),
                  );
                }
              },
              child: Text('تأكيد استبدال $quantity قسيمة'),
            ),
          ],
        ),
      );
    },
  );
}
