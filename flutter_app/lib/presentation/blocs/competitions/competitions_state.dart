import 'package:equatable/equatable.dart';
import '../../../models/models.dart';

enum CompetitionsStatus {
  initial,
  loading,
  loaded,
  success,
  error,
}

class CompetitionsState extends Equatable {
  final CompetitionsStatus status;
  final List<Competition> competitions;
  final Competition? selectedCompetition;
  final List<Map<String, dynamic>> leaderboard;
  final List<Map<String, dynamic>> generalLeaderboard;
  final String? errorMessage;
  final String? successMessage;

  const CompetitionsState({
    this.status = CompetitionsStatus.initial,
    this.competitions = const [],
    this.selectedCompetition,
    this.leaderboard = const [],
    this.generalLeaderboard = const [],
    this.errorMessage,
    this.successMessage,
  });

  factory CompetitionsState.initial() => const CompetitionsState();

  List<Competition> get activeCompetitions =>
      competitions.where((c) => c.isActive).toList();

  List<Competition> get upcomingCompetitions {
    final now = DateTime.now();
    return competitions.where((c) => c.startDate.isAfter(now)).toList();
  }

  int get totalCount => competitions.length;

  CompetitionsState copyWith({
    CompetitionsStatus? status,
    List<Competition>? competitions,
    Competition? Function()? selectedCompetition,
    List<Map<String, dynamic>>? leaderboard,
    List<Map<String, dynamic>>? generalLeaderboard,
    String? Function()? errorMessage,
    String? Function()? successMessage,
  }) {
    return CompetitionsState(
      status: status ?? this.status,
      competitions: competitions ?? this.competitions,
      selectedCompetition: selectedCompetition != null
          ? selectedCompetition()
          : this.selectedCompetition,
      leaderboard: leaderboard ?? this.leaderboard,
      generalLeaderboard: generalLeaderboard ?? this.generalLeaderboard,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
      successMessage:
          successMessage != null ? successMessage() : this.successMessage,
    );
  }

  @override
  List<Object?> get props => [
        status,
        competitions,
        selectedCompetition,
        leaderboard,
        generalLeaderboard,
        errorMessage,
        successMessage,
      ];
}
