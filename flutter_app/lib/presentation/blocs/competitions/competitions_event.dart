import 'package:equatable/equatable.dart';
import '../../../models/models.dart';

abstract class CompetitionsEvent extends Equatable {
  const CompetitionsEvent();

  @override
  List<Object?> get props => [];
}

/// Load competitions list with optional gender filter
class LoadCompetitionsEvent extends CompetitionsEvent {
  final String? genderBranch;

  const LoadCompetitionsEvent({this.genderBranch});

  @override
  List<Object?> get props => [genderBranch];
}

/// Select a competition to view leaderboard and details
class SelectCompetitionEvent extends CompetitionsEvent {
  final Competition competition;
  final String? halaqaId;

  const SelectCompetitionEvent(this.competition, {this.halaqaId});

  @override
  List<Object?> get props => [competition, halaqaId];
}

/// Load general leaderboard across all students
class LoadGeneralLeaderboardEvent extends CompetitionsEvent {
  final String? mosqueId;
  final String? halaqaId;
  final String? gender;

  const LoadGeneralLeaderboardEvent({
    this.mosqueId,
    this.halaqaId,
    this.gender,
  });

  @override
  List<Object?> get props => [mosqueId, halaqaId, gender];
}

/// Add a new competition
class AddCompetitionEvent extends CompetitionsEvent {
  final String mosqueId;
  final String title;
  final String description;
  final DateTime startDate;
  final DateTime endDate;
  final bool countQuran;
  final bool countHadith;
  final bool countAttendance;
  final int bonusPoints;
  final String genderBranch;

  const AddCompetitionEvent({
    required this.mosqueId,
    required this.title,
    required this.description,
    required this.startDate,
    required this.endDate,
    this.countQuran = true,
    this.countHadith = true,
    this.countAttendance = true,
    this.bonusPoints = 0,
    this.genderBranch = 'male',
  });

  @override
  List<Object?> get props => [
        mosqueId,
        title,
        description,
        startDate,
        endDate,
        countQuran,
        countHadith,
        countAttendance,
        bonusPoints,
        genderBranch,
      ];
}

/// Update an existing competition
class UpdateCompetitionEvent extends CompetitionsEvent {
  final Competition competition;

  const UpdateCompetitionEvent(this.competition);

  @override
  List<Object?> get props => [competition];
}

/// Delete a competition
class DeleteCompetitionEvent extends CompetitionsEvent {
  final String competitionId;

  const DeleteCompetitionEvent(this.competitionId);

  @override
  List<Object?> get props => [competitionId];
}
