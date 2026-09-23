import 'package:equatable/equatable.dart';
import '../../../models/models.dart';

enum SessionStatus {
  initial,
  loading,
  authenticated,
  visitor,
  codeVerified,
  error,
}

class SessionState extends Equatable {
  final SessionStatus status;
  final ActiveSession? currentSession;
  final List<ActiveSession> savedSessions;
  /// Branch the signed-in user belongs to ('male' | 'female'). Anonymous
  /// visitors are treated as 'male' so women's content is never exposed.
  final String viewerBranch;
  final String? errorMessage;
  final String? successMessage;

  const SessionState({
    this.status = SessionStatus.initial,
    this.currentSession,
    this.savedSessions = const [],
    this.viewerBranch = 'male',
    this.errorMessage,
    this.successMessage,
  });

  factory SessionState.initial() => const SessionState();

  factory SessionState.visitor({List<ActiveSession> savedSessions = const []}) => SessionState(
        status: SessionStatus.visitor,
        currentSession: null,
        savedSessions: savedSessions,
      );

  // Convenience Role Getters
  String get role => currentSession?.role ?? 'visitor';
  String get roleLabel => currentSession?.roleLabel ?? 'زائر عام';
  bool get isVisitor => currentSession == null || currentSession!.role == 'visitor';
  bool get isAdmin => currentSession?.role == 'mosque_admin';
  bool get isSheikh => currentSession?.role == 'sheikh';
  bool get isStudent => currentSession?.role == 'student';
  bool get isCashier => currentSession?.role == 'cashier';
  bool get hasMultipleRoles => savedSessions.length > 1;

  // Active Context IDs
  String? get activeMosqueId => currentSession?.mosqueId;
  String? get activeHalaqaId => currentSession?.halaqaId;
  String? get activeStudentId => currentSession?.studentId;
  String? get activeSheikhId => currentSession?.sheikhId;
  String? get sessionName => currentSession?.name;

  ActiveSession? getSessionForRole(String role) {
    if (currentSession?.role == role) return currentSession;
    for (final s in savedSessions) {
      if (s.role == role) return s;
    }
    return null;
  }

  bool hasRole(String role) => getSessionForRole(role) != null;

  SessionState copyWith({
    SessionStatus? status,
    ActiveSession? Function()? currentSession,
    List<ActiveSession>? savedSessions,
    String? viewerBranch,
    String? Function()? errorMessage,
    String? Function()? successMessage,
  }) {
    return SessionState(
      status: status ?? this.status,
      currentSession: currentSession != null ? currentSession() : this.currentSession,
      savedSessions: savedSessions ?? this.savedSessions,
      viewerBranch: viewerBranch ?? this.viewerBranch,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
      successMessage: successMessage != null ? successMessage() : this.successMessage,
    );
  }

  @override
  List<Object?> get props => [
        status,
        currentSession,
        savedSessions,
        viewerBranch,
        errorMessage,
        successMessage,
      ];
}
