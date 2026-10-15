import 'package:equatable/equatable.dart';

import '../../domain/entities/stroke.dart';

/// Base class for all Canvas events.
sealed class CanvasEvent extends Equatable {
  const CanvasEvent();

  @override
  List<Object?> get props => [];
}

/// Changes the active drawing tool (Pen, Highlighter, Eraser).
class SelectTool extends CanvasEvent {
  final StrokeTool tool;

  const SelectTool(this.tool);

  @override
  List<Object?> get props => [tool];
}

/// Changes the active pen/highlighter color (packed ARGB int).
class SelectColor extends CanvasEvent {
  final int colorValue;

  const SelectColor(this.colorValue);

  @override
  List<Object?> get props => [colorValue];
}

/// Changes the stroke width in logical pixels (1.0 to 30.0).
class ChangeStrokeWidth extends CanvasEvent {
  final double width;

  const ChangeStrokeWidth(this.width);

  @override
  List<Object?> get props => [width];
}

/// Adds a new completed stroke to the canvas.
class AddStrokeEvent extends CanvasEvent {
  final Stroke stroke;

  const AddStrokeEvent(this.stroke);

  @override
  List<Object?> get props => [stroke];
}

/// Undoes the most recent canvas action.
class UndoEvent extends CanvasEvent {
  const UndoEvent();
}

/// Redoes the most recently undone canvas action.
class RedoEvent extends CanvasEvent {
  const RedoEvent();
}

/// Clears all strokes on the canvas.
class ClearAllStrokesEvent extends CanvasEvent {
  const ClearAllStrokesEvent();
}
