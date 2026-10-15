import '../entities/stroke.dart';

/// A single reversible canvas action.
sealed class CanvasCommand {
  const CanvasCommand();
}

/// Command produced when the user draws a new stroke.
class AddStrokeCommand extends CanvasCommand {
  final Stroke stroke;
  const AddStrokeCommand(this.stroke);
}

/// Command produced when a stroke is programmatically removed (e.g. eraser).
class RemoveStrokeCommand extends CanvasCommand {
  final Stroke stroke;
  const RemoveStrokeCommand(this.stroke);
}

/// Manages the canvas undo / redo history using a Command Pattern.
///
/// Rules:
/// * Adding any new command clears [_redoStack].
/// * History is capped at [maxHistory] entries; oldest commands are discarded.
/// * This class is pure Dart — no Flutter or BLoC imports.
class CanvasHistoryManager {
  final int maxHistory;

  final List<CanvasCommand> _undoStack = [];
  final List<CanvasCommand> _redoStack = [];

  CanvasHistoryManager({this.maxHistory = 100});

  /// Whether there are commands that can be undone.
  bool get canUndo => _undoStack.isNotEmpty;

  /// Whether there are commands that can be redone.
  bool get canRedo => _redoStack.isNotEmpty;

  /// Number of commands currently in the undo stack.
  int get undoCount => _undoStack.length;

  /// Number of commands currently in the redo stack.
  int get redoCount => _redoStack.length;

  /// Records [command] as the latest action.
  ///
  /// Clears [_redoStack] and enforces [maxHistory] cap.
  void pushCommand(CanvasCommand command) {
    _redoStack.clear();
    _undoStack.add(command);
    if (_undoStack.length > maxHistory) {
      _undoStack.removeAt(0);
    }
  }

  /// Pops the most recent command for undoing.
  ///
  /// Moves it to [_redoStack] and returns it, or `null` if empty.
  CanvasCommand? undo() {
    if (_undoStack.isEmpty) return null;
    final command = _undoStack.removeLast();
    _redoStack.add(command);
    return command;
  }

  /// Pops the most recently undone command for redoing.
  ///
  /// Moves it back to [_undoStack] and returns it, or `null` if empty.
  CanvasCommand? redo() {
    if (_redoStack.isEmpty) return null;
    final command = _redoStack.removeLast();
    _undoStack.add(command);
    return command;
  }

  /// Applies [command] to [strokes], returning the updated list.
  ///
  /// * [AddStrokeCommand] → appends the stroke.
  /// * [RemoveStrokeCommand] → removes the stroke by id.
  List<Stroke> applyCommand(List<Stroke> strokes, CanvasCommand command) {
    return switch (command) {
      AddStrokeCommand(:final stroke) => [...strokes, stroke],
      RemoveStrokeCommand(:final stroke) =>
        strokes.where((s) => s.id != stroke.id).toList(),
    };
  }

  /// Reverses [command] on [strokes], returning the updated list.
  ///
  /// * Undoing an [AddStrokeCommand] → removes the stroke.
  /// * Undoing a [RemoveStrokeCommand] → re-appends the stroke.
  List<Stroke> reverseCommand(List<Stroke> strokes, CanvasCommand command) {
    return switch (command) {
      AddStrokeCommand(:final stroke) =>
        strokes.where((s) => s.id != stroke.id).toList(),
      RemoveStrokeCommand(:final stroke) => [...strokes, stroke],
    };
  }

  /// Clears both undo and redo history completely.
  void clear() {
    _undoStack.clear();
    _redoStack.clear();
  }
}
