import '../../models/models.dart';
import '../repositories/mosque_repository.dart';

/// Use case for querying available active rewards for a mosque.
class GetRewardsUseCase {
  final MosqueRepository _repository;

  const GetRewardsUseCase(this._repository);

  List<Reward> call({String? mosqueId}) =>
      _repository.getRewards(mosqueId: mosqueId);
}

/// Use case for redeeming a reward by a student (generating a voucher).
class RedeemRewardUseCase {
  final MosqueRepository _repository;

  const RedeemRewardUseCase(this._repository);

  RewardRedemption? call({
    required String studentId,
    required String rewardId,
  }) {
    return _repository.claimReward(
      studentId: studentId,
      rewardId: rewardId,
    );
  }
}

/// Use case for cashier dispensation of redeemed rewards using voucher code.
class DispenseRewardUseCase {
  final MosqueRepository _repository;

  const DispenseRewardUseCase(this._repository);

  Map<String, dynamic> call({
    required String voucherCode,
    required String cashierName,
  }) {
    return _repository.dispenseReward(
      voucherCode: voucherCode,
      cashierName: cashierName,
    );
  }
}
