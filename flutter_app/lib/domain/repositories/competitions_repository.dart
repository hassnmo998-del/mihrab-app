import '../../models/models.dart';

/// Contract for Competitions and dynamic honor leaderboard rankings.
abstract class CompetitionsRepository {
  List<Competition> getCompetitions({String? gender, String? mosqueId});
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
  });
  void updateCompetition(Competition comp);
  void deleteCompetition(String competitionId);
  List<Map<String, dynamic>> getRankings({
    String? competitionId,
    String? mosqueId,
    String? halaqaId,
    String? gender,
    String? courseId,
    DateTime? startDate,
    DateTime? endDate,
  });
}
