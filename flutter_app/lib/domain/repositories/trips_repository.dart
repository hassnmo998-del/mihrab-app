import '../../models/models.dart';

/// Contract for Trips and Outings management with student targeting and baggage checklist.
abstract class TripsRepository {
  List<Trip> getTrips({String? mosqueId, String? studentId, String? halaqaId});
  Trip addTrip({
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
  });
  void updateTrip(Trip trip);
  void deleteTrip(String tripId);
}
