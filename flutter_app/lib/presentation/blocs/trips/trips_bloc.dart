import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../models/models.dart';
import '../../../services/data_service.dart';
import 'trips_event.dart';
import 'trips_state.dart';

class TripsBloc extends Bloc<TripsEvent, TripsState> {
  final DataService _dataService;

  TripsBloc({DataService? dataService})
      : _dataService = dataService ?? DataService(),
        super(TripsState.initial()) {
    on<LoadTripsEvent>(_onLoadTrips);
    on<FilterTripsEvent>(_onFilterTrips);
    on<AddTripEvent>(_onAddTrip);
    on<UpdateTripEvent>(_onUpdateTrip);
    on<UpdateTripStatusEvent>(_onUpdateTripStatus);
    on<DeleteTripEvent>(_onDeleteTrip);
  }

  void _onLoadTrips(LoadTripsEvent event, Emitter<TripsState> emit) {
    emit(state.copyWith(status: TripsStatus.loading));

    try {
      final trips = _dataService.getTrips(
        mosqueId: event.mosqueId,
        studentId: event.studentId,
        halaqaId: event.halaqaId,
      );

      final filtered = _applyFilters(
        trips: trips,
        halaqaId: event.halaqaId ?? state.selectedHalaqaId,
        studentId: event.studentId ?? state.selectedStudentId,
        status: state.selectedStatus,
        query: state.searchQuery,
      );

      emit(state.copyWith(
        status: TripsStatus.loaded,
        allTrips: trips,
        filteredTrips: filtered,
        selectedHalaqaId: () => event.halaqaId ?? state.selectedHalaqaId,
        selectedStudentId: () => event.studentId ?? state.selectedStudentId,
        errorMessage: () => null,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: TripsStatus.error,
        errorMessage: () => 'فشل في تحميل قائمة الرحلات: ${e.toString()}',
      ));
    }
  }

  void _onFilterTrips(FilterTripsEvent event, Emitter<TripsState> emit) {
    final newHalaqa = event.halaqaId ?? state.selectedHalaqaId;
    final newStudent = event.studentId ?? state.selectedStudentId;
    final newStatus = event.status ?? state.selectedStatus;
    final newQuery = event.searchQuery ?? state.searchQuery;

    final filtered = _applyFilters(
      trips: state.allTrips,
      halaqaId: newHalaqa,
      studentId: newStudent,
      status: newStatus,
      query: newQuery,
    );

    emit(state.copyWith(
      filteredTrips: filtered,
      selectedHalaqaId: () => newHalaqa,
      selectedStudentId: () => newStudent,
      selectedStatus: newStatus,
      searchQuery: () => newQuery,
    ));
  }

  void _onAddTrip(AddTripEvent event, Emitter<TripsState> emit) {
    try {
      final trip = _dataService.addTrip(
        mosqueId: event.mosqueId,
        title: event.title,
        destination: event.destination,
        tripDate: event.tripDate,
        meetingTime: event.meetingTime,
        deadlineDate: event.deadlineDate,
        description: event.description,
        requiredItems: event.requiredItems,
        targetHalaqaIds: event.targetHalaqaIds,
        targetStudentIds: event.targetStudentIds,
        costPoints: event.costPoints,
      );

      final trips = _dataService.getTrips();
      final filtered = _applyFilters(
        trips: trips,
        halaqaId: state.selectedHalaqaId,
        studentId: state.selectedStudentId,
        status: state.selectedStatus,
        query: state.searchQuery,
      );

      emit(state.copyWith(
        status: TripsStatus.success,
        allTrips: trips,
        filteredTrips: filtered,
        successMessage: () =>
            'تمت جدولة الرحلة "${trip.title}" بنجاح مع المتطلبات المحددة 🎒',
        errorMessage: () => null,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: TripsStatus.error,
        errorMessage: () => 'فشل في إضافة الرحلة: ${e.toString()}',
      ));
    }
  }

