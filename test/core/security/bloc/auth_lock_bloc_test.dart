import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nhom_7/core/l10n/strings.dart';
import 'package:nhom_7/core/security/bloc/auth_lock_bloc.dart';
import 'package:nhom_7/core/security/bloc/auth_lock_event.dart';
import 'package:nhom_7/core/security/bloc/auth_lock_state.dart';

class MockLocalAuthentication extends Mock implements LocalAuthentication {}

void main() {
  late MockLocalAuthentication mockLocalAuth;

  setUp(() {
    mockLocalAuth = MockLocalAuthentication();
  });

  group('AuthLockBloc', () {
    test('initial state is AuthLocked', () {
      final bloc = AuthLockBloc(localAuth: mockLocalAuth);
      expect(bloc.state, equals(const AuthLocked()));
      bloc.close();
    });

    blocTest<AuthLockBloc, AuthLockState>(
      'emits [BiometricsNotAvailable] when device does not support biometrics',
      build: () {
        when(() => mockLocalAuth.isDeviceSupported())
            .thenAnswer((_) async => false);
        when(() => mockLocalAuth.canCheckBiometrics)
            .thenAnswer((_) async => false);
        return AuthLockBloc(localAuth: mockLocalAuth);
      },
      act: (bloc) => bloc.add(const CheckAuthStatus()),
      expect: () => [
        const BiometricsNotAvailable(),
      ],
    );

    blocTest<AuthLockBloc, AuthLockState>(
      'emits [AuthLocked] when device supports biometrics',
      build: () {
        when(() => mockLocalAuth.isDeviceSupported())
            .thenAnswer((_) async => true);
        when(() => mockLocalAuth.canCheckBiometrics)
            .thenAnswer((_) async => true);
        return AuthLockBloc(localAuth: mockLocalAuth);
      },
      act: (bloc) => bloc.add(const CheckAuthStatus()),
      expect: () => [
        const AuthLocked(),
      ],
    );

    blocTest<AuthLockBloc, AuthLockState>(
      'emits [AuthLocked(isAuthenticating: true), AuthUnlocked] on successful biometric authentication',
      build: () {
        when(() => mockLocalAuth.isDeviceSupported())
            .thenAnswer((_) async => true);
        when(() => mockLocalAuth.canCheckBiometrics)
            .thenAnswer((_) async => true);
        when(() => mockLocalAuth.authenticate(
              localizedReason: any(named: 'localizedReason'),
              biometricOnly: any(named: 'biometricOnly'),
              persistAcrossBackgrounding:
                  any(named: 'persistAcrossBackgrounding'),
            )).thenAnswer((_) async => true);
        return AuthLockBloc(localAuth: mockLocalAuth);
      },
      act: (bloc) => bloc.add(const AuthenticateWithBiometrics()),
      expect: () => [
        const AuthLocked(isAuthenticating: true),
        const AuthUnlocked(),
      ],
    );

    blocTest<AuthLockBloc, AuthLockState>(
      'emits [AuthLocked(isAuthenticating: true), AuthLocked(errorMessage: ...)] when authentication fails',
      build: () {
        when(() => mockLocalAuth.isDeviceSupported())
            .thenAnswer((_) async => true);
        when(() => mockLocalAuth.canCheckBiometrics)
            .thenAnswer((_) async => true);
        when(() => mockLocalAuth.authenticate(
              localizedReason: any(named: 'localizedReason'),
              biometricOnly: any(named: 'biometricOnly'),
              persistAcrossBackgrounding:
                  any(named: 'persistAcrossBackgrounding'),
            )).thenAnswer((_) async => false);
        return AuthLockBloc(localAuth: mockLocalAuth);
      },
      act: (bloc) => bloc.add(const AuthenticateWithBiometrics()),
      expect: () => [
        const AuthLocked(isAuthenticating: true),
        const AuthLocked(errorMessage: AppStrings.biometricsFailed),
      ],
    );

    blocTest<AuthLockBloc, AuthLockState>(
      'emits [AuthLocked(isAuthenticating: true), AuthLocked(errorMessage: ...)] when authenticate throws',
      build: () {
        when(() => mockLocalAuth.isDeviceSupported())
            .thenAnswer((_) async => true);
        when(() => mockLocalAuth.canCheckBiometrics)
            .thenAnswer((_) async => true);
        when(() => mockLocalAuth.authenticate(
              localizedReason: any(named: 'localizedReason'),
              biometricOnly: any(named: 'biometricOnly'),
              persistAcrossBackgrounding:
                  any(named: 'persistAcrossBackgrounding'),
            )).thenThrow(Exception('Hardware error'));
        return AuthLockBloc(localAuth: mockLocalAuth);
      },
      act: (bloc) => bloc.add(const AuthenticateWithBiometrics()),
      expect: () => [
        const AuthLocked(isAuthenticating: true),
        const AuthLocked(errorMessage: AppStrings.biometricsFailed),
      ],
    );

    blocTest<AuthLockBloc, AuthLockState>(
      'UnlockApp emits [AuthUnlocked]',
      build: () => AuthLockBloc(localAuth: mockLocalAuth),
      act: (bloc) => bloc.add(const UnlockApp()),
      expect: () => [
        const AuthUnlocked(),
      ],
    );

    blocTest<AuthLockBloc, AuthLockState>(
      'LockApp emits [AuthLocked]',
      build: () => AuthLockBloc(localAuth: mockLocalAuth),
      seed: () => const AuthUnlocked(),
      act: (bloc) => bloc.add(const LockApp()),
      expect: () => [
        const AuthLocked(),
      ],
    );

    blocTest<AuthLockBloc, AuthLockState>(
      'relocks app when background duration is 60s or more',
      build: () => AuthLockBloc(
        localAuth: mockLocalAuth,
        backgroundLockTimeout: const Duration(seconds: 60),
      ),
      seed: () => const AuthUnlocked(),
      act: (bloc) {
        final backgroundTime = DateTime(2026, 10, 13, 10, 0, 0);
        final resumeTime = DateTime(2026, 10, 13, 10, 1, 5); // 65 seconds
        bloc.add(AppEnteredBackground(timestamp: backgroundTime));
        bloc.add(AppResumed(timestamp: resumeTime));
      },
      expect: () => [
        const AuthLocked(),
      ],
    );

    blocTest<AuthLockBloc, AuthLockState>(
      'keeps app unlocked when background duration is less than 60s',
      build: () => AuthLockBloc(
        localAuth: mockLocalAuth,
        backgroundLockTimeout: const Duration(seconds: 60),
      ),
      seed: () => const AuthUnlocked(),
      act: (bloc) {
        final backgroundTime = DateTime(2026, 10, 13, 10, 0, 0);
        final resumeTime = DateTime(2026, 10, 13, 10, 0, 30); // 30 seconds
        bloc.add(AppEnteredBackground(timestamp: backgroundTime));
        bloc.add(AppResumed(timestamp: resumeTime));
      },
      expect: () => [],
    );
  });
}
