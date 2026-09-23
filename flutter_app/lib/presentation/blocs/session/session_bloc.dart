import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../services/data_service.dart';
import 'session_event.dart';
import 'session_state.dart';

class SessionBloc extends Bloc<SessionEvent, SessionState> {
  final DataService _dataService;

  SessionBloc({DataService? dataService})
      : _dataService = dataService ?? DataService(),
        super(SessionState.initial()) {
    on<LoadSessionsEvent>(_onLoadSessions);
    on<SwitchSessionEvent>(_onSwitchSession);
    on<SetRoleSessionEvent>(_onSetRoleSession);
    on<VerifyAccessCodeEvent>(_onVerifyAccessCode);
    on<DisconnectRoleEvent>(_onDisconnectRole);
    on<ClearActiveSessionEvent>(_onClearActiveSession);
    on<LogoutAllSessionsEvent>(_onLogoutAllSessions);
    on<RefreshSessionEvent>(_onRefreshSession);

    // Initial load
    add(const LoadSessionsEvent());
  }

  void _onLoadSessions(LoadSessionsEvent event, Emitter<SessionState> emit) {
    emit(state.copyWith(status: SessionStatus.loading));

    final current = _dataService.currentSession;
    final saved = _dataService.savedSessions;
    final branch = _dataService.branchOfSession(current);

    if (current != null) {
      emit(state.copyWith(
        status: SessionStatus.authenticated,
        currentSession: () => current,
        savedSessions: saved,
        viewerBranch: branch,
        errorMessage: () => null,
      ));
    } else {
      emit(state.copyWith(
        status: SessionStatus.visitor,
        currentSession: () => null,
        savedSessions: saved,
        viewerBranch: branch,
        errorMessage: () => null,
      ));
    }
  }

  void _onSwitchSession(SwitchSessionEvent event, Emitter<SessionState> emit) {
    _dataService.switchSession(event.session);
    final saved = _dataService.savedSessions;
    final branch = _dataService.branchOfSession(event.session);

    emit(state.copyWith(
      status: SessionStatus.authenticated,
      currentSession: () => event.session,
      savedSessions: saved,
      viewerBranch: branch,
      successMessage: () => 'تم التبديل إلى حساب ${event.session.name}',
      errorMessage: () => null,
    ));
  }

  void _onSetRoleSession(SetRoleSessionEvent event, Emitter<SessionState> emit) {
    _dataService.setRoleSession(event.session);
    final saved = _dataService.savedSessions;
    final branch = _dataService.branchOfSession(event.session);

    emit(state.copyWith(
      status: SessionStatus.authenticated,
      currentSession: () => event.session,
      savedSessions: saved,
      viewerBranch: branch,
      successMessage: () => 'تم حفظ دور ${event.session.roleLabel}',
      errorMessage: () => null,
    ));
  }

  Future<void> _onVerifyAccessCode(
      VerifyAccessCodeEvent event, Emitter<SessionState> emit) async {
    emit(state.copyWith(status: SessionStatus.loading));

    try {
      final session = await _dataService.verifyCode(event.code);
      if (session != null) {
        final saved = _dataService.savedSessions;
        final branch = _dataService.branchOfSession(session);

        emit(state.copyWith(
          status: SessionStatus.codeVerified,
          currentSession: () => session,
          savedSessions: saved,
          viewerBranch: branch,
          successMessage: () => 'تم التحقق وتفعيل الحساب: ${session.name}',
          errorMessage: () => null,
        ));

        emit(state.copyWith(
          status: SessionStatus.authenticated,
        ));
      } else {
        emit(state.copyWith(
          status: SessionStatus.error,
          errorMessage: () => 'الرمز المدخل غير صالح أو غير مرتبط بأي مسجد أو حلقة أو طالب',
        ));
      }
    } catch (e) {
      emit(state.copyWith(
        status: SessionStatus.error,
        errorMessage: () => 'حدث خطأ أثناء التحقق من الرمز: ${e.toString()}',
      ));
    }
  }

  void _onDisconnectRole(DisconnectRoleEvent event, Emitter<SessionState> emit) {
    _dataService.disconnectRole(event.role);
    final current = _dataService.currentSession;
    final saved = _dataService.savedSessions;

    if (current != null) {
      emit(state.copyWith(
        status: SessionStatus.authenticated,
        currentSession: () => current,
        savedSessions: saved,
        successMessage: () => 'تم إلغاء تفعيل الدور بنجاح',
        errorMessage: () => null,
      ));
    } else {
      emit(state.copyWith(
        status: SessionStatus.visitor,
        currentSession: () => null,
        savedSessions: saved,
        successMessage: () => 'تم إلغاء تفعيل الدور، العودة لوضع الزائر',
        errorMessage: () => null,
      ));
    }
  }

  void _onClearActiveSession(ClearActiveSessionEvent event, Emitter<SessionState> emit) {
    _dataService.clearSession();
    emit(state.copyWith(
      status: SessionStatus.visitor,
      currentSession: () => null,
      savedSessions: _dataService.savedSessions,
      successMessage: () => 'تم التحويل إلى وضع الزائر العام',
      errorMessage: () => null,
    ));
  }

  void _onLogoutAllSessions(LogoutAllSessionsEvent event, Emitter<SessionState> emit) {
    for (final s in List.from(_dataService.savedSessions)) {
      _dataService.disconnectRole(s.role);
    }
    _dataService.clearSession();

    emit(state.copyWith(
      status: SessionStatus.visitor,
      currentSession: () => null,
      savedSessions: const [],
      viewerBranch: 'male',
      successMessage: () => 'تم تسجيل الخروج من كافة الحسابات المحفوظة',
      errorMessage: () => null,
    ));
  }

  void _onRefreshSession(RefreshSessionEvent event, Emitter<SessionState> emit) {
    final current = _dataService.currentSession;
    final saved = _dataService.savedSessions;
    final branch = _dataService.branchOfSession(current);

    emit(state.copyWith(
      currentSession: () => current,
      savedSessions: saved,
      viewerBranch: branch,
    ));
  }
}
