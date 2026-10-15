import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nhom_7/core/l10n/strings.dart';
import 'package:nhom_7/features/notes/domain/entities/stroke.dart';
import 'package:nhom_7/features/notes/presentation/bloc/canvas_bloc.dart';
import 'package:nhom_7/features/notes/presentation/bloc/canvas_event.dart';
import 'package:nhom_7/features/notes/presentation/widgets/canvas/canvas_toolbar.dart';

void main() {
  group('CanvasToolbar Widget', () {
    late CanvasBloc bloc;

    setUp(() {
      bloc = CanvasBloc();
    });

    tearDown(() {
      bloc.close();
    });

    Widget buildTestHarness() {
      return MaterialApp(
        home: Scaffold(
          body: CanvasToolbar(bloc: bloc),
        ),
      );
    }

    testWidgets('renders all tools, color swatches, and slider correctly', (tester) async {
      await tester.pumpWidget(buildTestHarness());

      expect(find.text(AppStrings.canvasPen), findsOneWidget);
      expect(find.text(AppStrings.canvasHighlighter), findsOneWidget);
      expect(find.text(AppStrings.canvasEraser), findsOneWidget);

      // Slider present
      expect(find.byType(Slider), findsOneWidget);
      expect(find.text('4.0 px'), findsOneWidget);

      // Undo and Redo disabled initially
      final undoBtn = tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.undo_rounded));
      final redoBtn = tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.redo_rounded));
      expect(undoBtn.onPressed, isNull);
      expect(redoBtn.onPressed, isNull);
    });

    testWidgets('tool selection switches active tool in bloc', (tester) async {
      await tester.pumpWidget(buildTestHarness());

      await tester.tap(find.text(AppStrings.canvasHighlighter));
      await tester.pumpAndSettle();

      expect(bloc.state.selectedTool, StrokeTool.highlighter);

      await tester.tap(find.text(AppStrings.canvasEraser));
      await tester.pumpAndSettle();

      expect(bloc.state.selectedTool, StrokeTool.eraser);
    });

    testWidgets('slider adjustment updates strokeWidth in bloc', (tester) async {
      await tester.pumpWidget(buildTestHarness());

      final slider = find.byType(Slider);
      await tester.tap(slider);
      await tester.pumpAndSettle();

      expect(bloc.state.strokeWidth, isNot(4.0));
    });

    testWidgets('color swatch tap updates selectedColor in bloc', (tester) async {
      await tester.pumpWidget(buildTestHarness());

      // Tap on second color swatch (Red: 0xFFE53935)
      final redKey = Key('color_swatch_${kCanvasPresetColors[1].toRadixString(16)}');
      await tester.tap(find.byKey(redKey));
      await tester.pumpAndSettle();

      expect(bloc.state.selectedColor, kCanvasPresetColors[1]);
    });

    testWidgets('clear all button shows confirmation dialog and clears strokes on confirm', (tester) async {
      bloc.add(
        AddStrokeEvent(
          Stroke(
            id: 'test-1',
            tool: StrokeTool.pen,
            colorValue: 0xFF000000,
            widthNorm: 0.01,
            points: const [0.1, 0.1, 0.2, 0.2],
            createdAt: DateTime.now(),
          ),
        ),
      );

      await tester.pumpWidget(buildTestHarness());

      // Clear button should be enabled now
      final clearBtn = find.widgetWithIcon(IconButton, Icons.delete_sweep_outlined);
      await tester.tap(clearBtn);
      await tester.pumpAndSettle();

      // Dialog appears
      expect(find.text(AppStrings.canvasClearConfirmTitle), findsOneWidget);
      expect(find.text(AppStrings.canvasClearConfirmMessage), findsOneWidget);

      // Tap Confirm Delete
      await tester.tap(find.text(AppStrings.delete));
      await tester.pumpAndSettle();

      expect(bloc.state.strokes, isEmpty);
    });
  });
}
