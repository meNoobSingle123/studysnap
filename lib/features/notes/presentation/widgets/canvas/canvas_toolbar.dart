import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/l10n/strings.dart';
import '../../../domain/entities/stroke.dart';
import '../../bloc/canvas_bloc.dart';
import '../../bloc/canvas_event.dart';
import '../../bloc/canvas_state.dart';

/// Preset palette colors: 5 core colors + 1 highlighter yellow.
const List<int> kCanvasPresetColors = [
  0xFF000000, // Black
  0xFFE53935, // Red
  0xFF1E88E5, // Blue
  0xFF43A047, // Green
  0xFFFB8C00, // Orange
  0xFFFFEB3B, // Highlight Yellow
];

/// A rich floating / docked toolbar for canvas drawing controls:
/// - Tool selector: Pen, Highlighter, Eraser
/// - Quick color palette (with active outline indicator)
/// - Stroke width slider (1.0 to 30.0 px) with live px badge
/// - Actions: Undo, Redo (auto-disabled), Clear All (confirmation dialog)
class CanvasToolbar extends StatelessWidget {
  /// Optional callback to inject custom bloc; if null, reads from [context].
  final CanvasBloc? bloc;

  const CanvasToolbar({super.key, this.bloc});

  @override
  Widget build(BuildContext context) {
    final activeBloc = bloc ?? context.read<CanvasBloc>();

    return BlocBuilder<CanvasBloc, CanvasState>(
      bloc: activeBloc,
      builder: (context, state) {
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Top Row: Tools + History Actions ─────────────────────────
                Row(
                  children: [
                    // Tool Segmented Switch
                    Expanded(
                      child: SegmentedButton<StrokeTool>(
                        segments: const [
                          ButtonSegment(
                            value: StrokeTool.pen,
                            icon: Icon(Icons.edit_outlined),
                            label: Text(AppStrings.canvasPen),
                          ),
                          ButtonSegment(
                            value: StrokeTool.highlighter,
                            icon: Icon(Icons.brush_outlined),
                            label: Text(AppStrings.canvasHighlighter),
                          ),
                          ButtonSegment(
                            value: StrokeTool.eraser,
                            icon: Icon(Icons.auto_fix_normal_outlined),
                            label: Text(AppStrings.canvasEraser),
                          ),
                        ],
                        selected: {state.selectedTool},
                        onSelectionChanged: (selected) {
                          if (selected.isNotEmpty) {
                            activeBloc.add(SelectTool(selected.first));
                          }
                        },
                        showSelectedIcon: false,
                        style: const ButtonStyle(
                          visualDensity: VisualDensity.compact,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Undo
                    IconButton(
                      tooltip: AppStrings.canvasUndo,
                      icon: const Icon(Icons.undo_rounded),
                      onPressed: state.canUndo
                          ? () => activeBloc.add(const UndoEvent())
                          : null,
                    ),

                    // Redo
                    IconButton(
                      tooltip: AppStrings.canvasRedo,
                      icon: const Icon(Icons.redo_rounded),
                      onPressed: state.canRedo
                          ? () => activeBloc.add(const RedoEvent())
                          : null,
                    ),

                    // Clear All
                    IconButton(
                      tooltip: AppStrings.canvasClearAll,
                      icon: const Icon(Icons.delete_sweep_outlined),
                      onPressed: state.strokes.isNotEmpty
                          ? () => _confirmClearAll(context, activeBloc)
                          : null,
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // ── Bottom Row: Color Swatches + Size Slider ─────────────────
                Row(
                  children: [
                    // Color Palette (Hidden when Eraser is active)
                    if (state.selectedTool != StrokeTool.eraser) ...[
                      ...kCanvasPresetColors.map((colorVal) {
                        final isSelected = state.selectedColor == colorVal;
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: InkWell(
                            key: Key('color_swatch_${colorVal.toRadixString(16)}'),
                            onTap: () => activeBloc.add(SelectColor(colorVal)),
                            borderRadius: BorderRadius.circular(24),
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: Color(colorVal),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected
                                      ? colorScheme.primary
                                      : colorScheme.outlineVariant,
                                  width: isSelected ? 3 : 1,
                                ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: colorScheme.primary.withValues(alpha: 0.35),
                                          blurRadius: 4,
                                          spreadRadius: 1,
                                        ),
                                      ]
                                    : null,
                              ),
                              child: isSelected
                                  ? Icon(
                                      Icons.check,
                                      size: 16,
                                      color: _contrastTextColor(Color(colorVal)),
                                    )
                                  : null,
                            ),
                          ),
                        );
                      }),
                      const SizedBox(width: 8),
                      Container(
                        height: 24,
                        width: 1,
                        color: colorScheme.outlineVariant,
                      ),
                      const SizedBox(width: 8),
                    ],

                    // Stroke Width Badge
                    Text(
                      '${state.strokeWidth.toStringAsFixed(1)} px',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    // Stroke Width Slider
                    Expanded(
                      child: Slider(
                        value: state.strokeWidth,
                        min: 1.0,
                        max: 30.0,
                        divisions: 29,
                        label: '${state.strokeWidth.round()} px',
                        onChanged: (newWidth) {
                          activeBloc.add(ChangeStrokeWidth(newWidth));
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _contrastTextColor(Color bg) {
    final luminance = bg.computeLuminance();
    return luminance > 0.5 ? Colors.black : Colors.white;
  }

  Future<void> _confirmClearAll(BuildContext context, CanvasBloc bloc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(AppStrings.canvasClearConfirmTitle),
        content: const Text(AppStrings.canvasClearConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(AppStrings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(AppStrings.delete),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      bloc.add(const ClearAllStrokesEvent());
    }
  }
}
