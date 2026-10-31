import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nhom_7/core/security/key_storage_service.dart';
import 'package:nhom_7/features/onboarding/presentation/pages/onboarding_page.dart';

class MockKeyStorageService extends Mock implements KeyStorageService {}

void main() {
  late MockKeyStorageService mockKeyStorage;

  setUp(() {
    mockKeyStorage = MockKeyStorageService();
    when(() => mockKeyStorage.setOnboardingCompleted(any()))
        .thenAnswer((_) async {});
  });

  Widget buildTestableWidget() {
    return MaterialApp(
      home: OnboardingPage(keyStorageService: mockKeyStorage),
    );
  }

  group('OnboardingPage Widget Tests', () {
    testWidgets('renders first slide with title and badge', (tester) async {
      await tester.pumpWidget(buildTestableWidget());

      expect(find.text('THỜI KHÓA BIỂU & NHẮC HỌC'), findsOneWidget);
      expect(find.text('Quản lý Ca học & Báo thức thông minh'), findsOneWidget);
      expect(find.text('Tiếp theo'), findsOneWidget);
      expect(find.text('Bỏ qua'), findsOneWidget);
    });

    testWidgets('tapping Next moves to next slide', (tester) async {
      await tester.pumpWidget(buildTestableWidget());

      await tester.tap(find.text('Tiếp theo'));
      await tester.pumpAndSettle();

      expect(find.text('GHI CHÉP ĐA PHƯƠNG TIỆN'), findsOneWidget);
      expect(find.text('Ghi chú bài giảng & Nét vẽ Vector'), findsOneWidget);
    });

    testWidgets('tapping Skip calls setOnboardingCompleted(true)', (tester) async {
      await tester.pumpWidget(buildTestableWidget());

      await tester.tap(find.text('Bỏ qua'));
      await tester.pumpAndSettle();

      verify(() => mockKeyStorage.setOnboardingCompleted(true)).called(1);
    });
  });
}

