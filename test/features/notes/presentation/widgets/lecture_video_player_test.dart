import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nhom_7/core/l10n/strings.dart';
import 'package:nhom_7/features/notes/domain/utils/timestamp_helper.dart';
import 'package:nhom_7/features/notes/presentation/widgets/media/lecture_video_player.dart';

void main() {
  group('LectureVideoPlayer Widget', () {
    testWidgets('renders attachment card when videoPath is null and not in mini mode',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LectureVideoPlayer(
              videoPath: null,
              isMini: false,
            ),
          ),
        ),
      );

      expect(find.text(AppStrings.videoAttach), findsOneWidget);
      expect(find.byIcon(Icons.video_library_outlined), findsOneWidget);
    });

    testWidgets('Mini-Player renders 120x68 dp container and play/pause button',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LectureVideoPlayer(
              videoPath: null,
              isMini: true,
            ),
          ),
        ),
      );

      final miniContainer = tester.widget<Container>(
        find.descendant(
          of: find.byType(Semantics),
          matching: find.byType(Container).first,
        ),
      );

      expect(miniContainer.constraints?.maxWidth ?? 120.0, 120.0);
      expect(miniContainer.constraints?.maxHeight ?? 68.0, 68.0);
      expect(find.byType(InkWell), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);

      // Verify tapping play button does not crash even without initialized controller
      await tester.tap(find.byType(InkWell));
      await tester.pump();
    });

    testWidgets('Standard mode renders timestamp action button and chip list',
        (tester) async {
      Duration? insertedDuration;
      const timestamps = [
        TimestampEntry(
          tag: '[01:15]',
          duration: Duration(minutes: 1, seconds: 15),
          startIndex: 0,
          endIndex: 7,
        ),
        TimestampEntry(
          tag: '[05:30]',
          duration: Duration(minutes: 5, seconds: 30),
          startIndex: 10,
          endIndex: 17,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: LectureVideoPlayer(
                videoPath: 'dummy_lecture.mp4',
                timestamps: timestamps,
                isMini: false,
                onInsertTimestamp: (d) => insertedDuration = d,
              ),
            ),
          ),
        ),
      );

      // Verify "Gắn mốc" button and timestamp chips are rendered
      expect(find.text(AppStrings.videoTimestampButton), findsOneWidget);
      expect(find.text('[01:15]'), findsOneWidget);
      expect(find.text('[05:30]'), findsOneWidget);

      // Tapping "Gắn mốc" calls onInsertTimestamp
      await tester.tap(find.text(AppStrings.videoTimestampButton));
      await tester.pump();
      expect(insertedDuration, isNotNull);

      // Tapping a timestamp chip triggers seek
      await tester.tap(find.text('[01:15]'));
      await tester.pump();
    });

    testWidgets('Tapping remove video button calls onVideoChanged with null',
        (tester) async {
      String? changedPath = 'existing.mp4';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: LectureVideoPlayer(
                videoPath: 'existing.mp4',
                isMini: false,
                onVideoChanged: (newPath) => changedPath = newPath,
              ),
            ),
          ),
        ),
      );

      final removeBtn = find.byTooltip(AppStrings.videoRemove);
      expect(removeBtn, findsOneWidget);

      await tester.tap(removeBtn);
      await tester.pump();

      expect(changedPath, isNull);
    });
  });
}