  void _onUpdateTrip(UpdateTripEvent event, Emitter<TripsState> emit) {
    try {
      _dataService.updateTrip(event.trip);
      final trips = _dataService.getTrips();
      final filtered = _applyFilters(
        trips: trips,
        halaqaId: state.selectedHalaqaId,
        studentId: state.selectedStudentId,
        status: state.selectedStatus,
        query: state.searchQuery,
      );

      emit(state.copyWith(
        status: TripsStatus.success,
        allTrips: trips,
        filteredTrips: filtered,
        successMessage: () => 'تم تحديث بيانات الرحلة بنجاح',
        errorMessage: () => null,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: TripsStatus.error,
        errorMessage: () => 'فشل في تحديث بيانات الرحلة: ${e.toString()}',
      ));
    }
  }

  void _onUpdateTripStatus(
      UpdateTripStatusEvent event, Emitter<TripsState> emit) {
    try {
      final trip = state.allTrips.firstWhere((t) => t.id == event.tripId);
      final updated = trip.copyWith(status: event.status);
      _dataService.updateTrip(updated);

      final trips = _dataService.getTrips();
      final filtered = _applyFilters(
        trips: trips,
        halaqaId: state.selectedHalaqaId,
        studentId: state.selectedStudentId,
        status: state.selectedStatus,
        query: state.searchQuery,
      );

      emit(state.copyWith(
        status: TripsStatus.success,
        allTrips: trips,
        filteredTrips: filtered,
        successMessage: () => 'تم تغيير حالة الرحلة إلى ${event.status}',
        errorMessage: () => null,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: TripsStatus.error,
        errorMessage: () => 'فشل في تغيير حالة الرحلة: ${e.toString()}',
      ));
    }
  }

  void _onDeleteTrip(DeleteTripEvent event, Emitter<TripsState> emit) {
    try {
      _dataService.deleteTrip(event.tripId);
      final trips = _dataService.getTrips();
      final filtered = _applyFilters(
        trips: trips,
        halaqaId: state.selectedHalaqaId,
        studentId: state.selectedStudentId,
        status: state.selectedStatus,
        query: state.searchQuery,
      );

      emit(state.copyWith(
        status: TripsStatus.success,
        allTrips: trips,
        filteredTrips: filtered,
        successMessage: () => 'تم حذف الرحلة بنجاح',
        errorMessage: () => null,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: TripsStatus.error,
        errorMessage: () => 'فشل في حذف الرحلة: ${e.toString()}',
      ));
    }
  }

  List<Trip> _applyFilters({
    required List<Trip> trips,
    String? halaqaId,
    String? studentId,
    String? status,
    String? query,
  }) {
    var list = trips;

    // Halaqa filter
    if (halaqaId != null && halaqaId.isNotEmpty && halaqaId != 'all') {
      list = list
          .where((t) =>
              t.targetHalaqaIds.isEmpty || t.targetHalaqaIds.contains(halaqaId))
          .toList();
    }

    // Student filter
    if (studentId != null && studentId.isNotEmpty && studentId != 'all') {
      list = list.where((t) {
        if (t.targetStudentIds.isEmpty && t.targetHalaqaIds.isEmpty) return true;
        return t.targetStudentIds.contains(studentId);
      }).toList();
    }

    // Status filter
    if (status != null && status != 'all') {
      if (status == 'upcoming') {
        list = list.where((t) => t.isUpcoming).toList();
      } else {
        list = list.where((t) => t.status == status).toList();
      }
    }

    // Search query
    if (query != null && query.trim().isNotEmpty) {
      final q = query.trim().toLowerCase();
      list = list
          .where((t) =>
              t.title.toLowerCase().contains(q) ||
              t.destination.toLowerCase().contains(q) ||
              t.requiredItems.toLowerCase().contains(q) ||
              (t.description?.toLowerCase().contains(q) ?? false))
          .toList();
    }

    return list;
  }
}
