import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../services/data_service.dart';
import 'recitation_event.dart';
import 'recitation_state.dart';

class RecitationBloc extends Bloc<RecitationEvent, RecitationState> {
  final DataService _dataService;

  RecitationBloc({DataService? dataService})
      : _dataService = dataService ?? DataService(),
        super(RecitationState.initial()) {
    on<LoadStudentRecitationEvent>(_onLoadStudentRecitation);
    on<LoadTodayRecitationsEvent>(_onLoadTodayRecitations);
    on<RecordQuranRecitationEvent>(_onRecordQuranRecitation);
    on<RecordQuranBatchRecitationEvent>(_onRecordQuranBatchRecitation);
    on<RecordHadithRecitationEvent>(_onRecordHadithRecitation);
    on<RecordSubjectRecitationEvent>(_onRecordSubjectRecitation);
    on<DetectRecitationTimingEvent>(_onDetectRecitationTiming);
    on<LoadRecitationTracksEvent>(_onLoadRecitationTracks);
    on<AddRecitationTrackEvent>(_onAddRecitationTrack);
    on<UpdateRecitationTrackEvent>(_onUpdateRecitationTrack);
    on<DeleteRecitationTrackEvent>(_onDeleteRecitationTrack);
  }

  void _onLoadStudentRecitation(
      LoadStudentRecitationEvent event, Emitter<RecitationState> emit) {
    emit(state.copyWith(status: RecitationStatus.loading));

    try {
      final records = _dataService.getStudentMemorizations(event.studentId);
      final overall = _dataService.getStudentOverallQuranProgress(event.studentId);
      final ajza = _dataService.getStudent30AjzaStatus(event.studentId);
      final subjectProgs =
          _dataService.getAllStudentSubjectProgresses(event.studentId);
      final tracks = _dataService.getRecitationTracks();

      Map<String, dynamic>? timing;
      if (event.halaqaId != null) {
        timing = _dataService.detectSessionTimingMode(
          halaqaId: event.halaqaId!,
          studentId: event.studentId,
        );
      }

      emit(state.copyWith(
        status: RecitationStatus.loaded,
        studentId: () => event.studentId,
        records: records,
        overallQuranProgress: overall,
        ajzaStatus: ajza,
        studentSubjectProgresses: subjectProgs,
        tracks: tracks,
        detectedTimingMode: () => timing ?? state.detectedTimingMode,
        errorMessage: () => null,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: RecitationStatus.error,
        errorMessage: () => 'فشل في تحميل سجلات التسميع: ${e.toString()}',
      ));
    }
  }

  void _onLoadTodayRecitations(
      LoadTodayRecitationsEvent event, Emitter<RecitationState> emit) {
    final today = _dataService.getTodayMemorizations(
      halaqaId: event.halaqaId,
      sheikhId: event.sheikhId,
    );
    emit(state.copyWith(todayRecords: today));
  }

  void _onRecordQuranRecitation(
      RecordQuranRecitationEvent event, Emitter<RecitationState> emit) {
    try {
      _dataService.recordMemorization(
        studentId: event.studentId,
        halaqaId: event.halaqaId,
        sheikhId: event.sheikhId,
        courseId: event.courseId,
        surahName: event.surahName,
        fromAyah: event.fromAyah,
        toAyah: event.toAyah,
        juzNumber: event.juzNumber,
        sessionType: event.sessionType,
        qualityRating: event.qualityRating,
        points: event.points,
        notes: event.notes,
        countsTowardsStatistics: event.countsTowardsStatistics,
      );

      final records = _dataService.getStudentMemorizations(event.studentId);
      final overall = _dataService.getStudentOverallQuranProgress(event.studentId);
      final ajza = _dataService.getStudent30AjzaStatus(event.studentId);

      emit(state.copyWith(
        status: RecitationStatus.success,
        records: records,
        overallQuranProgress: overall,
        ajzaStatus: ajza,
        successMessage: () =>
            'تم تسجيل تسميع سورة ${event.surahName} (${event.fromAyah}-${event.toAyah}) بنجاح (+${event.points} نقطة)',
        errorMessage: () => null,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: RecitationStatus.error,
        errorMessage: () => 'فشل في حفظ التسميع: ${e.toString()}',
      ));
    }
  }

  void _onRecordQuranBatchRecitation(
      RecordQuranBatchRecitationEvent event, Emitter<RecitationState> emit) {
    try {
      _dataService.recordRecitationBatch(
        studentId: event.studentId,
        halaqaId: event.halaqaId,
        sheikhId: event.sheikhId,
        courseId: event.courseId,
        items: event.items,
        sessionType: event.sessionType,
        points: event.points,
        notes: event.notes,
        countsTowardsStatistics: event.countsTowardsStatistics,
      );

      final records = _dataService.getStudentMemorizations(event.studentId);
      final overall = _dataService.getStudentOverallQuranProgress(event.studentId);
      final ajza = _dataService.getStudent30AjzaStatus(event.studentId);

      emit(state.copyWith(
        status: RecitationStatus.success,
        records: records,
        overallQuranProgress: overall,
        ajzaStatus: ajza,
        successMessage: () =>
            'تم تسجيل دفعة التسميع (${event.items.length} مقطع) بنجاح (+${event.points} نقطة)',
        errorMessage: () => null,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: RecitationStatus.error,
        errorMessage: () => 'فشل في حفظ دفعة التسميع: ${e.toString()}',
      ));
    }
  }

