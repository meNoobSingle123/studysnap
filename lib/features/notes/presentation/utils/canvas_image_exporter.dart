import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../../domain/entities/stroke.dart';
import '../../domain/utils/stroke_math.dart';

/// Utility to flatten vector strokes and an optional background image into a
/// single raster image using [ui.PictureRecorder] and [Canvas].
///
/// Complies with:
/// - Maximum long edge capped to 4096 px to prevent OOM (rules/04-canvas-notes.md).
/// - Highlighter rendered using [ui.BlendMode.multiply] at 40% opacity.
/// - Full coordinate denormalization via [stroke_math.dart].
class CanvasImageExporter {
  static const double kMaxLongEdge = 4096.0;

  /// Calculates constrained dimensions so that neither width nor height
  /// exceeds [maxLongEdge], preserving aspect ratio.
  static Size computeConstrainedDimensions(
    Size originalSize, {
    double maxLongEdge = kMaxLongEdge,
  }) {
    var w = originalSize.width;
    var h = originalSize.height;

    if (w <= 0 || h <= 0) {
      return const Size(1080, 1920);
    }

    if (w > maxLongEdge || h > maxLongEdge) {
      final ratio = w / h;
      if (w >= h) {
        w = maxLongEdge;
        h = maxLongEdge / ratio;
      } else {
        h = maxLongEdge;
        w = maxLongEdge * ratio;
      }
    }
    return Size(w, h);
  }

  /// Flattens [strokes] and optional [baseImage] into PNG bytes.
  static Future<Uint8List?> exportToBytes({
    required List<Stroke> strokes,
    required Size targetSize,
    ui.Image? baseImage,
    Color backgroundColor = Colors.white,
    double maxLongEdge = kMaxLongEdge,
  }) async {
    final constrained = computeConstrainedDimensions(
      targetSize,
      maxLongEdge: maxLongEdge,
    );
    final w = constrained.width;
    final h = constrained.height;
    final displaySize = StrokeSize(w, h);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, w, h));

    // 1. Draw background or base image
    if (baseImage != null) {
      canvas.drawImageRect(
        baseImage,
        Rect.fromLTWH(
          0,
          0,
          baseImage.width.toDouble(),
          baseImage.height.toDouble(),
        ),
        Rect.fromLTWH(0, 0, w, h),
        Paint(),
      );
    } else {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, w, h),
        Paint()..color = backgroundColor,
      );
    }

    // 2. Overlay vector strokes
    for (final stroke in strokes) {
      if (stroke.points.length < 2) continue;

      final points = denormalizePoints(stroke.points, displaySize);
      if (points.isEmpty) continue;

      final paint = _buildStrokePaint(stroke, w);
      final path = Path()..moveTo(points.first.x, points.first.y);
      for (var i = 1; i < points.length; i++) {
        path.lineTo(points[i].x, points[i].y);
      }

      if (stroke.tool == StrokeTool.highlighter) {
        canvas.saveLayer(Rect.fromLTWH(0, 0, w, h), Paint());
        canvas.drawPath(path, paint);
        canvas.restore();
      } else {
        canvas.drawPath(path, paint);
      }
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(w.round(), h.round());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    return byteData?.buffer.asUint8List();
  }

  /// Saves the flattened PNG bytes to the local application documents directory.
  static Future<File> saveFlattenedImage(
    Uint8List bytes, {
    String? fileName,
  }) async {
    final directory = await getApplicationDocumentsDirectory();
    final name = fileName ?? 'canvas_${DateTime.now().millisecondsSinceEpoch}.png';
    final file = File('${directory.path}/$name');
    return file.writeAsBytes(bytes, flush: true);
  }

  static Paint _buildStrokePaint(Stroke stroke, double canvasWidth) {
    final color = Color(stroke.colorValue);
    final width = denormalizeWidth(stroke.widthNorm, canvasWidth);

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
          ..strokeWidth = width * 3
          ..strokeCap = StrokeCap.square
          ..style = PaintingStyle.stroke;

      case StrokeTool.eraser:
        return Paint()
          ..color = Colors.white
          ..strokeWidth = width * 2
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke;
    }
  }
}
