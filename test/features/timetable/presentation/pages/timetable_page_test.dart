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
}
