import 'package:equatable/equatable.dart';

import '../../domain/entities/stroke.dart';

/// State of the canvas drawing workspace.
class CanvasState extends Equatable {
  /// The currently active tool (pen, highlighter, eraser).
  final StrokeTool selectedTool;

  /// The active color represented as a 32-bit ARGB integer.
  final int selectedColor;

  /// Pen / stroke width in logical pixels (1.0 to 30.0).
  final double strokeWidth;

  /// All finalized strokes currently rendered on the canvas.
  final List<Stroke> strokes;

  /// Whether an undo action is available.
  final bool canUndo;

  /// Whether a redo action is available.
  final bool canRedo;

  const CanvasState({
    this.selectedTool = StrokeTool.pen,
    this.selectedColor = 0xFF000000,
    this.strokeWidth = 4.0,
    this.strokes = const [],
    this.canUndo = false,
    this.canRedo = false,
  });

  CanvasState copyWith({
    StrokeTool? selectedTool,
    int? selectedColor,
    double? strokeWidth,
    List<Stroke>? strokes,
    bool? canUndo,
    bool? canRedo,
  }) {
    return CanvasState(
      selectedTool: selectedTool ?? this.selectedTool,
      selectedColor: selectedColor ?? this.selectedColor,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      strokes: strokes ?? this.strokes,
      canUndo: canUndo ?? this.canUndo,
      canRedo: canRedo ?? this.canRedo,
    );
  }

  @override
  List<Object?> get props => [
        selectedTool,
        selectedColor,
        strokeWidth,
        strokes,
        canUndo,
        canRedo,
      ];
}
