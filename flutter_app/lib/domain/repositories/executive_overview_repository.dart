/// Contract for Executive Oversight Matrix across students, halaqat, and sheikhs.
abstract class ExecutiveOverviewRepository {
  List<Map<String, dynamic>> getExecutiveOverview({
    String? mosqueId,
    String? sheikhId,
    String? halaqaId,
    String? searchQuery,
    DateTime? date,
  });
}
