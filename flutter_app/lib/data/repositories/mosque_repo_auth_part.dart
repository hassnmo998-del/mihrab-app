part of 'mosque_repository_impl.dart';

/// Authentication and multi-role session delegation mixin.
mixin MosqueRepoAuthMixin implements AuthSessionRepository {
  AuthSessionRepositoryImpl get authSessionRepository;

  @override
  ActiveSession? get currentSession => authSessionRepository.currentSession;

  @override
  List<ActiveSession> get savedSessions => authSessionRepository.savedSessions;

  @override
  void switchSession(ActiveSession session) =>
      authSessionRepository.switchSession(session);

  @override
  void setRoleSession(ActiveSession session) =>
      authSessionRepository.setRoleSession(session);

  @override
  ActiveSession? getSessionForRole(String role) =>
      authSessionRepository.getSessionForRole(role);

  @override
  bool hasRole(String role) => authSessionRepository.hasRole(role);

  @override
  void disconnectRole(String role) =>
      authSessionRepository.disconnectRole(role);

  @override
  void clearSession() => authSessionRepository.clearSession();

  @override
  Future<ActiveSession?> verifyCode(String code) =>
      authSessionRepository.verifyCode(code);

  @override
  void validateActiveSessions() =>
      authSessionRepository.validateActiveSessions();
}
