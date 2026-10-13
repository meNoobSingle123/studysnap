import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/l10n/strings.dart';
import '../../domain/entities/stroke.dart';
import '../bloc/canvas_bloc.dart';
import '../bloc/canvas_event.dart';
import '../bloc/canvas_state.dart';
import '../utils/canvas_image_exporter.dart';
import '../widgets/canvas/canvas_drawing_board.dart';
import '../widgets/canvas/canvas_toolbar.dart';

/// Fullscreen canvas page (S07) combining [CanvasDrawingBoard] with
/// [CanvasToolbar] and raster export via [CanvasImageExporter].
class CanvasPage extends StatelessWidget {
  final String? noteId;
  final Size originalImageSize;
  final Widget? backgroundImage;
  final Future<void> Function(List<Stroke> strokes, Uint8List? flatBytes)? onSave;

  const CanvasPage({
    super.key,
    this.noteId,
    this.originalImageSize = const Size(1080, 1920),
    this.backgroundImage,
    this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<CanvasBloc>(),
      child: _CanvasPageView(
        noteId: noteId,
        originalImageSize: originalImageSize,
        backgroundImage: backgroundImage,
        onSave: onSave,
      ),
    );
  }
}

class _CanvasPageView extends StatefulWidget {
  final String? noteId;
  final Size originalImageSize;
  final Widget? backgroundImage;
  final Future<void> Function(List<Stroke> strokes, Uint8List? flatBytes)? onSave;

  const _CanvasPageView({
    this.noteId,
    required this.originalImageSize,
    this.backgroundImage,
    this.onSave,
  });

  @override
  State<_CanvasPageView> createState() => _CanvasPageViewState();
}

class _CanvasPageViewState extends State<_CanvasPageView> {
  bool _isSaving = false;

  Future<void> _handleSave(CanvasState state) async {
    setState(() => _isSaving = true);
    try {
      final bytes = await CanvasImageExporter.exportToBytes(
        strokes: state.strokes,
        targetSize: widget.originalImageSize,
      );

      if (widget.onSave != null) {
        await widget.onSave!(state.strokes, bytes);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.canvasExportSuccess)),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<bool> _confirmDiscard(CanvasState state) async {
    if (state.strokes.isEmpty) return true;

    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(AppStrings.canvasDiscardConfirmTitle),
        content: const Text(AppStrings.canvasDiscardConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(AppStrings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(AppStrings.ok),
          ),
        ],
      ),
    );

    return shouldLeave ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<CanvasBloc>();

    return BlocBuilder<CanvasBloc, CanvasState>(
      builder: (context, state) {
        return PopScope(
          canPop: state.strokes.isEmpty,
          onPopInvokedWithResult: (didPop, _) async {
            if (didPop) return;
            final canLeave = await _confirmDiscard(state);
            if (canLeave && context.mounted) {
              Navigator.of(context).pop();
            }
          },
          child: Scaffold(
            appBar: AppBar(
              title: const Text(AppStrings.canvasPageTitle),
              actions: [
                if (_isSaving)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                else
                  TextButton.icon(
                    onPressed: () => _handleSave(state),
                    icon: const Icon(Icons.check_rounded),
                    label: const Text(AppStrings.save),
                  ),
              ],
            ),
            body: Column(
              children: [
                // Drawing Canvas Area
                Expanded(
                  child: CanvasDrawingBoard(
                    strokes: state.strokes,
                    originalImageSize: widget.originalImageSize,
                    backgroundImage: widget.backgroundImage,
                    activeTool: state.selectedTool,
                    activeColor: Color(state.selectedColor),
                    activeWidthScene: state.strokeWidth,
                    onStrokeAdded: (stroke) => bloc.add(AddStrokeEvent(stroke)),
                    onUndo: () => bloc.add(const UndoEvent()),
                    onRedo: () => bloc.add(const RedoEvent()),
                  ),
                ),

                // Bottom Floating / Docked Toolbar
                CanvasToolbar(bloc: bloc),
              ],
            ),
          ),
        );
      },
    );
  }
}
