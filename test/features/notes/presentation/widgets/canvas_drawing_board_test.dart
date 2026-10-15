import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nhom_7/core/l10n/strings.dart';
import 'package:nhom_7/features/notes/domain/entities/stroke.dart';
import 'package:nhom_7/features/notes/domain/utils/stroke_math.dart';
import 'package:nhom_7/features/notes/presentation/widgets/canvas/active_stroke_painter.dart';
import 'package:nhom_7/features/notes/presentation/widgets/canvas/canvas_drawing_board.dart';
import 'package:nhom_7/features/notes/presentation/widgets/canvas/completed_strokes_painter.dart';

void main() {
  group('CompletedStrokesPainter', () {
    test('shouldRepaint returns false when strokes and size are identical', () {
      final strokes = <Stroke>[
        Stroke(
          id: '1',
          tool: StrokeTool.pen,
          colorValue: 0xFF000000,
          widthNorm: 0.01,
          points: const [0.1, 0.1, 0.2, 0.2],
          createdAt: DateTime(2026, 1, 1),
        ),
      ];
      const size = StrokeSize(800, 600);

      final painter1 = CompletedStrokesPainter(
        strokes: strokes,
        displayImageSize: size,
      );
      final painter2 = CompletedStrokesPainter(
        strokes: strokes,
        displayImageSize: size,
      );

      expect(painter2.shouldRepaint(painter1), isFalse);
    });

    test('shouldRepaint returns true when strokes list reference changes', () {
      final strokes1 = <Stroke>[];
      final strokes2 = <Stroke>[];
      const size = StrokeSize(800, 600);

      final painter1 = CompletedStrokesPainter(
        strokes: strokes1,
        displayImageSize: size,
      );
      final painter2 = CompletedStrokesPainter(
        strokes: strokes2,
        displayImageSize: size,
      );

      expect(painter2.shouldRepaint(painter1), isTrue);
    });

    test('shouldRepaint returns true when displayImageSize changes', () {
      final strokes = <Stroke>[];
      final painter1 = CompletedStrokesPainter(
        strokes: strokes,
        displayImageSize: const StrokeSize(800, 600),
      );
      final painter2 = CompletedStrokesPainter(
        strokes: strokes,
        displayImageSize: const StrokeSize(1024, 768),
      );

      expect(painter2.shouldRepaint(painter1), isTrue);
    });
  });

  group('ActiveStrokePainter', () {
    test('shouldRepaint always returns false', () {
      final notifier = ValueNotifier<List<Offset>>([]);
      final painter1 = ActiveStrokePainter(
        activePoints: notifier,
        tool: StrokeTool.pen,
        color: Colors.black,
        strokeWidth: 4.0,
      );
      final painter2 = ActiveStrokePainter(
        activePoints: notifier,
        tool: StrokeTool.pen,
        color: Colors.black,
        strokeWidth: 4.0,
      );

      expect(painter2.shouldRepaint(painter1), isFalse);
    });
  });

  group('CanvasDrawingBoard Widget', () {
    Widget buildTestHarness({
      List<Stroke> strokes = const [],
      Size originalImageSize = const Size(1000, 1000),
      void Function(Stroke stroke)? onStrokeAdded,
      VoidCallback? onUndo,
      VoidCallback? onRedo,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 400,
            child: CanvasDrawingBoard(
              strokes: strokes,
              originalImageSize: originalImageSize,
              onStrokeAdded: onStrokeAdded,
              onUndo: onUndo,
              onRedo: onRedo,
            ),
          ),
        ),
      );
    }

    testWidgets('starts in view mode by default without undo/redo buttons', (tester) async {
      await tester.pumpWidget(buildTestHarness());

      // Toggle button indicates we can switch to Draw mode
      expect(find.text(AppStrings.canvasModeDraw), findsOneWidget);
      expect(find.byIcon(Icons.edit_outlined), findsOneWidget);

      // Undo/Redo are hidden in view mode
      expect(find.byIcon(Icons.undo_rounded), findsNothing);
      expect(find.byIcon(Icons.redo_rounded), findsNothing);

      final state = tester.state<CanvasDrawingBoardState>(find.byType(CanvasDrawingBoard));
      expect(state.mode, CanvasMode.view);
    });

    testWidgets('toggles between view mode and draw mode on FAB click', (tester) async {
      await tester.pumpWidget(buildTestHarness());

      // Tap toggle to enter Draw mode
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.canvasModeView), findsOneWidget);
      expect(find.byIcon(Icons.pan_tool_outlined), findsOneWidget);
      expect(find.byIcon(Icons.undo_rounded), findsOneWidget);
      expect(find.byIcon(Icons.redo_rounded), findsOneWidget);

      var state = tester.state<CanvasDrawingBoardState>(find.byType(CanvasDrawingBoard));
      expect(state.mode, CanvasMode.draw);

      // Tap toggle again to return to View mode
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.canvasModeDraw), findsOneWidget);
      expect(find.byIcon(Icons.undo_rounded), findsNothing);
      expect(find.byIcon(Icons.redo_rounded), findsNothing);

      state = tester.state<CanvasDrawingBoardState>(find.byType(CanvasDrawingBoard));
      expect(state.mode, CanvasMode.view);
    });

    testWidgets('triggers onUndo and onRedo in draw mode', (tester) async {
      var undoCalled = false;
      var redoCalled = false;

      await tester.pumpWidget(
        buildTestHarness(
          onUndo: () => undoCalled = true,
          onRedo: () => redoCalled = true,
        ),
      );

      // Switch to draw mode
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.undo_rounded));
      await tester.pump();
      expect(undoCalled, isTrue);

      await tester.tap(find.byIcon(Icons.redo_rounded));
      await tester.pump();
      expect(redoCalled, isTrue);
    });

    testWidgets('captures drawing gesture and emits stroke in draw mode', (tester) async {
      Stroke? addedStroke;

      await tester.pumpWidget(
        buildTestHarness(
          originalImageSize: const Size(1000, 1000),
          onStrokeAdded: (stroke) => addedStroke = stroke,
        ),
      );

      // Switch to draw mode
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      // Perform drag gesture across the canvas
      final gesture = await tester.startGesture(const Offset(200, 200));
      await gesture.moveBy(const Offset(30, 30));
      await tester.pump();
      await gesture.moveBy(const Offset(30, 30));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(addedStroke, isNotNull);
      expect(addedStroke!.tool, StrokeTool.pen);
      expect(addedStroke!.points.length, greaterThanOrEqualTo(4));
      // Normalized coordinates should be within [0.0, 1.0]
      for (final val in addedStroke!.points) {
        expect(val, inInclusiveRange(0.0, 1.0));
      }
    });

    testWidgets('does not capture drawing gesture in view mode', (tester) async {
      Stroke? addedStroke;

      await tester.pumpWidget(
        buildTestHarness(
          onStrokeAdded: (stroke) => addedStroke = stroke,
        ),
      );

      // We are in View mode by default
      await tester.drag(find.byType(InteractiveViewer), const Offset(100, 100));
      await tester.pumpAndSettle();

      expect(addedStroke, isNull);
    });
  });
}
