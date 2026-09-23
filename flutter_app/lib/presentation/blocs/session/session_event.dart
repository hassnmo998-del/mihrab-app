import 'package:equatable/equatable.dart';
import '../../../models/models.dart';

abstract class SessionEvent extends Equatable {
  const SessionEvent();

  @override
  List<Object?> get props => [];
}

/// Load currently active session and all saved multi-role sessions from storage
class LoadSessionsEvent extends SessionEvent {
  const LoadSessionsEvent();
}

/// Switch active role to another saved session without auto-logout
class SwitchSessionEvent extends SessionEvent {
  final ActiveSession session;

  const SwitchSessionEvent(this.session);

  @override
  List<Object?> get props => [session];
}

/// Set or update the active session for a specific role
class SetRoleSessionEvent extends SessionEvent {
  final ActiveSession session;

  const SetRoleSessionEvent(this.session);

  @override
  List<Object?> get props => [session];
}

/// Verify an access code or QR scan string (e.g., MSQ-*, SHK-*, STD-*, CSH-*)
class VerifyAccessCodeEvent extends SessionEvent {
  final String code;

  const VerifyAccessCodeEvent(this.code);

  @override
  List<Object?> get props => [code];
}

/// Disconnect/remove a specific role session without logging out other roles
class DisconnectRoleEvent extends SessionEvent {
  final String role;

  const DisconnectRoleEvent(this.role);

  @override
  List<Object?> get props => [role];
}

/// Clear active session and return to visitor mode without erasing saved roles
class ClearActiveSessionEvent extends SessionEvent {
  const ClearActiveSessionEvent();
}

/// Completely clear all sessions (hard reset / full logout)
class LogoutAllSessionsEvent extends SessionEvent {
  const LogoutAllSessionsEvent();
}

/// Refresh session details after underlying data changes
class RefreshSessionEvent extends SessionEvent {
  const RefreshSessionEvent();
}
