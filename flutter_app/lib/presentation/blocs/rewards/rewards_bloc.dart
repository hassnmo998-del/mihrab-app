import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../services/data_service.dart';
import 'rewards_event.dart';
import 'rewards_state.dart';

class RewardsBloc extends Bloc<RewardsEvent, RewardsState> {
  final DataService _dataService;

  RewardsBloc({DataService? dataService})
      : _dataService = dataService ?? DataService(),
        super(RewardsState.initial()) {
    on<LoadRewardsEvent>(_onLoadRewards);
    on<ClaimRewardEvent>(_onClaimReward);
    on<DispenseRewardEvent>(_onDispenseReward);
    on<AddRewardEvent>(_onAddReward);
    on<UpdateRewardEvent>(_onUpdateReward);
    on<DeleteRewardEvent>(_onDeleteReward);
  }

  void _onLoadRewards(LoadRewardsEvent event, Emitter<RewardsState> emit) {
    emit(state.copyWith(status: RewardsStatus.loading));

    try {
      final rewards = _dataService.getRewards(mosqueId: event.mosqueId);
      final redemptions = _dataService.getRedemptions(
        mosqueId: event.mosqueId,
        studentId: event.studentId,
      );

      emit(state.copyWith(
        status: RewardsStatus.loaded,
        rewards: rewards,
        redemptions: redemptions,
        errorMessage: () => null,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: RewardsStatus.error,
        errorMessage: () => 'فشل في تحميل قائمة الجوائز: ${e.toString()}',
      ));
    }
  }

  void _onClaimReward(ClaimRewardEvent event, Emitter<RewardsState> emit) {
    try {
      final redemption = _dataService.claimReward(
        studentId: event.studentId,
        rewardId: event.rewardId,
      );

      if (redemption != null) {
        final redemptions = _dataService.getRedemptions();
        emit(state.copyWith(
          status: RewardsStatus.success,
          redemptions: redemptions,
          lastClaimedRedemption: () => redemption,
          successMessage: () =>
              'تم استبدال الجائزة بنجاح! كود القسيمة: ${redemption.redemptionCode}',
          errorMessage: () => null,
        ));
      } else {
        emit(state.copyWith(
          status: RewardsStatus.error,
          errorMessage: () => 'رصيد نقاط الطالب غير كافٍ لاستبدال هذه الجائزة',
        ));
      }
    } catch (e) {
      emit(state.copyWith(
        status: RewardsStatus.error,
        errorMessage: () => 'فشل في استبدال الجائزة: ${e.toString()}',
      ));
    }
  }

  void _onDispenseReward(DispenseRewardEvent event, Emitter<RewardsState> emit) {
    try {
      final result = _dataService.dispenseReward(
        voucherCode: event.voucherCode,
        cashierName: event.cashierName,
      );

      final success = result['success'] == true;
      final redemptions = _dataService.getRedemptions();

      if (success) {
        emit(state.copyWith(
          status: RewardsStatus.success,
          redemptions: redemptions,
          lastDispenseResult: () => result,
          successMessage: () => 'تم صرف وتسليم الجائزة بنجاح وخصم النقاط',
          errorMessage: () => null,
        ));
      } else {
        emit(state.copyWith(
          status: RewardsStatus.error,
          lastDispenseResult: () => result,
          errorMessage: () => result['message']?.toString() ?? 'فشل في صرف الجائزة',
        ));
      }
    } catch (e) {
      emit(state.copyWith(
        status: RewardsStatus.error,
        errorMessage: () => 'حدث خطأ أثناء صرف الجائزة: ${e.toString()}',
      ));
    }
  }

  void _onAddReward(AddRewardEvent event, Emitter<RewardsState> emit) {
    try {
      final reward = _dataService.addReward(
        mosqueId: event.mosqueId,
        title: event.title,
        description: event.description,
        pointsCost: event.pointsCost,
      );

      final rewards = _dataService.getRewards();
      emit(state.copyWith(
        status: RewardsStatus.success,
        rewards: rewards,
        successMessage: () => 'تمت إضافة الجائزة "${reward.title}" بنجاح',
        errorMessage: () => null,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: RewardsStatus.error,
        errorMessage: () => 'فشل في إضافة الجائزة: ${e.toString()}',
      ));
    }
  }

  void _onUpdateReward(UpdateRewardEvent event, Emitter<RewardsState> emit) {
    try {
      _dataService.updateReward(event.reward);
      final rewards = _dataService.getRewards();

      emit(state.copyWith(
        status: RewardsStatus.success,
        rewards: rewards,
        successMessage: () => 'تم تحديث بيانات الجائزة بنجاح',
        errorMessage: () => null,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: RewardsStatus.error,
        errorMessage: () => 'فشل في تحديث بيانات الجائزة: ${e.toString()}',
      ));
    }
  }

  void _onDeleteReward(DeleteRewardEvent event, Emitter<RewardsState> emit) {
    try {
      _dataService.deleteReward(event.rewardId);
      final rewards = _dataService.getRewards();

      emit(state.copyWith(
        status: RewardsStatus.success,
        rewards: rewards,
        successMessage: () => 'تم حذف الجائزة بنجاح',
        errorMessage: () => null,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: RewardsStatus.error,
        errorMessage: () => 'فشل في حذف الجائزة: ${e.toString()}',
      ));
    }
  }
}
