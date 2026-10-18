import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:nhom_7/core/l10n/strings.dart';
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
                // ── Row 1: Tool Selection (Full width, no wrapping or overflow) ───
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<StrokeTool>(
                    segments: const [
                      ButtonSegment(
                        value: StrokeTool.pen,
                        icon: Icon(Icons.edit_outlined, size: 18),
                        label: Text(AppStrings.canvasPen),
                      ),
                      ButtonSegment(
                        value: StrokeTool.highlighter,
                        icon: Icon(Icons.brush_outlined, size: 18),
                        label: Text(AppStrings.canvasHighlighter),
                      ),
                      ButtonSegment(
                        value: StrokeTool.eraser,
                        icon: Icon(Icons.auto_fix_normal_outlined, size: 18),
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
                const SizedBox(height: 6),

                // ── Row 2: Color Swatches & History Actions ───────────────────────
                Row(
                  children: [
                    // Color Palette (Hidden when Eraser is active)
                    if (state.selectedTool != StrokeTool.eraser) ...[
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: kCanvasPresetColors.map((colorVal) {
                              final isSelected = state.selectedColor == colorVal;
                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 3),
                                child: InkWell(
                                  key: Key('color_swatch_${colorVal.toRadixString(16)}'),
                                  onTap: () => activeBloc.add(SelectColor(colorVal)),
                                  borderRadius: BorderRadius.circular(24),
                                  child: Container(
                                    width: 26,
                                    height: 26,
                                    decoration: BoxDecoration(
                                      color: Color(colorVal),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isSelected
                                            ? colorScheme.primary
                                            : colorScheme.outlineVariant,
                                        width: isSelected ? 3 : 1,
                                      ),
                                    ),
                                    child: isSelected
                                        ? Icon(
                                            Icons.check,
                                            size: 14,
                                            color: _contrastTextColor(Color(colorVal)),
                                          )
                                        : null,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ] else
                      Expanded(
                        child: Text(
                          'Chế độ tẩy nét vẽ',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.outline,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),

                    const SizedBox(width: 4),

                    // Undo
                    IconButton(
                      tooltip: AppStrings.canvasUndo,
                      icon: const Icon(Icons.undo_rounded, size: 20),
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.all(6),
                      constraints: const BoxConstraints(),
                      onPressed: state.canUndo
                          ? () => activeBloc.add(const UndoEvent())
                          : null,
                    ),
                    const SizedBox(width: 4),

                    // Redo
                    IconButton(
                      tooltip: AppStrings.canvasRedo,
                      icon: const Icon(Icons.redo_rounded, size: 20),
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.all(6),
                      constraints: const BoxConstraints(),
                      onPressed: state.canRedo
                          ? () => activeBloc.add(const RedoEvent())
                          : null,
                    ),
                    const SizedBox(width: 4),

                    // Clear All
                    IconButton(
                      tooltip: AppStrings.canvasClearAll,
                      icon: const Icon(Icons.delete_sweep_outlined, size: 20),
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.all(6),
                      constraints: const BoxConstraints(),
                      onPressed: state.strokes.isNotEmpty
                          ? () => _confirmClearAll(context, activeBloc)
                          : null,
                    ),
                  ],
                ),
                const SizedBox(height: 4),

                // ── Row 3: Stroke Width Badge & Slider ────────────────────────────
                Row(
                  children: [
                    Text(
                      '${state.strokeWidth.toStringAsFixed(1)} px',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
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
