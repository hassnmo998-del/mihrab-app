import 'package:equatable/equatable.dart';
import '../../../models/models.dart';

abstract class TripsEvent extends Equatable {
  const TripsEvent();

  @override
  List<Object?> get props => [];
}

/// Load trips list with optional mosque / student / halaqa context
class LoadTripsEvent extends TripsEvent {
  final String? mosqueId;
  final String? studentId;
  final String? halaqaId;

  const LoadTripsEvent({
    this.mosqueId,
    this.studentId,
    this.halaqaId,
  });

  @override
  List<Object?> get props => [mosqueId, studentId, halaqaId];
}

/// Filter loaded trips by halaqa, student, status or search query
class FilterTripsEvent extends TripsEvent {
  final String? halaqaId;
  final String? studentId;
  final String? status; // 'all', 'upcoming', 'completed', 'cancelled'
  final String? searchQuery;

  const FilterTripsEvent({
    this.halaqaId,
    this.studentId,
    this.status,
    this.searchQuery,
  });

  @override
  List<Object?> get props => [halaqaId, studentId, status, searchQuery];
}

/// Add a new trip with required items (🎒) and targeted audience
class AddTripEvent extends TripsEvent {
  final String mosqueId;
  final String title;
  final String destination;
  final DateTime tripDate;
  final String meetingTime;
  final DateTime? deadlineDate;
  final String? description;
  final String requiredItems; // 🎒 ما يلزم إحضاره مع الطالب
  final List<String> targetHalaqaIds;
  final List<String> targetStudentIds;
  final int costPoints;

  const AddTripEvent({
    required this.mosqueId,
    required this.title,
    required this.destination,
    required this.tripDate,
    this.meetingTime = '08:00 صباحاً',
    this.deadlineDate,
    this.description,
    this.requiredItems = 'لباس مريح، مصحف جيب، مياه وطعام خفيف 🎒',
    this.targetHalaqaIds = const [],
    this.targetStudentIds = const [],
    this.costPoints = 0,
  });

  @override
  List<Object?> get props => [
        mosqueId,
        title,
        destination,
        tripDate,
        meetingTime,
        deadlineDate,
        description,
        requiredItems,
        targetHalaqaIds,
        targetStudentIds,
        costPoints,
      ];
}

/// Update trip details
class UpdateTripEvent extends TripsEvent {
  final Trip trip;

  const UpdateTripEvent(this.trip);

  @override
  List<Object?> get props => [trip];
}

/// Change trip status ('upcoming', 'completed', 'cancelled')
class UpdateTripStatusEvent extends TripsEvent {
  final String tripId;
  final String status;

  const UpdateTripStatusEvent({
    required this.tripId,
    required this.status,
  });

  @override
  List<Object?> get props => [tripId, status];
}

/// Delete a trip
class DeleteTripEvent extends TripsEvent {
  final String tripId;

  const DeleteTripEvent(this.tripId);

  @override
  List<Object?> get props => [tripId];
}
