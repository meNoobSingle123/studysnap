import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../domain/entities/stroke.dart';
import '../../../domain/utils/stroke_math.dart';

/// Paints all completed (finalized) strokes onto the canvas.
///
/// Repaint is triggered only when [strokes] list identity changes,
/// ensuring we never do unnecessary redraws.
class CompletedStrokesPainter extends CustomPainter {
  final List<Stroke> strokes;

  /// The size of the original backing image in logical pixels as
  /// displayed in the current [InteractiveViewer] scene.
  /// Used to denormalize stored [Stroke.points] back to paint coordinates.
  final StrokeSize displayImageSize;

  const CompletedStrokesPainter({
    required this.strokes,
    required this.displayImageSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in strokes) {
      _paintStroke(canvas, stroke);
    }
  }

  void _paintStroke(Canvas canvas, Stroke stroke) {
    if (stroke.points.length < 2) return;

    final points = denormalizePoints(stroke.points, displayImageSize);
    if (points.isEmpty) return;

    final paint = _buildPaint(stroke);

    final path = Path()
      ..moveTo(points.first.x, points.first.y);
    for (var i = 1; i < points.length; i++) {
      path.lineTo(points[i].x, points[i].y);
    }

    // Highlighter uses BlendMode.multiply at 40% opacity per spec (04-canvas-notes).
    if (stroke.tool == StrokeTool.highlighter) {
      canvas.saveLayer(null, Paint());
    }
    canvas.drawPath(path, paint);
    if (stroke.tool == StrokeTool.highlighter) {
      canvas.restore();
    }
  }

  Paint _buildPaint(Stroke stroke) {
    final color = Color(stroke.colorValue);
    final width = denormalizeWidth(stroke.widthNorm, displayImageSize.width);

    switch (stroke.tool) {
      case StrokeTool.pen:
        return Paint()
          ..color = color
          ..strokeWidth = width
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..style = PaintingStyle.stroke;

      case StrokeTool.highlighter:
        return Paint()
          ..color = color.withValues(alpha: 0.4)
          ..blendMode = ui.BlendMode.multiply
          ..strokeWidth = width * 3 // wider stroke for highlight
          ..strokeCap = StrokeCap.square
          ..style = PaintingStyle.stroke;

      case StrokeTool.eraser:
        return Paint()
          ..color = Colors.white
          ..blendMode = ui.BlendMode.clear
          ..strokeWidth = width * 2
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke;
    }
  }

  /// Compare by list identity — only repaints when the list reference changes.
  @override
  bool shouldRepaint(CompletedStrokesPainter oldDelegate) =>
      !identical(oldDelegate.strokes, strokes) ||
      oldDelegate.displayImageSize.width != displayImageSize.width ||
      oldDelegate.displayImageSize.height != displayImageSize.height;
}
