import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../services/data_service.dart';
import 'competitions_event.dart';
import 'competitions_state.dart';

class CompetitionsBloc extends Bloc<CompetitionsEvent, CompetitionsState> {
  final DataService _dataService;

  CompetitionsBloc({DataService? dataService})
      : _dataService = dataService ?? DataService(),
        super(CompetitionsState.initial()) {
    on<LoadCompetitionsEvent>(_onLoadCompetitions);
    on<SelectCompetitionEvent>(_onSelectCompetition);
    on<LoadGeneralLeaderboardEvent>(_onLoadGeneralLeaderboard);
    on<AddCompetitionEvent>(_onAddCompetition);
    on<UpdateCompetitionEvent>(_onUpdateCompetition);
    on<DeleteCompetitionEvent>(_onDeleteCompetition);
  }

  void _onLoadCompetitions(
      LoadCompetitionsEvent event, Emitter<CompetitionsState> emit) {
    emit(state.copyWith(status: CompetitionsStatus.loading));

    try {
      final comps = _dataService.getCompetitions(
        gender: event.genderBranch,
      );

      emit(state.copyWith(
        status: CompetitionsStatus.loaded,
        competitions: comps,
        errorMessage: () => null,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: CompetitionsStatus.error,
        errorMessage: () => 'فشل في تحميل المسابقات: ${e.toString()}',
      ));
    }
  }

  void _onSelectCompetition(
      SelectCompetitionEvent event, Emitter<CompetitionsState> emit) {
    emit(state.copyWith(status: CompetitionsStatus.loading));

    try {
      final leaderboard = _dataService.getRankings(
        competitionId: event.competition.id,
        halaqaId: event.halaqaId,
      );

      emit(state.copyWith(
        status: CompetitionsStatus.loaded,
        selectedCompetition: () => event.competition,
        leaderboard: leaderboard,
        errorMessage: () => null,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: CompetitionsStatus.error,
        errorMessage: () => 'فشل في تحميل ترتيب المسابقة: ${e.toString()}',
      ));
    }
  }

  void _onLoadGeneralLeaderboard(
      LoadGeneralLeaderboardEvent event, Emitter<CompetitionsState> emit) {
    emit(state.copyWith(status: CompetitionsStatus.loading));

    try {
      final board = _dataService.getRankings(
        mosqueId: event.mosqueId,
        halaqaId: event.halaqaId,
        gender: event.gender,
      );

      emit(state.copyWith(
        status: CompetitionsStatus.loaded,
        generalLeaderboard: board,
        errorMessage: () => null,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: CompetitionsStatus.error,
        errorMessage: () => 'فشل في تحميل لوحة الشرف العامة: ${e.toString()}',
      ));
    }
  }

  void _onAddCompetition(
      AddCompetitionEvent event, Emitter<CompetitionsState> emit) {
    try {
      final comp = _dataService.addCompetition(
        mosqueId: event.mosqueId,
        title: event.title,
        description: event.description,
        startDate: event.startDate,
        endDate: event.endDate,
        countQuran: event.countQuran,
        countHadith: event.countHadith,
        countAttendance: event.countAttendance,
        bonusPoints: event.bonusPoints,
        genderBranch: event.genderBranch,
      );

      final comps = _dataService.getCompetitions();
      emit(state.copyWith(
        status: CompetitionsStatus.success,
        competitions: comps,
        selectedCompetition: () => comp,
        successMessage: () => 'تمت إضافة المسابقة "${comp.title}" بنجاح',
        errorMessage: () => null,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: CompetitionsStatus.error,
        errorMessage: () => 'فشل في إضافة المسابقة: ${e.toString()}',
      ));
    }
  }

  void _onUpdateCompetition(
      UpdateCompetitionEvent event, Emitter<CompetitionsState> emit) {
    try {
      _dataService.updateCompetition(event.competition);
      final comps = _dataService.getCompetitions();

      emit(state.copyWith(
        status: CompetitionsStatus.success,
        competitions: comps,
        selectedCompetition: () => event.competition,
        successMessage: () => 'تم تحديث بيانات المسابقة بنجاح',
        errorMessage: () => null,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: CompetitionsStatus.error,
        errorMessage: () => 'فشل في تحديث بيانات المسابقة: ${e.toString()}',
      ));
    }
  }

  void _onDeleteCompetition(
      DeleteCompetitionEvent event, Emitter<CompetitionsState> emit) {
    try {
      _dataService.deleteCompetition(event.competitionId);
      final comps = _dataService.getCompetitions();

      emit(state.copyWith(
        status: CompetitionsStatus.success,
        competitions: comps,
        successMessage: () => 'تم حذف المسابقة بنجاح',
        errorMessage: () => null,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: CompetitionsStatus.error,
        errorMessage: () => 'فشل في حذف المسابقة: ${e.toString()}',
      ));
    }
  }
}
