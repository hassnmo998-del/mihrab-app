import 'package:equatable/equatable.dart';
import '../../../models/models.dart';

abstract class RecitationEvent extends Equatable {
  const RecitationEvent();

  @override
  List<Object?> get props => [];
}

/// Load recitations and calculate progress for a student
class LoadStudentRecitationEvent extends RecitationEvent {
  final String studentId;
  final String? halaqaId;

  const LoadStudentRecitationEvent({
    required this.studentId,
    this.halaqaId,
  });

  @override
  List<Object?> get props => [studentId, halaqaId];
}

/// Load today's recitation records for a halaqa or sheikh
class LoadTodayRecitationsEvent extends RecitationEvent {
  final String? halaqaId;
  final String? sheikhId;

  const LoadTodayRecitationsEvent({this.halaqaId, this.sheikhId});

  @override
  List<Object?> get props => [halaqaId, sheikhId];
}

/// Record a single Quran recitation segment
class RecordQuranRecitationEvent extends RecitationEvent {
  final String studentId;
  final String? halaqaId;
  final String? sheikhId;
  final String? courseId;
  final String surahName;
  final int fromAyah;
  final int toAyah;
  final int juzNumber;
  final String sessionType; // 'new_memorization', 'review', 'test'
  final String qualityRating;
  final int points;
  final String? notes;
  final bool countsTowardsStatistics;

  const RecordQuranRecitationEvent({
    required this.studentId,
    this.halaqaId,
    this.sheikhId,
    this.courseId,
    required this.surahName,
    required this.fromAyah,
    required this.toAyah,
    required this.juzNumber,
    required this.sessionType,
    this.qualityRating = 'excellent',
    required this.points,
    this.notes,
    this.countsTowardsStatistics = true,
  });

  @override
  List<Object?> get props => [
        studentId,
        halaqaId,
        sheikhId,
        courseId,
        surahName,
        fromAyah,
        toAyah,
        juzNumber,
        sessionType,
        qualityRating,
        points,
        notes,
        countsTowardsStatistics,
      ];
}

/// Record multiple Quran portions in a single batch
class RecordQuranBatchRecitationEvent extends RecitationEvent {
  final String studentId;
  final String? halaqaId;
  final String? sheikhId;
  final String? courseId;
  final List<Map<String, dynamic>> items;
  final String sessionType;
  final int points;
  final String? notes;
  final bool countsTowardsStatistics;

  const RecordQuranBatchRecitationEvent({
    required this.studentId,
    this.halaqaId,
    this.sheikhId,
    this.courseId,
    required this.items,
    required this.sessionType,
    required this.points,
    this.notes,
    this.countsTowardsStatistics = true,
  });

  @override
  List<Object?> get props => [
        studentId,
        halaqaId,
        sheikhId,
        courseId,
        items,
        sessionType,
        points,
        notes,
        countsTowardsStatistics,
      ];
}

/// Record Hadith recitation
class RecordHadithRecitationEvent extends RecitationEvent {
  final String studentId;
  final String? halaqaId;
  final String hadithTitle;
  final int points;

  const RecordHadithRecitationEvent({
    required this.studentId,
    this.halaqaId,
    required this.hadithTitle,
    required this.points,
  });

  @override
  List<Object?> get props => [studentId, halaqaId, hadithTitle, points];
}

/// Record recitation on custom curriculum tracks (Hadith, Matn, Pages, etc.)
class RecordSubjectRecitationEvent extends RecitationEvent {
  final String studentId;
  final String? halaqaId;
  final String? sheikhId;
  final String trackId;
  final String trackName;
  final int fromUnit;
  final int toUnit;
  final int pointsEarned;
  final String? courseId;
  final String? notes;
  final bool countsTowardsStatistics;

  const RecordSubjectRecitationEvent({
    required this.studentId,
    this.halaqaId,
    this.sheikhId,
    required this.trackId,
    required this.trackName,
    required this.fromUnit,
    required this.toUnit,
    required this.pointsEarned,
    this.courseId,
    this.notes,
    this.countsTowardsStatistics = true,
  });

  @override
  List<Object?> get props => [
        studentId,
        halaqaId,
        sheikhId,
        trackId,
        trackName,
        fromUnit,
        toUnit,
        pointsEarned,
        courseId,
        notes,
        countsTowardsStatistics,
      ];
}

/// Detect session timing mode within ±30 minutes buffer
class DetectRecitationTimingEvent extends RecitationEvent {
  final String halaqaId;
  final String? studentId;
  final DateTime? currentTime;

  const DetectRecitationTimingEvent({
    required this.halaqaId,
    this.studentId,
    this.currentTime,
  });

  @override
  List<Object?> get props => [halaqaId, studentId, currentTime];
}

/// Load custom recitation tracks
class LoadRecitationTracksEvent extends RecitationEvent {
  final String? mosqueId;
  final String? halaqaId;
  final bool activeOnly;

  const LoadRecitationTracksEvent({
    this.mosqueId,
    this.halaqaId,
    this.activeOnly = true,
  });

  @override
  List<Object?> get props => [mosqueId, halaqaId, activeOnly];
}

/// Add a new custom curriculum/track
class AddRecitationTrackEvent extends RecitationEvent {
  final String mosqueId;
  final String name;
  final String category;
  final String unitLabel;
  final int totalUnits;
  final int pointsPerUnit;
  final bool isActive;
  final List<String> targetHalaqaIds;
  final String? sheikhId;

  const AddRecitationTrackEvent({
    required this.mosqueId,
    required this.name,
    this.category = 'custom',
    this.unitLabel = 'حديث',
    this.totalUnits = 40,
    this.pointsPerUnit = 2,
    this.isActive = true,
    this.targetHalaqaIds = const [],
    this.sheikhId,
  });

  @override
  List<Object?> get props => [
        mosqueId,
        name,
        category,
        unitLabel,
        totalUnits,
        pointsPerUnit,
        isActive,
        targetHalaqaIds,
        sheikhId,
      ];
}

/// Update an existing recitation track
class UpdateRecitationTrackEvent extends RecitationEvent {
  final RecitationTrack track;

  const UpdateRecitationTrackEvent(this.track);

  @override
  List<Object?> get props => [track];
}

/// Delete a recitation track
class DeleteRecitationTrackEvent extends RecitationEvent {
  final String trackId;

  const DeleteRecitationTrackEvent(this.trackId);

  @override
  List<Object?> get props => [trackId];
}
