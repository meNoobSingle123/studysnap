import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:local_auth/local_auth.dart';

import '../../l10n/strings.dart';
import '../auth_lock_listenable.dart';
import 'auth_lock_event.dart';
import 'auth_lock_state.dart';

/// BLoC quản lý trạng thái khóa sinh trắc học và thời gian khóa nền 60s
/// theo đặc tả CĐ 11 (mục 6.2, 7.1, 8.2).
class AuthLockBloc extends Bloc<AuthLockEvent, AuthLockState> {
  final LocalAuthentication localAuth;
  final Duration backgroundLockTimeout;

  DateTime? _backgroundTimestamp;

  AuthLockBloc({
    LocalAuthentication? localAuth,
    this.backgroundLockTimeout = const Duration(seconds: 60),
  })  : localAuth = localAuth ?? LocalAuthentication(),
        super(const AuthLocked()) {
    on<CheckAuthStatus>(_onCheckAuthStatus);
    on<AuthenticateWithBiometrics>(_onAuthenticateWithBiometrics);
    on<LockApp>(_onLockApp);
    on<UnlockApp>(_onUnlockApp);
    on<AppEnteredBackground>(_onAppEnteredBackground);
    on<AppResumed>(_onAppResumed);
  }

  @override
  void onChange(Change<AuthLockState> change) {
    super.onChange(change);
    AuthLockListenable.instance
        .updateLockState(change.nextState is AuthLocked);
  }

  Future<void> _onCheckAuthStatus(
    CheckAuthStatus event,
    Emitter<AuthLockState> emit,
  ) async {
    try {
      final isSupported = await localAuth.isDeviceSupported();
      final canCheck = await localAuth.canCheckBiometrics;

      if (!isSupported && !canCheck) {
        emit(const BiometricsNotAvailable());
      } else {
        emit(const AuthLocked());
      }
    } catch (_) {
      emit(const AuthLocked());
    }
  }

  Future<void> _onAuthenticateWithBiometrics(
    AuthenticateWithBiometrics event,
    Emitter<AuthLockState> emit,
  ) async {
    try {
      final isSupported = await localAuth.isDeviceSupported();
      final canCheck = await localAuth.canCheckBiometrics;

      if (!isSupported && !canCheck) {
        emit(const BiometricsNotAvailable());
        return;
      }

      emit(const AuthLocked(isAuthenticating: true));

      final didAuthenticate = await localAuth.authenticate(
        localizedReason: AppStrings.biometricsPrompt,
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );

      if (didAuthenticate) {
        emit(const AuthUnlocked());
      } else {
        emit(const AuthLocked(
          errorMessage: AppStrings.biometricsFailed,
        ));
      }
    } catch (e) {
      emit(const AuthLocked(
        errorMessage: AppStrings.biometricsFailed,
      ));
    }
  }

  void _onLockApp(LockApp event, Emitter<AuthLockState> emit) {
    emit(const AuthLocked());
  }

  void _onUnlockApp(UnlockApp event, Emitter<AuthLockState> emit) {
    emit(const AuthUnlocked());
  }

  void _onAppEnteredBackground(
    AppEnteredBackground event,
    Emitter<AuthLockState> emit,
  ) {
    _backgroundTimestamp = event.timestamp ?? DateTime.now();
  }

  void _onAppResumed(
    AppResumed event,
    Emitter<AuthLockState> emit,
  ) {
    if (_backgroundTimestamp != null) {
      final now = event.timestamp ?? DateTime.now();
      final diff = now.difference(_backgroundTimestamp!);
      if (diff >= backgroundLockTimeout) {
        emit(const AuthLocked());
      }
      _backgroundTimestamp = null;
    }
  }
}
