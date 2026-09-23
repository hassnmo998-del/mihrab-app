import '../../models/models.dart';

/// Contract for multi-role persistent sessions and authentication verification.
abstract class AuthSessionRepository {
  ActiveSession? get currentSession;
  List<ActiveSession> get savedSessions;
  void switchSession(ActiveSession session);
  void setRoleSession(ActiveSession session);
  ActiveSession? getSessionForRole(String role);
  bool hasRole(String role);
  void disconnectRole(String role);
  void clearSession();
  /// Resolves a scanned/typed code into a session. Women's-branch provisioning
  /// tokens resolve to null here on purpose: they are redeemed through the
  /// provisioning flow, never used as login credentials.
  Future<ActiveSession?> verifyCode(String code);
  void validateActiveSessions();
}