  void _onRecordHadithRecitation(
      RecordHadithRecitationEvent event, Emitter<RecitationState> emit) {
    try {
      _dataService.recordHadith(
        studentId: event.studentId,
        halaqaId: event.halaqaId,
        hadithTitle: event.hadithTitle,
        points: event.points,
      );

      emit(state.copyWith(
        status: RecitationStatus.success,
        successMessage: () =>
            'تم تسجيل تسميع الحديث الشريف "${event.hadithTitle}" بنجاح (+${event.points} نقطة)',
        errorMessage: () => null,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: RecitationStatus.error,
        errorMessage: () => 'فشل في حفظ تسميع الحديث: ${e.toString()}',
      ));
    }
  }

  void _onRecordSubjectRecitation(
      RecordSubjectRecitationEvent event, Emitter<RecitationState> emit) {
    try {
      _dataService.recordSubjectRecitation(
        studentId: event.studentId,
        halaqaId: event.halaqaId,
        sheikhId: event.sheikhId,
        trackId: event.trackId,
        trackName: event.trackName,
        fromUnit: event.fromUnit,
        toUnit: event.toUnit,
        pointsEarned: event.pointsEarned,
        courseId: event.courseId,
        notes: event.notes,
        countsTowardsStatistics: event.countsTowardsStatistics,
      );

      final subjectProgs =
          _dataService.getAllStudentSubjectProgresses(event.studentId);

      emit(state.copyWith(
        status: RecitationStatus.success,
        studentSubjectProgresses: subjectProgs,
        successMessage: () =>
            'تم حفظ تسميع منهج ${event.trackName} من ${event.fromUnit} إلى ${event.toUnit} بنجاح (+${event.pointsEarned} نقطة)',
        errorMessage: () => null,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: RecitationStatus.error,
        errorMessage: () => 'فشل في حفظ تسميع المسار المخصص: ${e.toString()}',
      ));
    }
  }

  void _onDetectRecitationTiming(
      DetectRecitationTimingEvent event, Emitter<RecitationState> emit) {
    final timing = _dataService.detectSessionTimingMode(
      halaqaId: event.halaqaId,
      studentId: event.studentId,
      currentTime: event.currentTime,
    );

    emit(state.copyWith(
      detectedTimingMode: () => timing,
    ));
  }

  void _onLoadRecitationTracks(
      LoadRecitationTracksEvent event, Emitter<RecitationState> emit) {
    final tracks = _dataService.getRecitationTracks(
      mosqueId: event.mosqueId,
      halaqaId: event.halaqaId,
      activeOnly: event.activeOnly,
    );
    emit(state.copyWith(tracks: tracks));
  }

  void _onAddRecitationTrack(
      AddRecitationTrackEvent event, Emitter<RecitationState> emit) {
    try {
      final track = _dataService.addRecitationTrack(
        mosqueId: event.mosqueId,
        name: event.name,
        category: event.category,
        unitLabel: event.unitLabel,
        totalUnits: event.totalUnits,
        pointsPerUnit: event.pointsPerUnit,
        isActive: event.isActive,
        targetHalaqaIds: event.targetHalaqaIds,
        sheikhId: event.sheikhId,
      );

      final tracks = _dataService.getRecitationTracks();
      emit(state.copyWith(
        status: RecitationStatus.success,
        tracks: tracks,
        successMessage: () => 'تمت إضافة منهج ${track.name} بنجاح',
        errorMessage: () => null,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: RecitationStatus.error,
        errorMessage: () => 'فشل في إضافة المسار: ${e.toString()}',
      ));
    }
  }

  void _onUpdateRecitationTrack(
      UpdateRecitationTrackEvent event, Emitter<RecitationState> emit) {
    try {
      _dataService.updateRecitationTrack(event.track);
      final tracks = _dataService.getRecitationTracks();

      emit(state.copyWith(
        status: RecitationStatus.success,
        tracks: tracks,
        successMessage: () => 'تم تحديث المسار بنجاح',
        errorMessage: () => null,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: RecitationStatus.error,
        errorMessage: () => 'فشل في تحديث المسار: ${e.toString()}',
      ));
    }
  }

  void _onDeleteRecitationTrack(
      DeleteRecitationTrackEvent event, Emitter<RecitationState> emit) {
    try {
      _dataService.deleteRecitationTrack(event.trackId);
      final tracks = _dataService.getRecitationTracks();

      emit(state.copyWith(
        status: RecitationStatus.success,
        tracks: tracks,
        successMessage: () => 'تم حذف المسار بنجاح',
        errorMessage: () => null,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: RecitationStatus.error,
        errorMessage: () => 'فشل في حذف المسار: ${e.toString()}',
      ));
    }
  }
}
