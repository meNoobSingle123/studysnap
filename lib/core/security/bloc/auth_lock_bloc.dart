import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:local_auth/local_auth.dart';

import '../../di/injection.dart';
import '../../l10n/strings.dart';
import '../auth_lock_listenable.dart';
import '../key_storage_service.dart';
import 'auth_lock_event.dart';
import 'auth_lock_state.dart';

/// BLoC quản lý trạng thái khóa sinh trắc học và thời gian khóa nền 60s
/// theo đặc tả CĐ 11 (mục 6.2, 7.1, 8.2).
class AuthLockBloc extends Bloc<AuthLockEvent, AuthLockState> {
  final LocalAuthentication localAuth;
  final Duration backgroundLockTimeout;
  final KeyStorageService keyStorage;

  DateTime? _backgroundTimestamp;

  AuthLockBloc({
    LocalAuthentication? localAuth,
    KeyStorageService? keyStorage,
    this.backgroundLockTimeout = const Duration(seconds: 60),
  })  : localAuth = localAuth ?? LocalAuthentication(),
        keyStorage = keyStorage ??
            (getIt.isRegistered<KeyStorageService>()
                ? getIt<KeyStorageService>()
                : KeyStorageService()),
        super(const AuthLocked()) {
    on<CheckAuthStatus>(_onCheckAuthStatus);
    on<AuthenticateWithBiometrics>(_onAuthenticateWithBiometrics);
    on<LockApp>(_onLockApp);
    on<UnlockApp>(_onUnlockApp);
    on<AppEnteredBackground>(_onAppEnteredBackground);
    on<AppResumed>(_onAppResumed);
    on<SubmitPin>(_onSubmitPin);
    on<SetupPin>(_onSetupPin);
    on<ResetPin>(_onResetPin);
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

  Future<void> _onSubmitPin(
    SubmitPin event,
    Emitter<AuthLockState> emit,
  ) async {
    // 1. Kiểm tra lockout (khóa tạm)
    final lockout = await keyStorage.getLockoutUntil();
    if (lockout != null) {
      final secondsLeft = lockout.difference(DateTime.now()).inSeconds;
      emit(AuthLocked(
        isPinMode: true,
        errorMessage:
            'Đã nhập sai quá nhiều lần. Vui lòng thử lại sau $secondsLeft giây.',
        lockoutUntil: lockout,
        failedAttempts: await keyStorage.getFailedPinAttempts(),
      ));
      return;
    }

    // 2. Lấy PIN đã lưu
    final savedPin = await keyStorage.getPin();
    if (savedPin == null || savedPin.isEmpty) {
      emit(const AuthLocked(
        isPinMode: true,
        errorMessage: 'Chưa thiết lập mã PIN. Vui lòng tạo mã PIN mới.',
      ));
      return;
    }

    // 3. So khớp PIN
    if (event.pin == savedPin) {
      await keyStorage.resetFailedPinAttempts();
      await keyStorage.clearLockout();
      emit(const AuthUnlocked());
    } else {
      final attempts = await keyStorage.incrementFailedPinAttempts();
      if (attempts >= 5) {
        final lockUntil = DateTime.now().add(const Duration(seconds: 30));
        await keyStorage.setLockoutUntil(lockUntil);
        emit(AuthLocked(
          isPinMode: true,
          errorMessage: 'Nhập sai 5 lần! Ứng dụng tạm khóa 30 giây.',
          lockoutUntil: lockUntil,
          failedAttempts: attempts,
        ));
      } else {
        final left = 5 - attempts;
        emit(AuthLocked(
          isPinMode: true,
          errorMessage: 'Mã PIN không đúng. Bạn còn $left lần thử.',
          failedAttempts: attempts,
        ));
      }
    }
  }

  Future<void> _onSetupPin(
    SetupPin event,
    Emitter<AuthLockState> emit,
  ) async {
    if (event.pin.length >= 4) {
      await keyStorage.setPin(event.pin);
      await keyStorage.resetFailedPinAttempts();
      await keyStorage.clearLockout();
      emit(const AuthUnlocked());
    } else {
      emit(const AuthLocked(
        isPinMode: true,
        errorMessage: 'Mã PIN phải có ít nhất 4 chữ số.',
      ));
    }
  }

  Future<void> _onResetPin(
    ResetPin event,
    Emitter<AuthLockState> emit,
  ) async {
    await keyStorage.clearPin();
    await keyStorage.resetFailedPinAttempts();
    await keyStorage.clearLockout();
    emit(const AuthLocked(
      isPinMode: true,
      errorMessage: 'Đã xóa mã PIN cũ. Vui lòng tạo mã PIN mới.',
    ));
  }
}
