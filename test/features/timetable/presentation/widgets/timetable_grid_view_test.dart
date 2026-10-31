import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nhom_7/features/timetable/domain/entities/subject.dart';
import 'package:nhom_7/features/timetable/domain/entities/timetable_slot.dart';
import 'package:nhom_7/features/timetable/presentation/widgets/timetable_grid_view.dart';

void main() {
  final sampleSubject = Subject(
    id: 'sub-physics',
    name: 'Physics',
    code: 'PHY101',
    credits: 3,
    colorArgb: 0xFFFFC800,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  final sampleSlot = TimetableSlot(
    id: 'slot-phy',
    subjectId: 'sub-physics',
    room: 'H2.304',
    buildingId: 'H2',
    dayOfWeek: 1, // Thứ 2 / Mon
    startMin: 480, // 08:00
    endMin: 540,   // 09:00
    termStart: DateTime(2026, 1, 1),
    termEnd: DateTime(2026, 6, 30),
    source: 'manual',
    updatedAt: DateTime.now(),
  );

  Widget buildTestableWidget({
    List<TimetableSlot>? slots,
    Map<String, Subject>? subjects,
    VoidCallback? onDataChanged,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: TimetableGridView(
          allSlots: slots ?? [sampleSlot],
          subjectsMap: subjects ?? {'sub-physics': sampleSubject},
          onDataChanged: onDataChanged ?? () {},
        ),
      ),
    );
  }

  group('TimetableGridView Widget Tests', () {
    testWidgets('renders Time header, Mon header and slot cell correctly', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildTestableWidget());

      // Header row
      expect(find.text('Ca học'), findsOneWidget);
      expect(find.text('Thứ 2'), findsOneWidget);

      // Slot content
      expect(find.text('Physics'), findsOneWidget);
      expect(find.text('H2.304'), findsOneWidget);

      // Add button
      expect(find.byIcon(Icons.add_rounded), findsWidgets);
    });

    testWidgets('tapping time cell opens popup menu with Insert Row and Delete Row', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildTestableWidget());

      // Find first time popup button
      final popupFinder = find.byType(PopupMenuButton<String>).first;
      await tester.tap(popupFinder);
      await tester.pumpAndSettle();

      expect(find.text('Insert Row'), findsOneWidget);
      expect(find.text('Delete Row'), findsOneWidget);
    });
  });
}

