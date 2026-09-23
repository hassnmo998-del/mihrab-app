import 'package:equatable/equatable.dart';
import '../../../models/models.dart';

abstract class RewardsEvent extends Equatable {
  const RewardsEvent();

  @override
  List<Object?> get props => [];
}

/// Load rewards catalog and redemptions
class LoadRewardsEvent extends RewardsEvent {
  final String? mosqueId;
  final String? studentId;

  const LoadRewardsEvent({this.mosqueId, this.studentId});

  @override
  List<Object?> get props => [mosqueId, studentId];
}

/// Claim a reward voucher with student points
class ClaimRewardEvent extends RewardsEvent {
  final String studentId;
  final String rewardId;

  const ClaimRewardEvent({
    required this.studentId,
    required this.rewardId,
  });

  @override
  List<Object?> get props => [studentId, rewardId];
}

/// Dispense a reward at the cashier using voucher code (VCH-*)
class DispenseRewardEvent extends RewardsEvent {
  final String voucherCode;
  final String cashierName;

  const DispenseRewardEvent({
    required this.voucherCode,
    required this.cashierName,
  });

  @override
  List<Object?> get props => [voucherCode, cashierName];
}

/// Add a new reward item to the catalog
class AddRewardEvent extends RewardsEvent {
  final String mosqueId;
  final String title;
  final String? description;
  final int pointsCost;
  final bool isActive;

  const AddRewardEvent({
    required this.mosqueId,
    required this.title,
    this.description,
    required this.pointsCost,
    this.isActive = true,
  });

  @override
  List<Object?> get props => [mosqueId, title, description, pointsCost, isActive];
}

/// Update an existing reward
class UpdateRewardEvent extends RewardsEvent {
  final Reward reward;

  const UpdateRewardEvent(this.reward);

  @override
  List<Object?> get props => [reward];
}

/// Delete a reward item
class DeleteRewardEvent extends RewardsEvent {
  final String rewardId;

  const DeleteRewardEvent(this.rewardId);

  @override
  List<Object?> get props => [rewardId];
}
