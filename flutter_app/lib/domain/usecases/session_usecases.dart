import '../../models/models.dart';
import '../repositories/mosque_repository.dart';

/// Use case for retrieving saved sessions and current active session.
class GetSessionsUseCase {
  final MosqueRepository _repository;

  const GetSessionsUseCase(this._repository);

  List<ActiveSession> call() => _repository.savedSessions;

  ActiveSession? get currentSession => _repository.currentSession;

  ActiveSession? getSessionForRole(String role) =>
      _repository.getSessionForRole(role);

  bool hasRole(String role) => _repository.hasRole(role);
}

/// Use case for setting/switching active role sessions.
class SetSessionUseCase {
  final MosqueRepository _repository;

  const SetSessionUseCase(this._repository);

  void call(ActiveSession session) => _repository.setRoleSession(session);

  void switchSession(ActiveSession session) =>
      _repository.switchSession(session);
}

/// Use case for disconnecting a role session or clearing active sessions.
class DisconnectSessionUseCase {
  final MosqueRepository _repository;

  const DisconnectSessionUseCase(this._repository);

  void call(String role) => _repository.disconnectRole(role);

  void clearSession() => _repository.clearSession();
}

/// Use case for verifying an access code (QR or PIN) across hierarchy.
class VerifyAccessCodeUseCase {
  final MosqueRepository _repository;

  const VerifyAccessCodeUseCase(this._repository);

  Future<ActiveSession?> call(String code) => _repository.verifyCode(code);
}
