import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nhom_7/core/security/key_storage_service.dart';
import 'package:nhom_7/features/ai_assistant/data/datasources/gemini_remote_datasource.dart';
import 'package:nhom_7/features/settings/presentation/pages/system_settings_page.dart';
import 'package:nhom_7/features/timetable/data/datasources/timetable_local_datasource.dart';

class MockKeyStorageService extends Mock implements KeyStorageService {}

class MockGeminiRemoteDataSource extends Mock
    implements GeminiRemoteDataSource {}

class MockTimetableLocalDataSource extends Mock
    implements TimetableLocalDataSource {}

void main() {
  late MockKeyStorageService mockKeyStorage;
  late MockGeminiRemoteDataSource mockGeminiDataSource;
  late MockTimetableLocalDataSource mockTimetableDataSource;

  setUp(() {
    mockKeyStorage = MockKeyStorageService();
    mockGeminiDataSource = MockGeminiRemoteDataSource();
    mockTimetableDataSource = MockTimetableLocalDataSource();

    when(() => mockKeyStorage.getGeminiApiKey()).thenAnswer((_) async => null);
    when(() => mockKeyStorage.isLockEnabled()).thenAnswer((_) async => false);
    when(() => mockKeyStorage.saveGeminiApiKey(any())).thenAnswer((_) async {});
    when(() => mockKeyStorage.clearGeminiApiKey()).thenAnswer((_) async {});
  });

  Widget buildTestableWidget() {
    return MaterialApp(
      home: SystemSettingsPage(
        keyStorageService: mockKeyStorage,
        geminiRemoteDataSource: mockGeminiDataSource,
        timetableLocalDataSource: mockTimetableDataSource,
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
      expect(find.text('Cơ sở dữ liệu Hive CE'), findsOneWidget);
      expect(find.text('Dọn dẹp bộ nhớ đệm (Cache)'), findsOneWidget);
      expect(find.text('Khôi phục dữ liệu ban đầu'), findsOneWidget);
      expect(find.text('Cài đặt Nhắc giờ học'), findsOneWidget);
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
  });
}

