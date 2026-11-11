import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nhom_7/core/di/injection.dart';
import 'package:nhom_7/features/timetable/domain/entities/subject.dart';
import 'package:nhom_7/features/timetable/domain/usecases/calculate_gpa_usecase.dart';
import 'package:nhom_7/features/timetable/presentation/pages/gpa_page.dart';

void main() {
  setUp(() async {
    await getIt.reset();
    getIt.registerSingleton<CalculateGpaUseCase>(const CalculateGpaUseCase());
  });

  tearDown(() async {
    await getIt.reset();
  });

  Widget buildApp({double textScale = 1.0}) {
    return MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: const GpaPage(),
      ),
    );
  }

  group('Subject.letterGrade mapping verification', () {
    test('aligns 4.0 grading scale with UI grade dropdown options', () {
      Subject make(double gp) => Subject(
            id: 's-$gp',
            code: 'CS',
            name: 'Subject',
            credits: 3,
            colorArgb: 0xFF1E88E5,
            gradePoint: gp,
            createdAt: DateTime(2026),
            updatedAt: DateTime(2026),
          );

      expect(make(4.0).letterGrade, 'A+');
      expect(make(3.7).letterGrade, 'A');
      expect(make(3.5).letterGrade, 'B+');
      expect(make(3.0).letterGrade, 'B');
      expect(make(2.5).letterGrade, 'C+');
      expect(make(2.0).letterGrade, 'C');
      expect(make(1.5).letterGrade, 'D+');
      expect(make(1.0).letterGrade, 'D');
      expect(make(0.0).letterGrade, 'F');
    });
  });

  group('GpaPage Widget & UX Tests', () {
    testWidgets('shows clear step sections, default projection and letter hint',
        (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      expect(find.text('MỤC TIÊU KHẢ THI'), findsOneWidget);
      expect(find.text('3.60 / 4.0'), findsOneWidget);
      expect(find.textContaining('mức A'), findsOneWidget);
      expect(find.text('Tình hình học tập hiện tại'), findsOneWidget);
      expect(find.text('Bảng điểm từng môn'), findsOneWidget);
    });

    testWidgets(
        'validates empty/invalid GPA input and shows reachable target helper when impossible',
        (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      // Enter invalid GPA > 4.0
      await tester.enterText(
          find.byKey(const ValueKey('gpa_current_input')), '4.5');
      await tester.pumpAndSettle();
      expect(find.text('GPA hệ 4 phải từ 0.0 đến 4.0'), findsOneWidget);
      expect(find.text('CẦN KIỂM TRA LẠI SỐ LIỆU'), findsOneWidget);

      // Enter valid low GPA (2.0), completed 90, remaining 10 -> impossible for 3.2
      await tester.enterText(
          find.byKey(const ValueKey('gpa_current_input')), '2.0');
      await tester.enterText(
          find.byKey(const ValueKey('gpa_completed_credits_input')), '90');
      await tester.enterText(
          find.byKey(const ValueKey('gpa_remaining_credits_input')), '10');
      await tester.pumpAndSettle();

      expect(find.text('MỤC TIÊU CHƯA KHẢ THI'), findsOneWidget);
      expect(find.textContaining('2.20 / 4.0'), findsOneWidget);

      // Tap suggested target 2.20 -> immediately becomes achievable
      await tester.tap(find.textContaining('Hạ mục tiêu về mức khả thi (2.20)'));
      await tester.pumpAndSettle();
      expect(find.text('MỤC TIÊU KHẢ THI'), findsOneWidget);
    });

    testWidgets('renders cleanly without overflow on 360x700 at 1.3x text scale',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildApp(textScale: 1.3));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}

