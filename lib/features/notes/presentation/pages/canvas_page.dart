import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/l10n/strings.dart';
import '../../domain/entities/stroke.dart';
import '../../domain/repositories/note_repository.dart';
import '../bloc/canvas_bloc.dart';
import '../bloc/canvas_event.dart';
import '../bloc/canvas_state.dart';
import '../utils/canvas_image_exporter.dart';
import '../widgets/canvas/canvas_drawing_board.dart';
import '../widgets/canvas/canvas_toolbar.dart';

/// Màn hình vẽ và chú thích trên canvas S07 theo đặc tả CĐ 7 (mục 5.2, 5.3, 6.2).
/// Hỗ trợ vẽ nét bút/highlight, tẩy xóa, undo/redo, xuất ảnh độ phân giải gốc.
class CanvasPage extends StatelessWidget {
  final String? noteId;
  final Size originalImageSize;
  final Uint8List? backgroundImage;
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
      create: (context) {
        final getIt = GetIt.instance;
        if (getIt.isRegistered<CanvasBloc>()) {
          return getIt<CanvasBloc>();
        }
        return CanvasBloc();
      },
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
  final Uint8List? backgroundImage;
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
  bool _hasUnsavedChanges = false;
  Uint8List? _backgroundImage;

  @override
  void initState() {
    super.initState();
    _backgroundImage = widget.backgroundImage;
  }

  Future<ui.Image?> _loadUiImage(Uint8List? bytes) async {
    if (bytes == null || bytes.isEmpty) return null;
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  Future<void> _pickBackgroundImage() async {
    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Chụp ảnh từ Camera'),
              onTap: () {
                Navigator.of(sheetCtx).pop();
                _pickImageFromSource(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Chọn ảnh từ Thư viện'),
              onTap: () {
                Navigator.of(sheetCtx).pop();
                _pickImageFromSource(ImageSource.gallery);
              },
            ),
            if (_backgroundImage != null)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Xóa ảnh nền hiện tại',
                    style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.of(sheetCtx).pop();
                  setState(() {
                    _backgroundImage = null;
                    _hasUnsavedChanges = true;
                  });
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImageFromSource(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 85,
      );
      if (picked != null) {
        final bytes = await File(picked.path).readAsBytes();
        if (mounted) {
          setState(() {
            _backgroundImage = bytes;
            _hasUnsavedChanges = true;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể nạp ảnh: $e')),
        );
      }
    }
  }

  Future<void> _handleSave(CanvasState state) async {
    setState(() => _isSaving = true);
    try {
      ui.Image? baseUiImage;
      if (_backgroundImage != null) {
        try {
          baseUiImage = await _loadUiImage(_backgroundImage);
        } catch (_) {}
      }

      final bytes = await CanvasImageExporter.exportToBytes(
        strokes: state.strokes,
        targetSize: widget.originalImageSize,
        baseImage: baseUiImage,
      );

      String? savedPath;
      if (bytes != null) {
        try {
          final docsDir = await getApplicationDocumentsDirectory();
          final fileName = 'canvas_${const Uuid().v4()}.png';
          final file = File('${docsDir.path}/$fileName');
          await file.writeAsBytes(bytes, flush: true);
          savedPath = file.path;

          if (widget.noteId != null && GetIt.instance.isRegistered<NoteRepository>()) {
            final noteRepo = GetIt.instance<NoteRepository>();
            final note = await noteRepo.getNoteById(widget.noteId!);
            if (note != null) {
              final updatedImages = [...note.imagePaths, savedPath];
              await noteRepo.saveNote(note.copyWith(
                imagePaths: updatedImages,
                updatedAt: DateTime.now(),
              ));
            }
          }
        } catch (_) {
          // Fallback an toàn nếu có sự cố IO
        }
      }

      if (widget.onSave != null) {
        await widget.onSave!(state.strokes, bytes);
      }

      if (mounted) {
        setState(() {
          _hasUnsavedChanges = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.canvasExportSuccess)),
        );
        Navigator.of(context).pop(savedPath);
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<bool> _confirmDiscard(CanvasState state) async {
    if (!_hasUnsavedChanges) {
      return true;
    }

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

    return BlocConsumer<CanvasBloc, CanvasState>(
      listenWhen: (prev, curr) => prev.strokes != curr.strokes,
      listener: (context, state) {
        if (!_hasUnsavedChanges && state.strokes.isNotEmpty) {
          setState(() => _hasUnsavedChanges = true);
        }
      },
      builder: (context, state) {
        return PopScope(
          canPop: !_hasUnsavedChanges,
          onPopInvokedWithResult: (didPop, _) async {
            if (didPop) {
              return;
            }
            final canLeave = await _confirmDiscard(state);
            if (canLeave && context.mounted) {
              Navigator.of(context).pop();
            }
          },
          child: Scaffold(
            appBar: AppBar(
              title: const Text(AppStrings.canvasPageTitle),
              leading: const BackButton(),
              actions: [
                IconButton(
                  tooltip: 'Thêm ảnh nền để vẽ',
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  onPressed: _pickBackgroundImage,
                ),
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
                    backgroundImage: _backgroundImage != null
                        ? Image.memory(_backgroundImage!,
                            fit: BoxFit.contain)
                        : null,
                    activeTool: state.selectedTool,
                    activeColor: Color(state.selectedColor),
                    activeWidthScene: state.strokeWidth,
                    onStrokeAdded: (stroke) {
                      setState(() => _hasUnsavedChanges = true);
                      bloc.add(AddStrokeEvent(stroke));
                    },
                    onUndo: () {
                      setState(() => _hasUnsavedChanges = true);
                      bloc.add(const UndoEvent());
                    },
                    onRedo: () {
                      setState(() => _hasUnsavedChanges = true);
                      bloc.add(const RedoEvent());
                    },
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
