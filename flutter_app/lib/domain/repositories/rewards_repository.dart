import '../../models/models.dart';

/// Contract for Rewards catalog, redemptions, vouchers (`VCH-XXXX`), and cashier dispensation.
abstract class RewardsRepository {
  List<Reward> getRewards({String? mosqueId});
  Reward addReward({
    required String mosqueId,
    required String title,
    String? description,
    required int pointsCost,
    bool isActive = true,
  });
  void updateReward(Reward reward);
  void deleteReward(String rewardId);
  List<RewardRedemption> getRedemptions({
    String? mosqueId,
    String? studentId,
    String? status,
  });
  RewardRedemption? claimReward({
    required String studentId,
    required String rewardId,
  });
  Map<String, dynamic> sellReward({
    required String studentId,
    required String rewardId,
    required String cashierName,
  });
  Map<String, dynamic> dispenseReward({
    required String voucherCode,
    required String cashierName,
  });
}
