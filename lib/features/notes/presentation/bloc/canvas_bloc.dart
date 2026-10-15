import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/utils/canvas_history_manager.dart';
import 'canvas_event.dart';
import 'canvas_state.dart';

/// Manages canvas drawing state and coordinates Undo/Redo commands
/// via [CanvasHistoryManager].
class CanvasBloc extends Bloc<CanvasEvent, CanvasState> {
  final CanvasHistoryManager _historyManager;

  CanvasBloc({CanvasHistoryManager? historyManager})
      : _historyManager = historyManager ?? CanvasHistoryManager(),
        super(const CanvasState()) {
    on<SelectTool>(_onSelectTool);
    on<SelectColor>(_onSelectColor);
    on<ChangeStrokeWidth>(_onChangeStrokeWidth);
    on<AddStrokeEvent>(_onAddStroke);
    on<UndoEvent>(_onUndo);
    on<RedoEvent>(_onRedo);
    on<ClearAllStrokesEvent>(_onClearAllStrokes);
  }

  void _onSelectTool(SelectTool event, Emitter<CanvasState> emit) {
    emit(state.copyWith(selectedTool: event.tool));
  }

  void _onSelectColor(SelectColor event, Emitter<CanvasState> emit) {
    emit(state.copyWith(selectedColor: event.colorValue));
  }

  void _onChangeStrokeWidth(ChangeStrokeWidth event, Emitter<CanvasState> emit) {
    final clampedWidth = event.width.clamp(1.0, 30.0);
    emit(state.copyWith(strokeWidth: clampedWidth));
  }

  void _onAddStroke(AddStrokeEvent event, Emitter<CanvasState> emit) {
    final command = AddStrokeCommand(event.stroke);
    _historyManager.pushCommand(command);
    final updatedStrokes = _historyManager.applyCommand(state.strokes, command);
    emit(state.copyWith(
      strokes: updatedStrokes,
      canUndo: _historyManager.canUndo,
      canRedo: _historyManager.canRedo,
    ));
  }

  void _onUndo(UndoEvent event, Emitter<CanvasState> emit) {
    if (!_historyManager.canUndo) return;
    final command = _historyManager.undo();
    if (command == null) return;

    final updatedStrokes = _historyManager.reverseCommand(state.strokes, command);
    emit(state.copyWith(
      strokes: updatedStrokes,
      canUndo: _historyManager.canUndo,
      canRedo: _historyManager.canRedo,
    ));
  }

  void _onRedo(RedoEvent event, Emitter<CanvasState> emit) {
    if (!_historyManager.canRedo) return;
    final command = _historyManager.redo();
    if (command == null) return;

    final updatedStrokes = _historyManager.applyCommand(state.strokes, command);
    emit(state.copyWith(
      strokes: updatedStrokes,
      canUndo: _historyManager.canUndo,
      canRedo: _historyManager.canRedo,
    ));
  }

  void _onClearAllStrokes(ClearAllStrokesEvent event, Emitter<CanvasState> emit) {
    _historyManager.clear();
    emit(state.copyWith(
      strokes: const [],
      canUndo: false,
      canRedo: false,
    ));
  }
}
