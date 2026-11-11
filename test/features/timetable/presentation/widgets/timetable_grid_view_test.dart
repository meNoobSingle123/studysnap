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
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  // Tuần mẫu: 09/11/2026 (Thứ 2) .. 15/11/2026 (Chủ nhật), nowForTest = 11/11/2026
  final sampleSlot = TimetableSlot(
    id: 'slot-phy',
    subjectId: 'sub-physics',
    room: 'H2.304',
    buildingId: 'H2',
    dayOfWeek: 1, // Thứ 2 (09/11)
    startMin: 480, // 08:00
    endMin: 540, // 09:00
    termStart: DateTime(2026, 10, 19),
    termEnd: DateTime(2027, 1, 15),
    source: 'manual',
    updatedAt: DateTime(2026, 1, 1),
  );

  final afternoonFractionalSlot = TimetableSlot(
    id: 'slot-afternoon',
    subjectId: 'sub-physics',
    room: 'B3.102',
    buildingId: 'B3',
    dayOfWeek: 3, // Thứ 4 (11/11)
    startMin: 810, // 13:30
    endMin: 960, // 16:00
    termStart: DateTime(2026, 10, 19),
    termEnd: DateTime(2027, 1, 15),
    source: 'user',
    updatedAt: DateTime(2026, 1, 1),
  );

  final eveningSlot = TimetableSlot(
    id: 'slot-evening',
    subjectId: 'sub-physics',
    room: 'Online',
    buildingId: null,
    dayOfWeek: 5, // Thứ 6 (13/11)
    startMin: 1170, // 19:30
    endMin: 1320, // 22:00
    termStart: DateTime(2026, 10, 19),
    termEnd: DateTime(2027, 1, 15),
    source: 'user',
    updatedAt: DateTime(2026, 1, 1),
  );

  final singleDayOnlySlot = TimetableSlot(
    id: 'slot-one-day-only',
    subjectId: 'sub-physics',
    room: 'A1.201',
    buildingId: 'A1',
    dayOfWeek: 4, // Thứ 5 (12/11/2026) - chỉ học duy nhất ngày này
    startMin: 600, // 10:00
    endMin: 720, // 12:00
    termStart: DateTime(2026, 11, 12),
    termEnd: DateTime(2026, 11, 12),
    source: 'user',
    updatedAt: DateTime(2026, 11, 11),
  );

  Widget buildTestableWidget({
    List<TimetableSlot>? slots,
    Map<String, Subject>? subjects,
    VoidCallback? onDataChanged,
    double textScale = 1.0,
  }) {
    return MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: Scaffold(
          body: TimetableGridView(
            allSlots: slots ?? [sampleSlot],
            subjectsMap: subjects ?? {'sub-physics': sampleSubject},
            onDataChanged: onDataChanged ?? () {},
            nowForTest: DateTime(2026, 11, 11, 11, 26),
          ),
        ),
      ),
    );
  }

  group('TimetableGridView Hourly Timeline Widget Tests', () {
    testWidgets('renders Giờ header, hourly ticks, weekday headers and slot',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildTestableWidget());

      expect(find.text('Giờ'), findsOneWidget);
      expect(find.text('06:00'), findsOneWidget);
      expect(find.text('08:00'), findsOneWidget);
      expect(find.text('13:00'), findsOneWidget);
      expect(find.text('Thứ 2'), findsOneWidget);
      expect(find.text('Chủ nhật'), findsOneWidget);
      expect(find.text('Tuần 09/11 - 15/11/2026'), findsOneWidget);

      expect(find.text('Physics'), findsOneWidget);
      expect(find.text('08:00 - 09:00 • H2.304'), findsOneWidget);
    });

    testWidgets(
        'renders fractional afternoon slot (13:30-16:00) and evening slot (19:30-22:00) at proportional vertical positions',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        buildTestableWidget(slots: [afternoonFractionalSlot, eveningSlot]),
      );

      expect(find.text('13:30 - 16:00'), findsOneWidget);
      expect(find.text('19:30 - 22:00'), findsOneWidget);

      final afternoonPos = tester.widget<Positioned>(
          find.byKey(const ValueKey('grid_slot_slot-afternoon')));
      expect(afternoonPos.top, closeTo(481.5, 0.1));
      expect(afternoonPos.height, closeTo(157.0, 0.1));

      final eveningPos = tester
          .widget<Positioned>(find.byKey(const ValueKey('grid_slot_slot-evening')));
      expect(eveningPos.top, closeTo(865.5, 0.1));
      expect(eveningPos.height, closeTo(157.0, 0.1));
    });

    testWidgets(
        'tapping empty hour cell opens editor without +1h quick chips, with repeat switch OFF hiding weekdays until enabled',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildTestableWidget(slots: const []));

      // Tap 13:00 on Thứ 4 (day 3 -> 11/11/2026)
      final cellFinder = find.byKey(const ValueKey('grid_empty_3_13'));
      await tester.ensureVisible(cellFinder);
      await tester.pumpAndSettle();
      await tester.tap(cellFinder);
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('grid_editor_start_time')), findsOneWidget);
      expect(find.byKey(const ValueKey('grid_editor_end_time')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('grid_editor_start_time')),
          matching: find.text('13:00'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('grid_editor_end_time')),
          matching: find.text('14:00'),
        ),
        findsOneWidget,
      );

      // Quick hour duration chips must be removed
      expect(find.text('+1h'), findsNothing);
      expect(find.text('+1h30'), findsNothing);
      expect(find.text('+2h'), findsNothing);
      expect(find.text('+2h30'), findsNothing);
      expect(find.text('+3h'), findsNothing);

      // Repeat toggle is OFF by default -> T2..CN chips must be hidden
      expect(
          find.byKey(const ValueKey('grid_editor_repeat_switch')), findsOneWidget);
      for (int day = 1; day <= 7; day++) {
        expect(find.byKey(ValueKey('grid_weekday_chip_$day')), findsNothing);
      }
      expect(find.text('Lưu duy nhất ngày 11/11/2026'), findsOneWidget);

      // Turn ON repeat switch -> T2..CN chips + repeat weeks become visible
      await tester.tap(find.byKey(const ValueKey('grid_editor_repeat_switch')));
      await tester.pumpAndSettle();

      for (int day = 1; day <= 7; day++) {
        expect(find.byKey(ValueKey('grid_weekday_chip_$day')), findsOneWidget);
      }
      expect(
          find.byKey(const ValueKey('grid_editor_repeat_weeks')), findsOneWidget);

      // Select T2 (1) and T6 (5) alongside default T4 (3)
      await tester.tap(find.byKey(const ValueKey('grid_weekday_chip_1')));
      await tester.tap(find.byKey(const ValueKey('grid_weekday_chip_5')));
      await tester.pumpAndSettle();

      expect(find.text('Lưu lặp 3 thứ (15 tuần)'), findsOneWidget);
    });

    testWidgets(
        'non-repeating single-day slot displays only in its week and hides next week',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        buildTestableWidget(slots: [sampleSlot, singleDayOnlySlot]),
      );

      // Current week 09/11 - 15/11 shows both repeating slot and 12/11 single-day slot
      expect(find.byKey(const ValueKey('grid_slot_slot-phy')), findsOneWidget);
      expect(find.byKey(const ValueKey('grid_slot_slot-one-day-only')),
          findsOneWidget);

      // Move to next week (16/11 - 22/11)
      await tester.tap(find.byKey(const ValueKey('grid_next_week_btn')));
      await tester.pumpAndSettle();

      expect(find.text('Tuần 16/11 - 22/11/2026'), findsOneWidget);
      expect(find.text('Tuần này'), findsNothing);
      expect(find.byKey(const ValueKey('grid_slot_slot-phy')), findsOneWidget);
      expect(find.byKey(const ValueKey('grid_slot_slot-one-day-only')),
          findsNothing);
    });

    testWidgets(
        'tapping existing 13-week recurring slot opens editor cleanly without DropdownButton assertion',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildTestableWidget(slots: [sampleSlot]));

      await tester.tap(find.byKey(const ValueKey('grid_slot_slot-phy')));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Chỉnh sửa ca học'), findsOneWidget);
      expect(find.text('13 tuần liên tiếp'), findsOneWidget);
    });

    testWidgets('renders cleanly on narrow phone 360x700 at 1.3x text scale',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        buildTestableWidget(
          slots: [sampleSlot, afternoonFractionalSlot, eveningSlot],
          textScale: 1.3,
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
