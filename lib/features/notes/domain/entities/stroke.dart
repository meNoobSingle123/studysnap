import 'package:equatable/equatable.dart';

/// Drawing tool type for each stroke.
enum StrokeTool { pen, highlighter, eraser }

/// Pure domain entity representing a single vector drawing stroke.
///
/// All coordinate data is stored as normalized values in [0.0, 1.0]
/// relative to the original image dimensions, so strokes remain
/// accurate regardless of zoom level, pan position or screen orientation.
class Stroke extends Equatable {
  /// Unique identifier for this stroke.
  final String id;

  /// The drawing tool that created this stroke.
  final StrokeTool tool;

  /// ARGB color packed as an integer (e.g. 0xFF_FF0000 = opaque red).
  final int colorValue;

  /// Pen width expressed as a fraction of the original image width [0.0, 1.0].
  final double widthNorm;

  /// Flat list of normalized point coordinates [x0, y0, x1, y1, ...].
  /// Every coordinate is in the range [0.0, 1.0] relative to the
  /// original image (x / imageWidth, y / imageHeight).
  final List<double> points;

  final DateTime createdAt;

  const Stroke({
    required this.id,
    required this.tool,
    required this.colorValue,
    required this.widthNorm,
    required this.points,
    required this.createdAt,
  });

  Stroke copyWith({
    String? id,
    StrokeTool? tool,
    int? colorValue,
    double? widthNorm,
    List<double>? points,
    DateTime? createdAt,
  }) {
    return Stroke(
      id: id ?? this.id,
      tool: tool ?? this.tool,
      colorValue: colorValue ?? this.colorValue,
      widthNorm: widthNorm ?? this.widthNorm,
      points: points ?? this.points,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [id, tool, colorValue, widthNorm, points, createdAt];
}
