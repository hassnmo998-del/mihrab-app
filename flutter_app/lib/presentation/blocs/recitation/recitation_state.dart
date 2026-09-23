import 'package:equatable/equatable.dart';
import '../../../models/models.dart';

enum RecitationStatus {
  initial,
  loading,
  loaded,
  success,
  error,
}

class RecitationState extends Equatable {
  final RecitationStatus status;
  final String? studentId;
  final List<MemorizationRecord> records;
  final List<MemorizationRecord> todayRecords;
  final List<RecitationTrack> tracks;
  final List<SubjectRecitationRecord> subjectRecords;
  final List<Map<String, dynamic>> studentSubjectProgresses;
  final Map<String, dynamic> overallQuranProgress;
  final Map<int, Map<String, dynamic>> ajzaStatus;
  final Map<String, dynamic>? detectedTimingMode;
  final String? errorMessage;
  final String? successMessage;

  const RecitationState({
    this.status = RecitationStatus.initial,
    this.studentId,
    this.records = const [],
    this.todayRecords = const [],
    this.tracks = const [],
    this.subjectRecords = const [],
    this.studentSubjectProgresses = const [],
    this.overallQuranProgress = const {
      'memorizedAyahs': 0,
      'totalAyahs': 6236,
      'progress': 0.0,
      'completedAjza': 0,
      'totalAjza': 30,
    },
    this.ajzaStatus = const {},
    this.detectedTimingMode,
    this.errorMessage,
    this.successMessage,
  });

  factory RecitationState.initial() => const RecitationState();

  // Progress Helper Getters
  int get memorizedAyahsCount =>
      (overallQuranProgress['memorizedAyahs'] as num?)?.toInt() ?? 0;
  int get totalQuranAyahsCount =>
      (overallQuranProgress['totalAyahs'] as num?)?.toInt() ?? 6236;
  int get completedAjzaCount =>
      (overallQuranProgress['completedAjza'] as num?)?.toInt() ?? 0;
  double get quranProgressFraction =>
      (overallQuranProgress['progress'] as num?)?.toDouble() ?? 0.0;
  double get quranProgressPercentage => (quranProgressFraction * 100);

  // Smart Timing Helper Getters
  bool get hasDetectedTiming => detectedTimingMode != null;
  String get timingMode => detectedTimingMode?['mode'] ?? 'custom';
  bool get isScheduledTiming => timingMode == 'normal' || timingMode == 'course';
  String get timingLabel =>
      detectedTimingMode?['label'] ?? 'تسميع بوقت مخصص (خارج الجلسات المعتادة)';
  String get timingReason => detectedTimingMode?['reason'] ?? '';
  bool get timingCountsTowardsQuran =>
      detectedTimingMode?['countsTowardsQuran'] ?? true;
  String? get timingCourseId => detectedTimingMode?['courseId'] as String?;

  RecitationState copyWith({
    RecitationStatus? status,
    String? Function()? studentId,
    List<MemorizationRecord>? records,
    List<MemorizationRecord>? todayRecords,
    List<RecitationTrack>? tracks,
    List<SubjectRecitationRecord>? subjectRecords,
    List<Map<String, dynamic>>? studentSubjectProgresses,
    Map<String, dynamic>? overallQuranProgress,
    Map<int, Map<String, dynamic>>? ajzaStatus,
    Map<String, dynamic>? Function()? detectedTimingMode,
    String? Function()? errorMessage,
    String? Function()? successMessage,
  }) {
    return RecitationState(
      status: status ?? this.status,
      studentId: studentId != null ? studentId() : this.studentId,
      records: records ?? this.records,
      todayRecords: todayRecords ?? this.todayRecords,
      tracks: tracks ?? this.tracks,
      subjectRecords: subjectRecords ?? this.subjectRecords,
      studentSubjectProgresses:
          studentSubjectProgresses ?? this.studentSubjectProgresses,
      overallQuranProgress: overallQuranProgress ?? this.overallQuranProgress,
      ajzaStatus: ajzaStatus ?? this.ajzaStatus,
      detectedTimingMode: detectedTimingMode != null
          ? detectedTimingMode()
          : this.detectedTimingMode,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
      successMessage:
          successMessage != null ? successMessage() : this.successMessage,
    );
  }

  @override
  List<Object?> get props => [
        status,
        studentId,
        records,
        todayRecords,
        tracks,
        subjectRecords,
        studentSubjectProgresses,
        overallQuranProgress,
        ajzaStatus,
        detectedTimingMode,
        errorMessage,
        successMessage,
      ];
}
