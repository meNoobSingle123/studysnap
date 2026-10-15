import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../../../core/l10n/strings.dart';
import '../../../domain/entities/stroke.dart';
import '../../../domain/utils/stroke_math.dart';
import 'active_stroke_painter.dart';
import 'completed_strokes_painter.dart';

/// Interaction mode for the canvas board.
enum CanvasMode {
  /// Pan & zoom mode — InteractiveViewer is active, drawing is locked.
  view,

  /// Draw mode — InteractiveViewer is locked, GestureDetector captures input.
  draw,
}

/// The main canvas widget that layers:
/// 1. An optional background image.
/// 2. A [RepaintBoundary]-isolated [CompletedStrokesPainter] layer.
/// 3. A [RepaintBoundary]-isolated [ActiveStrokePainter] layer.
///
/// Toggle between [CanvasMode.view] and [CanvasMode.draw] via the floating
/// action button. In view mode the [InteractiveViewer] handles pan/zoom up to
/// 5× (500%). In draw mode the viewer is locked and [GestureDetector] captures
/// all pointer events.
class CanvasDrawingBoard extends StatefulWidget {
  /// Completed strokes to render on the lower paint layer.
  final List<Stroke> strokes;

  /// Original image dimensions — used for coordinate normalization.
  /// Pass [Size.zero] when no image is loaded yet.
  final Size originalImageSize;

  /// Optional background image widget (e.g. [Image.file]).
  final Widget? backgroundImage;

  /// Called when the user finishes drawing a new stroke.
  final void Function(Stroke stroke)? onStrokeAdded;

  /// Called when undo is triggered.
  final void Function()? onUndo;

  /// Called when redo is triggered.
  final void Function()? onRedo;

  /// Active drawing tool.
  final StrokeTool activeTool;

  /// Active pen color.
  final Color activeColor;

  /// Active pen width in logical pixels (scene space).
  final double activeWidthScene;

  const CanvasDrawingBoard({
    super.key,
    required this.strokes,
    required this.originalImageSize,
    this.backgroundImage,
    this.onStrokeAdded,
    this.onUndo,
    this.onRedo,
    this.activeTool = StrokeTool.pen,
    this.activeColor = Colors.black,
    this.activeWidthScene = 4.0,
  });

  @override
  State<CanvasDrawingBoard> createState() => CanvasDrawingBoardState();
}

@visibleForTesting
class CanvasDrawingBoardState extends State<CanvasDrawingBoard> {
  CanvasMode _mode = CanvasMode.view;
  final _transformationController = TransformationController();
  final _uuid = const Uuid();
  final GlobalKey _canvasContentKey = GlobalKey();
  StrokeSize? _lastDisplaySize;

  /// Points of the stroke currently being drawn (in display/paint pixels).
  final ValueNotifier<List<Offset>> _activePoints = ValueNotifier([]);

  /// Temporary scene-space points for normalization on PanEnd.
  final List<StrokePoint> _scenePointsBuffer = [];

  /// Exposed for widget tests.
  CanvasMode get mode => _mode;

  @override
  void dispose() {
    _transformationController.dispose();
    _activePoints.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Gesture handlers
  // ---------------------------------------------------------------------------

  void _onPanStart(DragStartDetails details) {
    if (_mode != CanvasMode.draw) return;
    _activePoints.value = [];
    _scenePointsBuffer.clear();
    _addPoint(details.globalPosition, fallbackLocal: details.localPosition);
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_mode != CanvasMode.draw) return;
    _addPoint(details.globalPosition, fallbackLocal: details.localPosition);
  }

  void _onPanEnd(DragEndDetails _) {
    if (_mode != CanvasMode.draw) return;
    _finalizeStroke();
  }

  /// Converts touch position to scene space and records point.
  /// Uses [RenderBox.globalToLocal] from [_canvasContentKey] to eliminate any
  /// touch offset or screen offset, falling back to [_transformationController.toScene].
  void _addPoint(Offset globalPos, {required Offset fallbackLocal}) {
    Offset sceneOffset;
    final renderBox = _canvasContentKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null && renderBox.hasSize) {
      sceneOffset = renderBox.globalToLocal(globalPos);
    } else {
      sceneOffset = _transformationController.toScene(fallbackLocal);
    }

    final scenePoint = StrokePoint(sceneOffset.dx, sceneOffset.dy);
    _scenePointsBuffer.add(scenePoint);

