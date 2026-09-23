import 'package:equatable/equatable.dart';
import '../../../models/models.dart';

enum TripsStatus {
  initial,
  loading,
  loaded,
  success,
  error,
}

class TripsState extends Equatable {
  final TripsStatus status;
  final List<Trip> allTrips;
  final List<Trip> filteredTrips;
  final String? selectedHalaqaId;
  final String? selectedStudentId;
  final String selectedStatus; // 'all', 'upcoming', 'completed', 'cancelled'
  final String? searchQuery;
  final String? errorMessage;
  final String? successMessage;

  const TripsState({
    this.status = TripsStatus.initial,
    this.allTrips = const [],
    this.filteredTrips = const [],
    this.selectedHalaqaId,
    this.selectedStudentId,
    this.selectedStatus = 'all',
    this.searchQuery,
    this.errorMessage,
    this.successMessage,
  });

  factory TripsState.initial() => const TripsState();

  // Helper Getters
  List<Trip> get upcomingTrips =>
      allTrips.where((t) => t.isUpcoming).toList();

  List<Trip> get completedTrips =>
      allTrips.where((t) => t.status == 'completed').toList();

  List<Trip> get cancelledTrips =>
      allTrips.where((t) => t.status == 'cancelled').toList();

  int get totalCount => allTrips.length;
  int get upcomingCount => upcomingTrips.length;

  TripsState copyWith({
    TripsStatus? status,
    List<Trip>? allTrips,
    List<Trip>? filteredTrips,
    String? Function()? selectedHalaqaId,
    String? Function()? selectedStudentId,
    String? selectedStatus,
    String? Function()? searchQuery,
    String? Function()? errorMessage,
    String? Function()? successMessage,
  }) {
    return TripsState(
      status: status ?? this.status,
      allTrips: allTrips ?? this.allTrips,
      filteredTrips: filteredTrips ?? this.filteredTrips,
      selectedHalaqaId: selectedHalaqaId != null
          ? selectedHalaqaId()
          : this.selectedHalaqaId,
      selectedStudentId: selectedStudentId != null
          ? selectedStudentId()
          : this.selectedStudentId,
      selectedStatus: selectedStatus ?? this.selectedStatus,
      searchQuery:
          searchQuery != null ? searchQuery() : this.searchQuery,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
      successMessage:
          successMessage != null ? successMessage() : this.successMessage,
    );
  }

  @override
  List<Object?> get props => [
        status,
        allTrips,
        filteredTrips,
        selectedHalaqaId,
        selectedStudentId,
        selectedStatus,
        searchQuery,
        errorMessage,
        successMessage,
      ];
}
