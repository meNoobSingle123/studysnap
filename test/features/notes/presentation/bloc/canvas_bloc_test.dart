import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nhom_7/features/notes/domain/entities/stroke.dart';
import 'package:nhom_7/features/notes/presentation/bloc/canvas_bloc.dart';
import 'package:nhom_7/features/notes/presentation/bloc/canvas_event.dart';
import 'package:nhom_7/features/notes/presentation/bloc/canvas_state.dart';

Stroke _createSampleStroke(String id) => Stroke(
      id: id,
      tool: StrokeTool.pen,
      colorValue: 0xFF000000,
      widthNorm: 0.01,
      points: const [0.1, 0.1, 0.2, 0.2],
      createdAt: DateTime(2026, 10, 13),
    );

void main() {
  group('CanvasBloc', () {
    test('initial state has correct default values', () {
      final bloc = CanvasBloc();
      expect(
        bloc.state,
        equals(
          const CanvasState(
            selectedTool: StrokeTool.pen,
            selectedColor: 0xFF000000,
            strokeWidth: 4.0,
            strokes: [],
            canUndo: false,
            canRedo: false,
          ),
        ),
      );
      bloc.close();
    });

    blocTest<CanvasBloc, CanvasState>(
      'SelectTool updates selectedTool in state',
      build: () => CanvasBloc(),
      act: (bloc) => bloc.add(const SelectTool(StrokeTool.highlighter)),
      expect: () => [
        const CanvasState(selectedTool: StrokeTool.highlighter),
      ],
    );

    blocTest<CanvasBloc, CanvasState>(
      'SelectColor updates selectedColor in state',
      build: () => CanvasBloc(),
      act: (bloc) => bloc.add(const SelectColor(0xFFE53935)),
      expect: () => [
        const CanvasState(selectedColor: 0xFFE53935),
      ],
    );

    blocTest<CanvasBloc, CanvasState>(
      'ChangeStrokeWidth updates strokeWidth and clamps between 1.0 and 30.0',
      build: () => CanvasBloc(),
      act: (bloc) {
        bloc.add(const ChangeStrokeWidth(15.5));
        bloc.add(const ChangeStrokeWidth(0.5)); // should clamp to 1.0
        bloc.add(const ChangeStrokeWidth(50.0)); // should clamp to 30.0
      },
      expect: () => [
        const CanvasState(strokeWidth: 15.5),
        const CanvasState(strokeWidth: 1.0),
        const CanvasState(strokeWidth: 30.0),
      ],
    );

    final stroke1 = _createSampleStroke('s1');
    final stroke2 = _createSampleStroke('s2');

    blocTest<CanvasBloc, CanvasState>(
      'AddStrokeEvent adds stroke and enables canUndo',
      build: () => CanvasBloc(),
      act: (bloc) => bloc.add(AddStrokeEvent(stroke1)),
      expect: () => [
        CanvasState(
          strokes: [stroke1],
          canUndo: true,
          canRedo: false,
        ),
      ],
    );

    blocTest<CanvasBloc, CanvasState>(
      'UndoEvent removes recent stroke and enables canRedo',
      build: () => CanvasBloc(),
      act: (bloc) {
        bloc.add(AddStrokeEvent(stroke1));
        bloc.add(const UndoEvent());
      },
      expect: () => [
        CanvasState(
          strokes: [stroke1],
          canUndo: true,
          canRedo: false,
        ),
        const CanvasState(
          strokes: [],
          canUndo: false,
          canRedo: true,
        ),
      ],
    );

    blocTest<CanvasBloc, CanvasState>(
      'RedoEvent re-applies undone stroke and disables canRedo',
      build: () => CanvasBloc(),
      act: (bloc) {
        bloc.add(AddStrokeEvent(stroke1));
        bloc.add(const UndoEvent());
        bloc.add(const RedoEvent());
      },
      expect: () => [
        CanvasState(
          strokes: [stroke1],
          canUndo: true,
          canRedo: false,
        ),
        const CanvasState(
          strokes: [],
          canUndo: false,
          canRedo: true,
        ),
        CanvasState(
          strokes: [stroke1],
          canUndo: true,
          canRedo: false,
        ),
      ],
    );

    blocTest<CanvasBloc, CanvasState>(
      'ClearAllStrokesEvent clears all strokes and resets undo/redo stacks',
      build: () => CanvasBloc(),
      act: (bloc) {
        bloc.add(AddStrokeEvent(stroke1));
        bloc.add(AddStrokeEvent(stroke2));
        bloc.add(const ClearAllStrokesEvent());
      },
      expect: () => [
        CanvasState(
          strokes: [stroke1],
          canUndo: true,
          canRedo: false,
        ),
        CanvasState(
          strokes: [stroke1, stroke2],
          canUndo: true,
          canRedo: false,
        ),
        const CanvasState(
          strokes: [],
          canUndo: false,
          canRedo: false,
        ),
      ],
    );

    blocTest<CanvasBloc, CanvasState>(
      'UndoEvent when empty does not emit new states',
      build: () => CanvasBloc(),
      act: (bloc) => bloc.add(const UndoEvent()),
      expect: () => [],
    );

    blocTest<CanvasBloc, CanvasState>(
      'RedoEvent when empty does not emit new states',
      build: () => CanvasBloc(),
      act: (bloc) => bloc.add(const RedoEvent()),
      expect: () => [],
    );
  });
}
