import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nhom_7/core/security/auth_lock_listenable.dart';
import 'package:nhom_7/core/security/key_storage_service.dart';
import 'package:nhom_7/features/ai_assistant/data/datasources/gemini_remote_datasource.dart';
import 'package:nhom_7/features/settings/presentation/pages/system_settings_page.dart';
import 'package:nhom_7/features/timetable/data/datasources/timetable_local_datasource.dart';

class MockKeyStorageService extends Mock implements KeyStorageService {}

class MockGeminiRemoteDataSource extends Mock
    implements GeminiRemoteDataSource {}

class MockTimetableLocalDataSource extends Mock
    implements TimetableLocalDataSource {}

class MockLocalAuthentication extends Mock implements LocalAuthentication {}

void main() {
  late MockKeyStorageService mockKeyStorage;
  late MockGeminiRemoteDataSource mockGeminiDataSource;
  late MockTimetableLocalDataSource mockTimetableDataSource;
  late MockLocalAuthentication mockLocalAuth;

  setUp(() {
    mockKeyStorage = MockKeyStorageService();
    mockGeminiDataSource = MockGeminiRemoteDataSource();
    mockTimetableDataSource = MockTimetableLocalDataSource();
    mockLocalAuth = MockLocalAuthentication();

    AuthLockListenable.instance.setLockEnabled(false);
    when(() => mockKeyStorage.getGeminiApiKey()).thenAnswer((_) async => null);
    when(() => mockKeyStorage.isLockEnabled()).thenAnswer((_) async => false);
    when(() => mockKeyStorage.setLockEnabled(any())).thenAnswer((_) async {});
    when(() => mockKeyStorage.saveGeminiApiKey(any())).thenAnswer((_) async {});
    when(() => mockKeyStorage.clearGeminiApiKey()).thenAnswer((_) async {});
  });

  Widget buildTestableWidget() {
    return MaterialApp(
      home: SystemSettingsPage(
        keyStorageService: mockKeyStorage,
        geminiRemoteDataSource: mockGeminiDataSource,
        timetableLocalDataSource: mockTimetableDataSource,
        localAuth: mockLocalAuth,
      ),
    );
  }

  group('SystemSettingsPage Widget Tests', () {
    Future<void> setLargeScreen(WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    }

    testWidgets('renders SystemSettingsPage with all sections and elements',
        (tester) async {
      await setLargeScreen(tester);
      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      expect(find.text('Cài đặt hệ thống'), findsOneWidget);
      expect(find.text('Google Gemini 2.0 Flash'), findsOneWidget);
      expect(find.text('Cơ sở dữ liệu Hive CE'), findsNothing);
      expect(find.text('AES-256'), findsNothing);
      expect(find.text('Dọn dẹp bộ nhớ đệm (Cache)'), findsOneWidget);
      expect(find.text('Khôi phục dữ liệu ban đầu'), findsOneWidget);
      expect(find.text('Cài đặt Nhắc giờ học'), findsOneWidget);
      expect(find.text('Quyền truy cập Camera'), findsOneWidget);
      expect(find.text('Khóa bảo mật ứng dụng'), findsOneWidget);
      expect(find.text('StudySnap'), findsOneWidget);
    });

    testWidgets('clicking Nhập API Key opens edit dialog', (tester) async {
      await setLargeScreen(tester);
      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      final inputButton = find.text('Nhập API Key');
      expect(inputButton, findsOneWidget);
      await tester.tap(inputButton);
      await tester.pumpAndSettle();

      expect(find.text('Khóa Google Gemini API'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('toggling Khóa bảo mật ứng dụng switches lock state directly without pushing shell route',
        (tester) async {
      await setLargeScreen(tester);
      when(() => mockLocalAuth.isDeviceSupported()).thenAnswer((_) async => true);
      when(() => mockLocalAuth.canCheckBiometrics).thenAnswer((_) async => true);
      when(() => mockLocalAuth.authenticate(
            localizedReason: any(named: 'localizedReason'),
            biometricOnly: any(named: 'biometricOnly'),
            persistAcrossBackgrounding: any(named: 'persistAcrossBackgrounding'),
          )).thenAnswer((_) async => true);

      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      final lockTile = find.widgetWithText(SwitchListTile, 'Khóa bảo mật ứng dụng');
      expect(lockTile, findsOneWidget);

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      verify(() => mockKeyStorage.setLockEnabled(true)).called(1);
      expect(AuthLockListenable.instance.isLockEnabled, isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'API key dialog and Reset data dialog render without overflow on narrow 360px screen with 1.3x font scale',
        (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      when(() => mockTimetableDataSource.init()).thenAnswer((_) async {});
      when(() => mockTimetableDataSource.seedMockData(force: true))
          .thenAnswer((_) async {});

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(360, 800),
              textScaler: TextScaler.linear(1.3),
            ),
            child: SystemSettingsPage(
              keyStorageService: mockKeyStorage,
              geminiRemoteDataSource: mockGeminiDataSource,
              timetableLocalDataSource: mockTimetableDataSource,
              localAuth: mockLocalAuth,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Open API Key dialog and verify zero overflow
      await tester.tap(find.text('Nhập API Key'));
      await tester.pumpAndSettle();
      expect(find.text('Khóa Google Gemini API'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Hủy'));
      await tester.pumpAndSettle();

      // 2. Scroll to and tap Khôi phục, verify Reset dialog has zero overflow & calls seedMockData(force: true)
      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Khôi phục'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Khôi phục'));
      await tester.pumpAndSettle();

      expect(find.text('Khôi phục dữ liệu gốc?'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Tap confirm Khôi phục inside dialog (last finder is the dialog FilledButton)
      await tester.tap(find.text('Khôi phục').last);
      await tester.pumpAndSettle();

      verify(() => mockTimetableDataSource.seedMockData(force: true)).called(1);
    });
  });
}

