import 'package:flutter/material.dart';

import '../../../domain/entities/stroke.dart';

/// Paints only the stroke currently being drawn by the user's finger.
///
/// Uses a [ValueNotifier<List<Offset>>] so that only this top-most painter
/// is invalidated on every pointer event — keeping the completed-strokes
/// layer untouched and the overall render budget within 60 FPS.
class ActiveStrokePainter extends CustomPainter {
  final ValueNotifier<List<Offset>> activePoints;
  final StrokeTool tool;
  final Color color;
  final double strokeWidth;

  ActiveStrokePainter({
    required this.activePoints,
    required this.tool,
    required this.color,
    required this.strokeWidth,
  }) : super(repaint: activePoints);

  @override
  void paint(Canvas canvas, Size size) {
    final pts = activePoints.value;
    if (pts.length < 2) return;

    final paint = _buildPaint();
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 1; i < pts.length; i++) {
      path.lineTo(pts[i].dx, pts[i].dy);
    }
    canvas.drawPath(path, paint);
  }

  Paint _buildPaint() {
    switch (tool) {
      case StrokeTool.pen:
        return Paint()
          ..color = color
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..style = PaintingStyle.stroke;

      case StrokeTool.highlighter:
        return Paint()
          ..color = color.withValues(alpha: 0.4)
          ..strokeWidth = strokeWidth * 3
          ..strokeCap = StrokeCap.square
          ..style = PaintingStyle.stroke;

      case StrokeTool.eraser:
        return Paint()
          ..color = Colors.white
          ..strokeWidth = strokeWidth * 2
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke;
    }
  }

  /// Always returns false — repaint is driven by [activePoints] ValueNotifier,
  /// not by widget rebuild.
  @override
  bool shouldRepaint(ActiveStrokePainter oldDelegate) => false;
}
