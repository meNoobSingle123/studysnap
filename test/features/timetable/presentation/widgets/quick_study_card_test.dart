import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nhom_7/features/timetable/domain/entities/subject.dart';
import 'package:nhom_7/features/timetable/domain/entities/timetable_slot.dart';
import 'package:nhom_7/features/timetable/presentation/widgets/quick_study_card.dart';

void main() {
  final sampleSubject = Subject(
    id: 'sub-cs101',
    name: 'Lập trình Flutter nâng cao',
    code: 'CS101',
    credits: 3,
    colorArgb: 0xFF5E48E8,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  final sampleSlot = TimetableSlot(
    id: 'slot-1',
    subjectId: 'sub-cs101',
    room: 'A1-402',
    buildingId: 'A1',
    dayOfWeek: 2,
    startMin: 480, // 08:00
    endMin: 600,   // 10:00
    termStart: DateTime(2026, 1, 1),
    termEnd: DateTime(2026, 6, 30),
    source: 'manual',
    updatedAt: DateTime.now(),
  );

  Widget buildTestableWidget({
    TimetableSlot? nextSlot,
    int? minutesUntilNextSlot,
    int todaySlotsCount = 1,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: QuickStudyCard(
          nextSlot: nextSlot,
          minutesUntilNextSlot: minutesUntilNextSlot,
          todaySlotsCount: todaySlotsCount,
          subjectsMap: {'sub-cs101': sampleSubject},
        ),
      ),
    );
  }

  group('QuickStudyCard Widget Tests', () {
    testWidgets('renders next upcoming slot and quick action buttons', (tester) async {
      await tester.pumpWidget(buildTestableWidget(
        nextSlot: sampleSlot,
        minutesUntilNextSlot: 25,
        todaySlotsCount: 2,
      ));

      expect(find.text('Lập trình Flutter nâng cao'), findsOneWidget);
      expect(find.text('Phòng A1-402'), findsOneWidget);
      expect(find.text('Tòa A1'), findsOneWidget);
      expect(find.text('Bắt đầu sau 25 phút'), findsOneWidget);
      expect(find.text('2 ca học hôm nay'), findsOneWidget);
      expect(find.text('Ghi chép ngay'), findsOneWidget);
      expect(find.text('Quét bảng OCR'), findsOneWidget);
    });

    testWidgets('renders empty state when no classes today', (tester) async {
      await tester.pumpWidget(buildTestableWidget(
        nextSlot: null,
        minutesUntilNextSlot: null,
        todaySlotsCount: 0,
      ));

      expect(find.text('Không có ca học'), findsOneWidget);
      expect(find.text('Hôm nay bạn không có lịch học 🏖️'), findsOneWidget);
      expect(find.byIcon(Icons.add), findsOneWidget);
    });

    testWidgets('renders completed state when classes today are done', (tester) async {
      await tester.pumpWidget(buildTestableWidget(
        nextSlot: null,
        minutesUntilNextSlot: null,
        todaySlotsCount: 2,
      ));

      expect(find.text('2 ca học hôm nay'), findsOneWidget);
      expect(find.text('Đã hoàn thành các ca học hôm nay! 🎉'), findsOneWidget);
    });
  });
}

