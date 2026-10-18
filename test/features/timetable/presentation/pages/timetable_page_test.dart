import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nhom_7/core/l10n/strings.dart';
import 'package:nhom_7/features/timetable/data/datasources/timetable_remote_data_source.dart';
import 'package:nhom_7/features/timetable/presentation/pages/timetable_page.dart';

class MockTimetableRemoteDataSource extends Mock
    implements TimetableRemoteDataSource {}

void main() {
  late MockTimetableRemoteDataSource mockRemoteDataSource;

  setUp(() {
    mockRemoteDataSource = MockTimetableRemoteDataSource();
  });

  final sampleTimetable = {
    'termId': '2026-1',
    'subjects': [
      {'id': 'sub-1', 'name': 'Flutter'},
    ],
    'slots': [
      {'id': 'slot-1', 'dayOfWeek': 2},
    ],
  };

  Widget buildTestableWidget() {
    return MaterialApp(
      home: TimetablePage(remoteDataSource: mockRemoteDataSource),
    );
  }

  group('TimetablePage Widget Tests', () {
    testWidgets('renders AppBar with sync button and empty state initially',
        (tester) async {
      await tester.pumpWidget(buildTestableWidget());

      expect(find.text(AppStrings.timetableTab), findsWidgets);
      expect(find.byIcon(Icons.sync), findsOneWidget);
      expect(find.text(AppStrings.emptyData), findsOneWidget);
    });

    testWidgets(
        'tapping sync button triggers getTimetable and shows success SnackBar',
        (tester) async {
      when(() => mockRemoteDataSource.getTimetable('2026-1'))
          .thenAnswer((_) async => sampleTimetable);

      await tester.pumpWidget(buildTestableWidget());

      await tester.tap(find.byIcon(Icons.sync));
      await tester.pump();
      await tester.pumpAndSettle();

      verify(() => mockRemoteDataSource.getTimetable('2026-1')).called(1);
      expect(find.text(AppStrings.syncTimetableSuccess), findsWidgets);
      expect(find.text('Học kỳ: 2026-1'), findsOneWidget);
    });
  });

  group('AddSlotBottomSheet Widget & Recurring Tests', () {
    testWidgets('renders all input fields and Google Calendar repeat switch',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AddSlotBottomSheet(
              initialDate: DateTime(2026, 10, 16),
              onSave: ({
                required String subjectName,
                required String room,
                String? building,
                required DateTime startDate,
                required TimeOfDay startTime,
                required TimeOfDay endTime,
                required int repeatWeeks,
              }) async {},
            ),
          ),
        ),
      );

      expect(find.byKey(const ValueKey('add_slot_subject_field')), findsOneWidget);
      expect(find.byKey(const ValueKey('add_slot_room_field')), findsOneWidget);
      expect(find.byKey(const ValueKey('add_slot_building_field')), findsOneWidget);
      expect(find.byKey(const ValueKey('add_slot_date_picker')), findsOneWidget);
      expect(find.byKey(const ValueKey('add_slot_start_time_picker')), findsOneWidget);
      expect(find.byKey(const ValueKey('add_slot_end_time_picker')), findsOneWidget);
      expect(find.byKey(const ValueKey('add_slot_repeat_switch')), findsOneWidget);
      expect(find.byKey(const ValueKey('add_slot_repeat_weeks_dropdown')), findsNothing);
      expect(find.byKey(const ValueKey('add_slot_submit_button')), findsOneWidget);
      expect(find.text(AppStrings.addSlotTitle), findsOneWidget);
      expect(find.text(AppStrings.addSlotSubtitle), findsOneWidget);
    });

    testWidgets('shows validation errors when submitting with empty fields',
        (tester) async {
      bool onSaveCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AddSlotBottomSheet(
              initialDate: DateTime(2026, 10, 16),
              onSave: ({
                required String subjectName,
                required String room,
                String? building,
                required DateTime startDate,
                required TimeOfDay startTime,
                required TimeOfDay endTime,
                required int repeatWeeks,
              }) async {
                onSaveCalled = true;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('add_slot_submit_button')));
      await tester.pumpAndSettle();

      expect(onSaveCalled, isFalse);
      expect(find.text('Vui lòng nhập tên môn học hoặc sự kiện'), findsOneWidget);
      expect(find.text('Vui lòng nhập phòng'), findsNothing);
    });

    testWidgets(
        'single event (repeat switch OFF by default) calls onSave with repeatWeeks = 1',
        (tester) async {
      String? savedSubject;
      String? savedRoom;
      int? savedRepeatWeeks;
      DateTime? savedStartDate;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AddSlotBottomSheet(
              initialDate: DateTime(2026, 10, 16),
              onSave: ({
                required String subjectName,
                required String room,
                String? building,
                required DateTime startDate,
                required TimeOfDay startTime,
                required TimeOfDay endTime,
                required int repeatWeeks,
              }) async {
                savedSubject = subjectName;
                savedRoom = room;
                savedRepeatWeeks = repeatWeeks;
                savedStartDate = startDate;
              },
            ),
          ),
        ),
      );

      await tester.enterText(
        find.byKey(const ValueKey('add_slot_subject_field')),
        'Họp nhóm đồ án',
      );
      await tester.enterText(
        find.byKey(const ValueKey('add_slot_room_field')),
        'Online Meet',
      );
      await tester.pumpAndSettle();

      // Submit with default repeat OFF
      await tester.ensureVisible(find.byKey(const ValueKey('add_slot_submit_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('add_slot_submit_button')));
      await tester.pumpAndSettle();

      expect(savedSubject, equals('Họp nhóm đồ án'));
      expect(savedRoom, equals('Online Meet'));
      expect(savedRepeatWeeks, equals(1));
      expect(savedStartDate, equals(DateTime(2026, 10, 16)));
    });

    testWidgets(
        'recurring event (repeat switch ON) reveals dropdown and calls onSave with selected repeatWeeks',
        (tester) async {
      String? savedSubject;
      String? savedRoom;
      int? savedRepeatWeeks;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AddSlotBottomSheet(
              initialDate: DateTime(2026, 10, 16),
              onSave: ({
                required String subjectName,
                required String room,
                String? building,
                required DateTime startDate,
                required TimeOfDay startTime,
                required TimeOfDay endTime,
                required int repeatWeeks,
              }) async {
                savedSubject = subjectName;
                savedRoom = room;
                savedRepeatWeeks = repeatWeeks;
              },
            ),
          ),
        ),
      );

      await tester.enterText(
        find.byKey(const ValueKey('add_slot_subject_field')),
        'Lập trình di động',
      );
      await tester.enterText(
        find.byKey(const ValueKey('add_slot_room_field')),
        'H2.304',
      );
      await tester.pumpAndSettle();

      // Toggle repeat switch ON
      await tester.ensureVisible(find.byKey(const ValueKey('add_slot_repeat_switch')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('add_slot_repeat_switch')));
      await tester.pumpAndSettle();

      // Verify dropdown is revealed
      expect(find.byKey(const ValueKey('add_slot_repeat_weeks_dropdown')), findsOneWidget);

      await tester.ensureVisible(find.byKey(const ValueKey('add_slot_submit_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('add_slot_submit_button')));
      await tester.pumpAndSettle();

      expect(savedSubject, equals('Lập trình di động'));
      expect(savedRoom, equals('H2.304'));
      expect(savedRepeatWeeks, equals(5));
    });
  });
}