    final current = List<Offset>.from(_activePoints.value)..add(sceneOffset);
    _activePoints.value = current;
  }

  /// Normalizes, simplifies, and emits the completed stroke.
  void _finalizeStroke() {
    final renderBox = _canvasContentKey.currentContext?.findRenderObject() as RenderBox?;
    final targetSize = (renderBox != null && renderBox.hasSize && renderBox.size.width > 0 && renderBox.size.height > 0)
        ? StrokeSize(renderBox.size.width, renderBox.size.height)
        : (_lastDisplaySize ??
            (widget.originalImageSize.width > 0 && widget.originalImageSize.height > 0
                ? StrokeSize(widget.originalImageSize.width, widget.originalImageSize.height)
                : const StrokeSize(1080, 1920)));

    // Apply simplification to remove redundant close points (< 1.5 px)
    final simplified = simplifyPoints(_scenePointsBuffer, threshold: 1.5);

    // Normalize to [0, 1] relative to the actual canvas display size
    final flatNorm = normalizePoints(simplified, targetSize);

    if (flatNorm.length >= 4) {
      // Need at least one complete segment (2 points → 4 values)
      final stroke = Stroke(
        id: _uuid.v4(),
        tool: widget.activeTool,
        colorValue: widget.activeColor.toARGB32(),
        widthNorm: normalizeWidth(widget.activeWidthScene, targetSize.width),
        points: flatNorm,
        createdAt: DateTime.now(),
      );
      widget.onStrokeAdded?.call(stroke);
    }

    _activePoints.value = [];
    _scenePointsBuffer.clear();
  }

  // ---------------------------------------------------------------------------
  // UI helpers
  // ---------------------------------------------------------------------------

  void _toggleMode() {
    setState(() {
      _mode = _mode == CanvasMode.view ? CanvasMode.draw : CanvasMode.view;
      // Clear any dangling in-progress stroke on mode switch
      _activePoints.value = [];
      _scenePointsBuffer.clear();
    });
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final isDrawMode = _mode == CanvasMode.draw;
    final colorScheme = Theme.of(context).colorScheme;

    return Stack(
      children: [
        // ── Main canvas area ─────────────────────────────────────────────────
        InteractiveViewer(
          transformationController: _transformationController,
          // Lock viewer in draw mode so two-finger zoom doesn't interfere
          panEnabled: !isDrawMode,
          scaleEnabled: !isDrawMode,
          minScale: 0.5,
          maxScale: 5.0,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final displaySize = StrokeSize(
                constraints.maxWidth,
                constraints.maxHeight,
              );
              _lastDisplaySize = displaySize;
              return SizedBox(
                key: _canvasContentKey,
                width: constraints.maxWidth,
                height: constraints.maxHeight,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Background image layer
                    if (widget.backgroundImage != null)
                      widget.backgroundImage!
                    else
                      const ColoredBox(color: Colors.transparent),

                    // Layer 1 — completed strokes (RepaintBoundary isolates)
                    RepaintBoundary(
                      child: CustomPaint(
                        painter: CompletedStrokesPainter(
                          strokes: widget.strokes,
                          displayImageSize: displaySize,
                        ),
                      ),
                    ),

                    // Layer 2 — active stroke (RepaintBoundary isolates)
                    RepaintBoundary(
                      child: CustomPaint(
                        painter: ActiveStrokePainter(
                          activePoints: _activePoints,
                          tool: widget.activeTool,
                          color: widget.activeColor,
                          strokeWidth: widget.activeWidthScene,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),

        // ── Draw gesture overlay (Active only in Draw Mode) ───────────────────
        if (isDrawMode)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart: _onPanStart,
              onPanUpdate: _onPanUpdate,
              onPanEnd: _onPanEnd,
            ),
          ),

        // ── Mode toggle button ───────────────────────────────────────────────
        Positioned(
          top: 12,
          right: 12,
          child: Tooltip(
            message: isDrawMode
                ? AppStrings.canvasModeView
                : AppStrings.canvasModeDraw,
            child: FloatingActionButton.extended(
              heroTag: 'canvas_mode_toggle',
              onPressed: _toggleMode,
              backgroundColor: isDrawMode
                  ? colorScheme.primaryContainer
                  : colorScheme.surfaceContainerHighest,
              foregroundColor: isDrawMode
                  ? colorScheme.onPrimaryContainer
                  : colorScheme.onSurfaceVariant,
              icon: Icon(
                isDrawMode ? Icons.pan_tool_outlined : Icons.edit_outlined,
              ),
              label: Text(
                isDrawMode
                    ? AppStrings.canvasModeView
                    : AppStrings.canvasModeDraw,
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ),
        ),

        // ── Undo / Redo row ─────────────────────────────────────────────────
        if (isDrawMode)
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _IconBtn(
                  icon: Icons.undo_rounded,
                  tooltip: AppStrings.canvasUndo,
                  onTap: widget.onUndo,
                ),
                const SizedBox(width: 12),
                _IconBtn(
                  icon: Icons.redo_rounded,
                  tooltip: AppStrings.canvasRedo,
                  onTap: widget.onRedo,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Private helpers
// ---------------------------------------------------------------------------

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  const _IconBtn({
    required this.icon,
    required this.tooltip,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(icon, size: 22),
          ),
        ),
      ),
    );
  }
}
