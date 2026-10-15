/// Pure Dart coordinate-transform utilities for the canvas drawing system.
///
/// All transformations operate on plain [double] pairs (x, y) so this
/// library has **zero** Flutter UI dependencies and can be tested in a
/// plain Dart environment.
///
/// Coordinate spaces used throughout the app:
///
/// * **Touch space**: raw pointer positions from the gesture recognizer,
///   measured in logical pixels relative to the widget's top-left corner.
/// * **Scene space**: the same point after applying the [TransformationController]
///   matrix of an [InteractiveViewer] — i.e. accounting for zoom & pan.
///   This step is performed in the Presentation layer by calling
///   `controller.toScene(localOffset)` *before* passing the result here.
/// * **Normalized space**: (x / imageWidth, y / imageHeight) both in [0.0, 1.0].
///   This is the only form stored in [Stroke.points].
/// * **Display space**: pixel position within the rectangular area on screen
///   where the image is currently rendered (origin = top-left of image rect).
library;

/// A plain 2-D point; no Flutter dependency.
class StrokePoint {
  final double x;
  final double y;

  const StrokePoint(this.x, this.y);

  @override
  String toString() => 'StrokePoint($x, $y)';
}

/// The size of a rectangular region.
class StrokeSize {
  final double width;
  final double height;

  const StrokeSize(this.width, this.height);

  bool get isEmpty => width <= 0 || height <= 0;
}

/// Converts a point from **scene space** to **normalized [0, 1] space**.
///
/// [scenePoint]  – the touch coordinate after `transformationController.toScene()`.
/// [imageSize]   – the ORIGINAL image dimensions (e.g. 4000 × 3000 px).
///
/// Returns [StrokePoint] with both components clamped to [0.0, 1.0].
/// Returns `StrokePoint(0, 0)` if [imageSize] has zero area (division-by-zero guard).
StrokePoint normalizePoint(StrokePoint scenePoint, StrokeSize imageSize) {
  if (imageSize.isEmpty) return const StrokePoint(0, 0);

  final nx = (scenePoint.x / imageSize.width).clamp(0.0, 1.0);
  final ny = (scenePoint.y / imageSize.height).clamp(0.0, 1.0);
  return StrokePoint(nx, ny);
}

/// Converts a **normalized [0, 1]** point back to **display pixel space**.
///
/// [normalizedPoint] – a point from [Stroke.points] (values in [0, 1]).
/// [displayRect]     – the size of the rectangle where the image is rendered
///                     on the current screen (e.g. 400 × 300 px on a phone
///                     portrait, 600 × 800 px landscape, etc.).
///
/// Returns [StrokePoint] in display pixels (origin = top-left of the image
/// on screen). Returns `StrokePoint(0, 0)` if [displayRect] has zero area.
StrokePoint denormalizePoint(StrokePoint normalizedPoint, StrokeSize displayRect) {
  if (displayRect.isEmpty) return const StrokePoint(0, 0);

  final px = normalizedPoint.x * displayRect.width;
  final py = normalizedPoint.y * displayRect.height;
  return StrokePoint(px, py);
}

/// Normalizes a pen width from **scene pixels** to a fraction of image width.
///
/// [widthScene]  – pen width in scene (logical pixel) units.
/// [imageWidth]  – the original image width in pixels.
///
/// Returns 0.0 when [imageWidth] is zero.
double normalizeWidth(double widthScene, double imageWidth) {
  if (imageWidth <= 0) return 0.0;
  return (widthScene / imageWidth).clamp(0.0, 1.0);
}

/// Converts a normalized pen width back to display pixels.
///
/// [widthNorm]    – fraction stored in [Stroke.widthNorm].
/// [displayWidth] – current display width of the image in pixels.
///
/// Returns 0.0 when [displayWidth] is zero.
double denormalizeWidth(double widthNorm, double displayWidth) {
  if (displayWidth <= 0) return 0.0;
  return widthNorm * displayWidth;
}

/// Converts a flat list of normalized coordinates [x0, y0, x1, y1, …]
/// to a list of [StrokePoint] in display pixel space.
///
/// Pairs with an odd total length drop the trailing orphan value.
List<StrokePoint> denormalizePoints(List<double> flatNormalized, StrokeSize displayRect) {
  final result = <StrokePoint>[];
  final len = flatNormalized.length - (flatNormalized.length % 2);
  for (var i = 0; i < len; i += 2) {
    result.add(
      denormalizePoint(
        StrokePoint(flatNormalized[i], flatNormalized[i + 1]),
        displayRect,
      ),
    );
  }
  return result;
}

/// Converts a list of [StrokePoint] in scene space to a flat [double] list
/// of normalized coordinates [x0, y0, x1, y1, …].
List<double> normalizePoints(List<StrokePoint> scenePoints, StrokeSize imageSize) {
  final result = <double>[];
  for (final pt in scenePoints) {
    final norm = normalizePoint(pt, imageSize);
    result
      ..add(norm.x)
      ..add(norm.y);
  }
  return result;
}

/// Simplifies a list of [StrokePoint] using a distance threshold to keep
/// stored stroke data small without visible quality loss.
///
/// [points]    – raw scene-space points to simplify.
/// [threshold] – minimum distance (in the same units as [points]) between
///               consecutive kept points. Defaults to 1.5 scene pixels.
List<StrokePoint> simplifyPoints(List<StrokePoint> points, {double threshold = 1.5}) {
  if (points.length <= 2) return List.of(points);

  final result = <StrokePoint>[points.first];
  for (var i = 1; i < points.length - 1; i++) {
    final prev = result.last;
    final curr = points[i];
    final dx = curr.x - prev.x;
    final dy = curr.y - prev.y;
    if ((dx * dx + dy * dy) >= threshold * threshold) {
      result.add(curr);
    }
  }
  result.add(points.last);
  return result;
}
