import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nhom_7/core/l10n/strings.dart';
import 'package:nhom_7/core/security/auth_lock_listenable.dart';
import 'package:nhom_7/core/security/key_storage_service.dart';
import 'package:nhom_7/features/settings/presentation/pages/tools_page.dart';

class MockKeyStorageService extends Mock implements KeyStorageService {}

class MockLocalAuthentication extends Mock implements LocalAuthentication {}

void main() {
  late MockKeyStorageService mockKeyStorage;
  late MockLocalAuthentication mockLocalAuth;

  setUp(() {
    mockKeyStorage = MockKeyStorageService();
    mockLocalAuth = MockLocalAuthentication();

    when(() => mockKeyStorage.isLockEnabled()).thenAnswer((_) async => false);
    when(() => mockKeyStorage.setLockEnabled(any())).thenAnswer((_) async {});
  });

  Widget buildTestableWidget() {
    return MaterialApp(
      home: ToolsPage(
        keyStorageService: mockKeyStorage,
        localAuth: mockLocalAuth,
      ),
    );
  }

  group('ToolsPage Widget Tests', () {
    testWidgets('renders ToolsPage with biometric switch, map and settings items',
        (tester) async {
      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.toolsTab), findsOneWidget);
      expect(find.text(AppStrings.biometricLockTitle), findsOneWidget);
      expect(find.text(AppStrings.biometricLockSubtitle), findsOneWidget);
      expect(find.byType(SwitchListTile), findsOneWidget);
      expect(find.text(AppStrings.mapNavigation), findsOneWidget);
      expect(find.text(AppStrings.appSettings), findsOneWidget);
    });

    testWidgets('toggling switch ON calls authenticate and sets lock enabled when successful',
        (tester) async {
      when(() => mockLocalAuth.isDeviceSupported()).thenAnswer((_) async => true);
      when(() => mockLocalAuth.canCheckBiometrics).thenAnswer((_) async => true);
      when(() => mockLocalAuth.authenticate(
            localizedReason: any(named: 'localizedReason'),
            biometricOnly: any(named: 'biometricOnly'),
            persistAcrossBackgrounding: any(named: 'persistAcrossBackgrounding'),
          )).thenAnswer((_) async => true);

      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      // Tap the switch to turn it ON
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      verify(() => mockLocalAuth.authenticate(
            localizedReason: any(named: 'localizedReason'),
            biometricOnly: any(named: 'biometricOnly'),
            persistAcrossBackgrounding: any(named: 'persistAcrossBackgrounding'),
          )).called(1);
      verify(() => mockKeyStorage.setLockEnabled(true)).called(1);
      expect(AuthLockListenable.instance.isLockEnabled, isTrue);
      expect(find.text(AppStrings.biometricLockEnabledSuccess), findsOneWidget);
    });

    testWidgets('toggling switch OFF sets lock disabled without authentication prompt',
        (tester) async {
      when(() => mockKeyStorage.isLockEnabled()).thenAnswer((_) async => true);
      AuthLockListenable.instance.setLockEnabled(true);

      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      // Tap the switch to turn it OFF
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      verifyNever(() => mockLocalAuth.authenticate(
            localizedReason: any(named: 'localizedReason'),
            biometricOnly: any(named: 'biometricOnly'),
            persistAcrossBackgrounding: any(named: 'persistAcrossBackgrounding'),
          ));
      verify(() => mockKeyStorage.setLockEnabled(false)).called(1);
      expect(AuthLockListenable.instance.isLockEnabled, isFalse);
      expect(find.text(AppStrings.biometricLockDisabledSuccess), findsOneWidget);
    });
  });
}
