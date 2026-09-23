import '../../models/models.dart';
import '../repositories/mosque_repository.dart';

/// Use case for querying trips and outings filtered by mosque, student, or halaqa.
class GetTripsUseCase {
  final MosqueRepository _repository;

  const GetTripsUseCase(this._repository);

  List<Trip> call({String? mosqueId, String? studentId, String? halaqaId}) {
    return _repository.getTrips(
      mosqueId: mosqueId,
      studentId: studentId,
      halaqaId: halaqaId,
    );
  }
}

/// Use case for creating a new educational or recreational trip.
class AddTripUseCase {
  final MosqueRepository _repository;

  const AddTripUseCase(this._repository);

  Trip call({
    required String mosqueId,
    required String title,
    required String destination,
    required DateTime tripDate,
    String meetingTime = '08:00 صباحاً',
    DateTime? deadlineDate,
    String? description,
    String requiredItems = 'لباس مريح، مصحف جيب، مياه وطعام خفيف',
    List<String> targetHalaqaIds = const [],
    List<String> targetStudentIds = const [],
    int costPoints = 0,
  }) {
    return _repository.addTrip(
      mosqueId: mosqueId,
      title: title,
      destination: destination,
      tripDate: tripDate,
      meetingTime: meetingTime,
      deadlineDate: deadlineDate,
      description: description,
      requiredItems: requiredItems,
      targetHalaqaIds: targetHalaqaIds,
      targetStudentIds: targetStudentIds,
      costPoints: costPoints,
    );
  }
}

/// Use case for updating trip details.
class UpdateTripUseCase {
  final MosqueRepository _repository;

  const UpdateTripUseCase(this._repository);

  void call(Trip trip) => _repository.updateTrip(trip);
}

/// Use case for deleting a trip.
class DeleteTripUseCase {
  final MosqueRepository _repository;

  const DeleteTripUseCase(this._repository);

  void call(String tripId) => _repository.deleteTrip(tripId);
}
