import 'package:equatable/equatable.dart';
import '../../../models/models.dart';

enum RewardsStatus {
  initial,
  loading,
  loaded,
  success,
  error,
}

class RewardsState extends Equatable {
  final RewardsStatus status;
  final List<Reward> rewards;
  final List<RewardRedemption> redemptions;
  final RewardRedemption? lastClaimedRedemption;
  final Map<String, dynamic>? lastDispenseResult;
  final String? errorMessage;
  final String? successMessage;

  const RewardsState({
    this.status = RewardsStatus.initial,
    this.rewards = const [],
    this.redemptions = const [],
    this.lastClaimedRedemption,
    this.lastDispenseResult,
    this.errorMessage,
    this.successMessage,
  });

  factory RewardsState.initial() => const RewardsState();

  List<Reward> get activeRewards => rewards.where((r) => r.isActive).toList();
  List<RewardRedemption> get pendingRedemptions =>
      redemptions.where((r) => r.isPending).toList();
  List<RewardRedemption> get dispensedRedemptions =>
      redemptions.where((r) => r.isDispensed).toList();

  RewardsState copyWith({
    RewardsStatus? status,
    List<Reward>? rewards,
    List<RewardRedemption>? redemptions,
    RewardRedemption? Function()? lastClaimedRedemption,
    Map<String, dynamic>? Function()? lastDispenseResult,
    String? Function()? errorMessage,
    String? Function()? successMessage,
  }) {
    return RewardsState(
      status: status ?? this.status,
      rewards: rewards ?? this.rewards,
      redemptions: redemptions ?? this.redemptions,
      lastClaimedRedemption: lastClaimedRedemption != null
          ? lastClaimedRedemption()
          : this.lastClaimedRedemption,
      lastDispenseResult: lastDispenseResult != null
          ? lastDispenseResult()
          : this.lastDispenseResult,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
      successMessage:
          successMessage != null ? successMessage() : this.successMessage,
    );
  }

  @override
  List<Object?> get props => [
        status,
        rewards,
        redemptions,
        lastClaimedRedemption,
        lastDispenseResult,
        errorMessage,
        successMessage,
      ];
}
