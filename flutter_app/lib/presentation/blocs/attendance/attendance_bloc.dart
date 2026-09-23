import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../services/data_service.dart';
import 'attendance_event.dart';
import 'attendance_state.dart';

class AttendanceBloc extends Bloc<AttendanceEvent, AttendanceState> {
  final DataService _dataService;

  AttendanceBloc({DataService? dataService})
      : _dataService = dataService ?? DataService(),
        super(AttendanceState.initial()) {
    on<LoadHalaqaAttendanceEvent>(_onLoadHalaqaAttendance);
    on<MarkStudentAttendanceEvent>(_onMarkStudentAttendance);
    on<BatchMarkAttendanceEvent>(_onBatchMarkAttendance);
    on<LoadStudentAttendanceSummaryEvent>(_onLoadStudentAttendanceSummary);
    on<ChangeAttendanceDateEvent>(_onChangeAttendanceDate);
  }

  void _onLoadHalaqaAttendance(
      LoadHalaqaAttendanceEvent event, Emitter<AttendanceState> emit) {
    emit(state.copyWith(status: AttendanceStatus.loading));

    try {
      final records = _dataService.getAttendanceForDate(
        event.halaqaId,
        event.sessionDate,
      );

      final stats = _computeHalaqaStats(records);

      emit(state.copyWith(
        status: AttendanceStatus.loaded,
        halaqaId: () => event.halaqaId,
        sessionDate: event.sessionDate,
        records: records,
        halaqaSessionStats: () => stats,
        errorMessage: () => null,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: AttendanceStatus.error,
        errorMessage: () => 'فشل في تحميل سجل الحضور: ${e.toString()}',
      ));
    }
  }

  void _onMarkStudentAttendance(
      MarkStudentAttendanceEvent event, Emitter<AttendanceState> emit) {
    try {
      _dataService.recordAttendance(
        studentId: event.studentId,
        halaqaId: event.halaqaId,
        sessionDate: event.sessionDate,
        status: event.status,
        pointsEarned: event.pointsEarned,
        notes: event.notes,
      );

      final records = _dataService.getAttendanceForDate(
        event.halaqaId,
        event.sessionDate,
      );
      final stats = _computeHalaqaStats(records);

      final statusAr = {
        'present': 'حاضر',
        'late': 'متأخر',
        'absent': 'غائب',
        'excused': 'معذور',
      }[event.status] ?? event.status;

      emit(state.copyWith(
        status: AttendanceStatus.success,
        records: records,
        halaqaSessionStats: () => stats,
        successMessage: () =>
            'تم تسجيل حالة الطالب: $statusAr ${event.pointsEarned > 0 ? "(+${event.pointsEarned} نقطة)" : ""}',
        errorMessage: () => null,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: AttendanceStatus.error,
        errorMessage: () => 'فشل في حفظ الحضور: ${e.toString()}',
      ));
    }
  }

  void _onBatchMarkAttendance(
      BatchMarkAttendanceEvent event, Emitter<AttendanceState> emit) {
    try {
      for (final item in event.items) {
        _dataService.recordAttendance(
          studentId: item.studentId,
          halaqaId: event.halaqaId,
          sessionDate: event.sessionDate,
          status: item.status,
          pointsEarned: item.pointsEarned,
          notes: item.notes,
        );
      }

      final records = _dataService.getAttendanceForDate(
        event.halaqaId,
        event.sessionDate,
      );
      final stats = _computeHalaqaStats(records);

      emit(state.copyWith(
        status: AttendanceStatus.success,
        records: records,
        halaqaSessionStats: () => stats,
        successMessage: () =>
            'تم حفظ حضور ${event.items.length} طلاب لجلسة ${event.sessionDate} بنجاح',
        errorMessage: () => null,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: AttendanceStatus.error,
        errorMessage: () => 'فشل في حفظ سجل الحضور الجماعي: ${e.toString()}',
      ));
    }
  }

  void _onLoadStudentAttendanceSummary(
      LoadStudentAttendanceSummaryEvent event, Emitter<AttendanceState> emit) {
    emit(state.copyWith(status: AttendanceStatus.loading));

    try {
      final summary = _dataService.getStudentAttendanceSummary(event.studentId);

      emit(state.copyWith(
        status: AttendanceStatus.loaded,
        studentId: () => event.studentId,
        studentSummary: () => summary,
        errorMessage: () => null,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: AttendanceStatus.error,
        errorMessage: () => 'فشل في تحميل إحصائيات حضور الطالب: ${e.toString()}',
      ));
    }
  }

  void _onChangeAttendanceDate(
      ChangeAttendanceDateEvent event, Emitter<AttendanceState> emit) {
    if (state.halaqaId != null && state.halaqaId!.isNotEmpty) {
      add(LoadHalaqaAttendanceEvent(
        halaqaId: state.halaqaId!,
        sessionDate: event.newDate,
      ));
    } else {
      emit(state.copyWith(sessionDate: event.newDate));
    }
  }

  Map<String, dynamic> _computeHalaqaStats(List<dynamic> records) {
    int present = 0;
    int late = 0;
    int absent = 0;
    int excused = 0;

    for (final r in records) {
      final status = r.status as String;
      if (status == 'present') {
        present++;
      } else if (status == 'late') {
        late++;
      } else if (status == 'absent') {
        absent++;
      } else if (status == 'excused') {
        excused++;
      }
    }

    final total = records.length;
    final percentage = total > 0
        ? ((present + (late * 0.5)) / total * 100)
        : 100.0;

    return {
      'presentCount': present,
      'lateCount': late,
      'absentCount': absent,
      'excusedCount': excused,
      'totalRecorded': total,
      'attendancePercentage': percentage,
    };
  }
}
