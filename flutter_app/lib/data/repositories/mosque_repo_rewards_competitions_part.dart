part of 'mosque_repository_impl.dart';

/// Rewards catalog, cashier dispensation, and competitions delegation mixin.
mixin MosqueRepoRewardsCompetitionsMixin
    implements RewardsRepository, CompetitionsRepository {
  RewardsRepositoryImpl get rewardsRepository;
  CompetitionsRepositoryImpl get competitionsRepository;

  // Rewards Management
  @override
  List<Reward> getRewards({String? mosqueId}) =>
      rewardsRepository.getRewards(mosqueId: mosqueId);

  @override
  Reward addReward({
    required String mosqueId,
    required String title,
    String? description,
    required int pointsCost,
    bool isActive = true,
  }) =>
      rewardsRepository.addReward(
        mosqueId: mosqueId,
        title: title,
        description: description,
        pointsCost: pointsCost,
        isActive: isActive,
      );

  @override
  void updateReward(Reward reward) =>
      rewardsRepository.updateReward(reward);

  @override
  void deleteReward(String rewardId) =>
      rewardsRepository.deleteReward(rewardId);

  @override
  List<RewardRedemption> getRedemptions({
    String? mosqueId,
    String? studentId,
    String? status,
  }) =>
      rewardsRepository.getRedemptions(
        mosqueId: mosqueId,
        studentId: studentId,
        status: status,
      );

  @override
  RewardRedemption? claimReward({
    required String studentId,
    required String rewardId,
  }) =>
      rewardsRepository.claimReward(
        studentId: studentId,
        rewardId: rewardId,
      );

  @override
  Map<String, dynamic> sellReward({
    required String studentId,
    required String rewardId,
    required String cashierName,
  }) =>
      rewardsRepository.sellReward(
        studentId: studentId,
        rewardId: rewardId,
        cashierName: cashierName,
      );

  @override
  Map<String, dynamic> dispenseReward({
    required String voucherCode,
    required String cashierName,
  }) =>
      rewardsRepository.dispenseReward(
        voucherCode: voucherCode,
        cashierName: cashierName,
      );

  // Competitions & Leaderboards
  @override
  List<Competition> getCompetitions({String? gender, String? mosqueId}) =>
      competitionsRepository.getCompetitions(
        gender: gender,
        mosqueId: mosqueId,
      );

  @override
  Competition addCompetition({
    String mosqueId = '',
    required String title,
    required String description,
    required DateTime startDate,
    required DateTime endDate,
    bool countQuran = true,
    bool countHadith = true,
    bool countAttendance = true,
    int bonusPoints = 0,
    required String genderBranch,
  }) =>
      competitionsRepository.addCompetition(
        mosqueId: mosqueId,
        title: title,
        description: description,
        startDate: startDate,
        endDate: endDate,
        countQuran: countQuran,
        countHadith: countHadith,
        countAttendance: countAttendance,
        bonusPoints: bonusPoints,
        genderBranch: genderBranch,
      );

  @override
  void updateCompetition(Competition comp) =>
      competitionsRepository.updateCompetition(comp);

  @override
  void deleteCompetition(String competitionId) =>
      competitionsRepository.deleteCompetition(competitionId);

  @override
  List<Map<String, dynamic>> getRankings({
    String? competitionId,
    String? mosqueId,
    String? halaqaId,
    String? gender,
    String? courseId,
    DateTime? startDate,
    DateTime? endDate,
  }) =>
      competitionsRepository.getRankings(
        competitionId: competitionId,
        mosqueId: mosqueId,
        halaqaId: halaqaId,
        gender: gender,
        courseId: courseId,
        startDate: startDate,
        endDate: endDate,
      );
}
