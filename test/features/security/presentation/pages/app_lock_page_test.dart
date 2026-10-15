import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nhom_7/core/l10n/strings.dart';
import 'package:nhom_7/core/security/bloc/auth_lock_bloc.dart';
import 'package:nhom_7/core/security/bloc/auth_lock_event.dart';
import 'package:nhom_7/core/security/bloc/auth_lock_state.dart';
import 'package:nhom_7/features/security/presentation/pages/app_lock_page.dart';

class MockAuthLockBloc extends MockBloc<AuthLockEvent, AuthLockState>
    implements AuthLockBloc {}

void main() {
  late MockAuthLockBloc mockAuthLockBloc;

  setUp(() {
    mockAuthLockBloc = MockAuthLockBloc();
  });

  Widget buildTestableWidget() {
    return MaterialApp(
      home: AppLockPage(bloc: mockAuthLockBloc),
    );
  }

  group('AppLockPage Widget Tests', () {
    testWidgets('renders lock UI with title and unlock button when locked',
        (tester) async {
      when(() => mockAuthLockBloc.state).thenReturn(const AuthLocked());

      await tester.pumpWidget(buildTestableWidget());
      await tester.pump();

      expect(find.text(AppStrings.appName), findsOneWidget);
      expect(find.text(AppStrings.appLockSubtitle), findsOneWidget);
      expect(find.text(AppStrings.unlockWithBiometrics), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline_rounded), findsOneWidget);
      expect(find.byIcon(Icons.fingerprint_rounded), findsOneWidget);
    });

    testWidgets('displays error banner when state has errorMessage',
        (tester) async {
      when(() => mockAuthLockBloc.state).thenReturn(const AuthLocked(
        errorMessage: AppStrings.biometricsFailed,
      ));

      await tester.pumpWidget(buildTestableWidget());
      await tester.pump();

      expect(find.text(AppStrings.biometricsFailed), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('tapping unlock button triggers AuthenticateWithBiometrics event',
        (tester) async {
      when(() => mockAuthLockBloc.state).thenReturn(const AuthLocked());

      await tester.pumpWidget(buildTestableWidget());
      await tester.pump();

      await tester.tap(find.text(AppStrings.unlockWithBiometrics));
      await tester.pump();

      verify(() => mockAuthLockBloc.add(const AuthenticateWithBiometrics()))
          .called(greaterThanOrEqualTo(1));
    });

    testWidgets('shows warning and allow unlock when BiometricsNotAvailable',
        (tester) async {
      when(() => mockAuthLockBloc.state).thenReturn(const BiometricsNotAvailable());

      await tester.pumpWidget(buildTestableWidget());
      await tester.pump();

      expect(find.text(AppStrings.biometricsNotAvailable), findsOneWidget);
      expect(find.text(AppStrings.ok), findsOneWidget);

      await tester.tap(find.text(AppStrings.ok));
      await tester.pump();

      verify(() => mockAuthLockBloc.add(const UnlockApp())).called(1);
    });
  });
}
