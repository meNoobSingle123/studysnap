import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nhom_7/features/notes/domain/utils/timestamp_helper.dart';
import 'package:nhom_7/features/timetable/domain/repositories/timetable_repository.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/l10n/strings.dart';
import '../../../../core/router/routes.dart';
import '../../../ai_assistant/presentation/widgets/ai_assistant_bottom_sheet.dart';
import '../../../ocr/ocr_scanner_page.dart';
import '../bloc/note_editor_bloc.dart';
import '../bloc/note_editor_event.dart';
import '../bloc/note_editor_state.dart';
import '../widgets/media/lecture_video_player.dart';
import 'canvas_page.dart';

class NoteEditorPage extends StatelessWidget {
  final String noteId;
  final String? subjectId;
  final String? slotId;

  const NoteEditorPage({
    super.key,
    required this.noteId,
    this.subjectId,
    this.slotId,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => getIt<NoteEditorBloc>()
        ..add(LoadNote(noteId, subjectId: subjectId, slotId: slotId)),
      child: const _NoteEditorView(),
    );
  }
}

class _NoteEditorView extends StatefulWidget {
  const _NoteEditorView();

  @override
  State<_NoteEditorView> createState() => _NoteEditorViewState();
}

class _NoteEditorViewState extends State<_NoteEditorView> {
  late final TextEditingController _titleController;
  late final TextEditingController _bodyController;
  late final FocusNode _titleFocusNode;
  late final FocusNode _bodyFocusNode;
  late final AppLifecycleListener _lifecycleListener;
  final GlobalKey<LectureVideoPlayerState> _videoKey =
      GlobalKey<LectureVideoPlayerState>();
  int _selectedVideoIndex = 0;
  bool _isInitialized = false;
  bool _isExiting = false;
  bool _canPop = false;
  String? _resolvedSubjectName;
  String? _resolvedSlotInfo;
  bool _isResolvingMetadata = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _bodyController = TextEditingController();
    _titleFocusNode = FocusNode();
    _bodyFocusNode = FocusNode();

    _bodyController.addListener(_onBodyTextChanged);

    _lifecycleListener = AppLifecycleListener(
      onPause: _saveIfUnsaved,
    );
  }

  void _onBodyTextChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _saveIfUnsaved() {
    if (!mounted) {
      return;
    }
    final bloc = context.read<NoteEditorBloc>();
    if (bloc.state is NoteEditorLoaded) {
      final state = bloc.state as NoteEditorLoaded;
      final hasChanges = state.hasUnsavedChanges ||
          _titleController.text != state.note.title ||
          _bodyController.text != state.note.bodyText;
      if (hasChanges && !state.isSaving) {
        bloc.add(
          UpdateContent(
            title: _titleController.text,
            bodyText: _bodyController.text,
          ),
        );
        bloc.add(const SaveNote());
      }
    }
  }

  Future<void> _handleBackNavigation() async {
    if (_isExiting) {
      return;
    }
    _isExiting = true;

    try {
      final bloc = context.read<NoteEditorBloc>();
      if (bloc.state is NoteEditorLoaded) {
        final state = bloc.state as NoteEditorLoaded;
        final hasChanges = state.hasUnsavedChanges ||
            _titleController.text != state.note.title ||
            _bodyController.text != state.note.bodyText;
        if (hasChanges && !state.isSaving) {
          final noteToSave = state.note.copyWith(
            title: _titleController.text,
            bodyText: _bodyController.text,
            updatedAt: DateTime.now(),
          );
          await bloc.saveNoteUseCase(noteToSave);
        }
      }
    } catch (_) {
      // In case of error, still allow pop
    } finally {
      if (mounted) {
        setState(() => _canPop = true);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Navigator.of(context).pop();
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    _bodyController.removeListener(_onBodyTextChanged);
    _titleFocusNode.dispose();
    _bodyFocusNode.dispose();
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  void _syncControllers(NoteEditorLoaded state) {
    if (!_isInitialized) {
      _titleController.text = state.note.title;
      _bodyController.text = state.note.bodyText;
      _isInitialized = true;
      _resolveMetadata(
        state.note.subjectId,
        state.note.slotId,
      );
    }
  }

  Future<void> _resolveMetadata(String subjectId, String? slotId) async {
    if (_isResolvingMetadata) return;
    _isResolvingMetadata = true;
    try {
      if (getIt.isRegistered<TimetableRepository>()) {
        final repo = getIt<TimetableRepository>();
        String? foundSubjectName;
        if (subjectId.isNotEmpty && subjectId != 'general') {
          final subjects = await repo.getSubjects();
          for (final s in subjects) {
            if (s.id == subjectId || s.name == subjectId) {
              foundSubjectName = s.name;
              break;
            }
          }
        }

        String? foundSlotInfo;
        if (slotId != null && slotId.isNotEmpty) {
          final slots = await repo.watchAllSlots().first;
          for (final s in slots) {
            if (s.id == slotId) {
              final startH = (s.startMin ~/ 60).toString().padLeft(2, '0');
              final startM = (s.startMin % 60).toString().padLeft(2, '0');
              final endH = (s.endMin ~/ 60).toString().padLeft(2, '0');
              final endM = (s.endMin % 60).toString().padLeft(2, '0');
              final roomStr = s.room.isNotEmpty ? ' (Phòng ${s.room})' : '';
              foundSlotInfo = '$startH:$startM - $endH:$endM$roomStr';
              break;
            }
          }
        }

        if (mounted) {
          setState(() {
            _resolvedSubjectName = foundSubjectName;
            _resolvedSlotInfo = foundSlotInfo;
          });

          // Tự động gán tiêu đề môn học nếu tiêu đề đang trống hoặc chứa UUID
          final currentTitle = _titleController.text.trim();
          final titleIsUuid = currentTitle.isEmpty ||
              currentTitle.contains(subjectId) ||
              currentTitle.startsWith('Ghi chú: 0') ||
              currentTitle.startsWith('Ghi chú: f') ||
              currentTitle.contains('-');
          if (titleIsUuid && foundSubjectName != null && foundSubjectName.isNotEmpty) {
            _titleController.text = 'Ghi chú: $foundSubjectName';
            context
                .read<NoteEditorBloc>()
                .add(UpdateContent(title: _titleController.text));
          }
        }
      }
    } catch (_) {
      // Bỏ qua lỗi tra cứu metadata nếu không có mạng / repo chưa sẵn sàng
    } finally {
      _isResolvingMetadata = false;
    }
  }

  void _insertTimestampAtCursor(Duration position) {
    final tag = TimestampHelper.format(position);
    final text = _bodyController.text;
    final selection = _bodyController.selection;

    int insertPos = selection.isValid ? selection.start : text.length;
    if (insertPos < 0 || insertPos > text.length) {
      insertPos = text.length;
    }

    final before = text.substring(0, insertPos);
    final after = text.substring(insertPos);
    final prefix = (before.isNotEmpty && !before.endsWith(' ')) ? ' ' : '';
    final suffix = (after.isNotEmpty && !after.startsWith(' ')) ? ' ' : '';
    final inserted = '$prefix$tag$suffix';

    final newText = '$before$inserted$after';
    final newCursor = insertPos + inserted.length;

    _bodyController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newCursor),
    );

    context.read<NoteEditorBloc>().add(UpdateContent(bodyText: newText));
  }

  Future<void> _pickMoreVideo() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickVideo(source: ImageSource.gallery);
      if (picked != null && mounted) {
        context.read<NoteEditorBloc>().add(AddVideo(picked.path));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể chọn video: $e')),
        );
      }
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      if (picked != null && mounted) {
        context.read<NoteEditorBloc>().add(AddImage(picked.path));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể chọn ảnh: $e')),
        );
      }
    }
  }

  Future<void> _showAddImageModal() async {
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
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Chọn ảnh từ Thư viện'),
              onTap: () {
                Navigator.of(sheetCtx).pop();
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openCanvas(String noteId, [String? existingImagePath]) async {
    Uint8List? bgBytes;
    if (existingImagePath != null) {
      try {
        final f = File(existingImagePath);
        if (await f.exists()) {
          bgBytes = await f.readAsBytes();
        }
      } catch (_) {}
    }
    if (!mounted) return;

    final savedPath = await Navigator.of(context).push<String?>(
      MaterialPageRoute(
        builder: (_) => CanvasPage(
          noteId: noteId,
          backgroundImage: bgBytes,
        ),
      ),
    );

    if (savedPath != null && savedPath.isNotEmpty && mounted) {
      context.read<NoteEditorBloc>().add(AddImage(savedPath));
    }
  }

  Future<void> _viewOrAnnotateImage(String noteId, String imagePath) async {
    final file = File(imagePath);
    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 360),
              child: Image.file(
                file,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => const Padding(
                  padding: EdgeInsets.all(32),
                  child: Icon(Icons.broken_image, size: 48, color: Colors.grey),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    label: const Text('Xóa ảnh', style: TextStyle(color: Colors.red)),
                    onPressed: () {
                      context.read<NoteEditorBloc>().add(RemoveImage(imagePath));
                      Navigator.of(dialogCtx).pop();
                    },
                  ),
                  FilledButton.icon(
                    icon: const Icon(Icons.draw_outlined),
                    label: const Text('Vẽ chú thích'),
                    onPressed: () {
                      Navigator.of(dialogCtx).pop();
                      _openCanvas(noteId, imagePath);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showSubjectPickerDialog(
      BuildContext context, String currentSubject) async {
    List<String> subjectOptions = [];
    try {
      if (getIt.isRegistered<TimetableRepository>()) {
        final list = await getIt<TimetableRepository>().getSubjects();
        subjectOptions =
            list.map((s) => s.name.isNotEmpty ? s.name : s.id).toList();
      }
    } catch (_) {}

    if (!subjectOptions.contains('Chung / Tự do')) {
      subjectOptions.insert(0, 'Chung / Tự do');
    }

    final customCtrl = TextEditingController(
      text: (currentSubject != 'general' && currentSubject != 'Chung / Tự do')
          ? currentSubject
          : '',
    );

    if (!context.mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.school_outlined, color: Colors.blue),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Gán môn học cho ghi chú',
                style: TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (subjectOptions.isNotEmpty) ...[
                const Text('Môn học trong thời khóa biểu:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: subjectOptions.map((subj) {
                    final isSel = currentSubject == subj ||
                        (currentSubject == 'general' && subj == 'Chung / Tự do');
                    return ChoiceChip(
                      label: Text(subj),
                      selected: isSel,
                      onSelected: (_) {
                        final val = subj == 'Chung / Tự do' ? 'general' : subj;
                        context.read<NoteEditorBloc>().add(UpdateSubject(val));
                        Navigator.of(dialogCtx).pop();
                      },
                    );
                  }).toList(),
                ),
                const Divider(height: 24),
              ],
              const Text('Hoặc nhập tên môn khác:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 8),
              TextField(
                controller: customCtrl,
                decoration: const InputDecoration(
                  hintText: 'VD: Lập trình di động, CSDL, AI...',
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () {
              final val = customCtrl.text.trim();
              if (val.isNotEmpty) {
                context.read<NoteEditorBloc>().add(UpdateSubject(val));
              }
              Navigator.of(dialogCtx).pop();
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isKeyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    return BlocConsumer<NoteEditorBloc, NoteEditorState>(
      listener: (context, state) {
        if (state is NoteEditorLoaded) {
          _syncControllers(state);
        } else if (state is NoteEditorFailure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message)),
          );
        }
      },
      builder: (context, state) {
        final isSaving = state is NoteEditorLoaded && state.isSaving;

        return PopScope(
          canPop: _canPop,
          onPopInvokedWithResult: (didPop, result) async {
            if (didPop) {
              return;
            }
            await _handleBackNavigation();
          },
          child: Scaffold(
            resizeToAvoidBottomInset: true,
            appBar: AppBar(
              leading: BackButton(
                onPressed: _handleBackNavigation,
              ),
              title: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(AppStrings.noteEditorTitle),
                  if (state is NoteEditorLoaded)
                    Text(
                      state.isSaving
                          ? AppStrings.savingStatus
                          : (state.isSaveSuccess && !state.hasUnsavedChanges
                              ? AppStrings.savedStatus
                              : ''),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: state.isSaving
                                ? Theme.of(context).colorScheme.primary
                                : Colors.green,
                          ),
                    ),
                ],
              ),
              actions: [
                // Nút Xuất PDF cho bài ghi chú hiện tại (CĐ 4 & S09)
                if (state is NoteEditorLoaded)
                  IconButton(
                    tooltip: 'Xuất PDF bài ghi chú',
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    onPressed: () async {
                      final currentNote = state.note;
                      final updated = currentNote.copyWith(
                        title: _titleController.text,
                        bodyText: _bodyController.text,
                        updatedAt: DateTime.now(),
                      );
                      await context.read<NoteEditorBloc>().saveNoteUseCase(updated);
                      if (context.mounted) {
                        context.push('${Routes.pdfExport}?noteId=${currentNote.id}');
                      }
                    },
                  ),
                // Nút Trợ lý AI: Tóm tắt & Sinh câu hỏi ôn tập
                IconButton(
                  tooltip: 'Trợ lý Học tập AI',
                  icon: const Icon(Icons.auto_awesome_rounded),
                  onPressed: () {
                    final content = _bodyController.text.trim();
                    if (content.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Vui lòng nhập nội dung bài học để AI tóm tắt hoặc tạo câu hỏi.',
                          ),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                      return;
                    }

                    AiAssistantBottomSheet.show(
                      context: context,
                      noteTitle: _titleController.text.trim(),
                      noteContent: content,
                      subjectName: _resolvedSubjectName,
                      onInsertToNote: (markdownText) {
                        final current = _bodyController.text;
                        final newContent = '$current$markdownText';
                        _bodyController.text = newContent;
                        context
                            .read<NoteEditorBloc>()
                            .add(UpdateContent(bodyText: newContent));
                      },
                    );
                  },
                ),
                // Nút OCR: chèn chữ từ ảnh vào vị trí con trỏ (CĐ 12 / FR-14)
                IconButton(
                  tooltip: 'Nhận diện chữ từ ảnh (OCR)',
                  icon: const Icon(Icons.document_scanner_outlined),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => OcrScannerPage(
                          onInsert: (text) {
                            final ctrl = _bodyController;
                            final old = ctrl.text;
                            final sel = ctrl.selection;
                            final pos = sel.isValid ? sel.start : old.length;
                            final newText = old.substring(0, pos) +
                                text +
                                old.substring(pos);
                            ctrl.value = TextEditingValue(
                              text: newText,
                              selection:
                                  TextSelection.collapsed(offset: pos + text.length),
                            );
                            context
                                .read<NoteEditorBloc>()
                                .add(UpdateContent(bodyText: newText));
                          },
                        ),
                      ),
                    );
                  },
                ),
                if (isSaving)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                    child: Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                else
                  TextButton.icon(
                    onPressed: () {
                      context.read<NoteEditorBloc>().add(
                            UpdateContent(
                              title: _titleController.text,
                              bodyText: _bodyController.text,
                            ),
                          );
                      context.read<NoteEditorBloc>().add(const SaveNote());
                    },
                    icon: const Icon(Icons.save_outlined),
                    label: const Text(AppStrings.save),
                  ),
              ],
            ),
            body: switch (state) {
              NoteEditorInitial() || NoteEditorLoading() => const Center(
                  child: CircularProgressIndicator(),
                ),
              NoteEditorFailure(:final message) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(message),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () {
                          context.read<NoteEditorBloc>().add(
                                LoadNote(
                                  (context.findAncestorWidgetOfExactType<NoteEditorPage>())
                                          ?.noteId ??
                                      '',
                                ),
                              );
                        },
                        child: const Text(AppStrings.retry),
                      ),
                    ],
                  ),
                ),
              NoteEditorLoaded() => LayoutBuilder(
                  builder: (context, constraints) {
                    final theme = Theme.of(context);
                    final videoList = state.note.videoPaths;
                    final hasVideo = videoList.isNotEmpty;
                    if (_selectedVideoIndex >= videoList.length && videoList.isNotEmpty) {
                      _selectedVideoIndex = videoList.length - 1;
                    }
                    final currentActiveVideo = hasVideo ? videoList[_selectedVideoIndex] : null;
                    final timestamps =
                        TimestampHelper.extractUniqueSorted(_bodyController.text);

                    return SingleChildScrollView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.manual,
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. Video Player
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeInOut,
                            height: (isKeyboardOpen && hasVideo) ? 68.0 : null,
                            alignment: (isKeyboardOpen && hasVideo)
                                ? Alignment.centerRight
                                : Alignment.topCenter,
                            child: LectureVideoPlayer(
                              key: _videoKey,
                              videoPath: currentActiveVideo,
                              timestamps: timestamps,
                              isMini: isKeyboardOpen && hasVideo,
                              onVideoChanged: (newPath) {
                                if (newPath == null && currentActiveVideo != null) {
                                  context
                                      .read<NoteEditorBloc>()
                                      .add(RemoveVideo(currentActiveVideo));
                                } else if (newPath != null) {
                                  context
                                      .read<NoteEditorBloc>()
                                      .add(AddVideo(newPath));
                                }
                              },
                              onInsertTimestamp: _insertTimestampAtCursor,
                            ),
                          ),

                          // 1.1 Khay Media Video cuộn ngang (Horizontal Tray)
                          if (hasVideo && !isKeyboardOpen)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              child: SizedBox(
                                height: 60,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: videoList.length + 1,
                                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                                  itemBuilder: (context, index) {
                                    if (index == videoList.length) {
                                      return OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          padding: const EdgeInsets.symmetric(horizontal: 12),
                                        ),
                                        icon: const Icon(Icons.add_circle_outline, size: 18),
                                        label: const Text('Thêm clip'),
                                        onPressed: _pickMoreVideo,
                                      );
                                    }
                                    final path = videoList[index];
                                    final isSelected = index == _selectedVideoIndex;
                                    final fileName = path.split('/').last;

                                    return Material(
                                      color: isSelected
                                          ? theme.colorScheme.primaryContainer
                                          : theme.colorScheme.surfaceContainerLow,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        side: BorderSide(
                                          color: isSelected
                                              ? theme.colorScheme.primary
                                              : theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
                                          width: isSelected ? 1.5 : 1,
                                        ),
                                      ),
                                      child: InkWell(
                                        onTap: () {
                                          setState(() => _selectedVideoIndex = index);
                                        },
                                        borderRadius: BorderRadius.circular(8),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          constraints: const BoxConstraints(maxWidth: 160),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                isSelected
                                                    ? Icons.play_circle_fill
                                                    : Icons.play_circle_outline,
                                                color: isSelected
                                                    ? theme.colorScheme.primary
                                                    : theme.colorScheme.onSurfaceVariant,
                                                size: 22,
                                              ),
                                              const SizedBox(width: 6),
                                              Expanded(
                                                child: Column(
                                                  mainAxisSize: MainAxisSize.min,
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      'Clip #${index + 1}',
                                                      style: theme.textTheme.labelMedium?.copyWith(
                                                        fontWeight: isSelected
                                                            ? FontWeight.bold
                                                            : FontWeight.w600,
                                                        color: isSelected
                                                            ? theme.colorScheme.onPrimaryContainer
                                                            : null,
                                                      ),
                                                    ),
                                                    Text(
                                                      fileName,
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: theme.textTheme.bodySmall?.copyWith(
                                                        fontSize: 10,
                                                        color: theme.colorScheme.outline,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.close, size: 16),
                                                padding: EdgeInsets.zero,
                                                constraints: const BoxConstraints(),
                                                tooltip: 'Xóa clip',
                                                onPressed: () {
                                                  context
                                                      .read<NoteEditorBloc>()
                                                      .add(RemoveVideo(path));
                                                },
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),

                          // 2. Metadata Linkage Chips & Quick Action Chips (Always stable!)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                // Chip Môn học (cho phép bấm chọn hoặc xóa gán môn)
                                if (state.note.subjectId.isNotEmpty &&
                                    state.note.subjectId != 'general')
                                  InputChip(
                                    avatar: const Icon(
                                      Icons.school,
                                      size: 16,
                                      color: Colors.blue,
                                    ),
                                    label: Text(
                                      '${AppStrings.pinnedSubject}: ${_resolvedSubjectName ?? state.note.subjectId}',
                                    ),
                                    onPressed: () => _showSubjectPickerDialog(
                                      context,
                                      state.note.subjectId,
                                    ),
                                    onDeleted: () {
                                      setState(() => _resolvedSubjectName = null);
                                      context
                                          .read<NoteEditorBloc>()
                                          .add(const UpdateSubject('general'));
                                    },
                                    visualDensity: VisualDensity.compact,
                                  )
                                else
                                  ActionChip(
                                    avatar: const Icon(
                                      Icons.school_outlined,
                                      size: 16,
                                    ),
                                    label: const Text('Chọn môn'),
                                    onPressed: () => _showSubjectPickerDialog(
                                      context,
                                      state.note.subjectId,
                                    ),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                if (state.note.slotId != null &&
                                    state.note.slotId!.isNotEmpty)
                                  Chip(
                                    avatar: const Icon(
                                      Icons.access_time_outlined,
                                      size: 16,
                                    ),
                                    label: Text(
                                      '${AppStrings.pinnedSlot}: ${_resolvedSlotInfo ?? state.note.slotId}',
                                    ),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                // Nút Thêm ảnh bài giảng
                                ActionChip(
                                  avatar: const Icon(
                                    Icons.add_a_photo_outlined,
                                    size: 16,
                                  ),
                                  label: const Text('Thêm ảnh'),
                                  onPressed: _showAddImageModal,
                                  visualDensity: VisualDensity.compact,
                                ),
                                // Nút Gắn video bài giảng
                                ActionChip(
                                  avatar: Icon(
                                    videoList.isNotEmpty
                                        ? Icons.video_collection_rounded
                                        : Icons.video_call_outlined,
                                    size: 16,
                                    color: videoList.isNotEmpty
                                        ? Colors.deepPurple
                                        : null,
                                  ),
                                  label: Text(
                                    videoList.isNotEmpty
                                        ? 'Video (${videoList.length})'
                                        : 'Thêm video',
                                  ),
                                  onPressed: _pickMoreVideo,
                                  visualDensity: VisualDensity.compact,
                                ),
                                // Nút Trợ lý Gemini AI
                                ActionChip(
                                  avatar: const Icon(
                                    Icons.auto_awesome_rounded,
                                    size: 16,
                                    color: Color(0xFF5E48E8),
                                  ),
                                  label: const Text('Trợ lý AI ✨'),
                                  onPressed: () {
                                    final content = _bodyController.text.trim();
                                    if (content.isEmpty) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Vui lòng nhập nội dung bài học để AI tóm tắt hoặc tạo câu hỏi.',
                                          ),
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                      return;
                                    }

                                    AiAssistantBottomSheet.show(
                                      context: context,
                                      noteTitle: _titleController.text.trim(),
                                      noteContent: content,
                                      subjectName: _resolvedSubjectName,
                                      onInsertToNote: (markdownText) {
                                        final current = _bodyController.text;
                                        final newContent = '$current$markdownText';
                                        _bodyController.text = newContent;
                                        context
                                            .read<NoteEditorBloc>()
                                            .add(UpdateContent(bodyText: newContent));
                                      },
                                    );
                                  },
                                  visualDensity: VisualDensity.compact,
                                ),
                                // Nút Vẽ tay Canvas (S07)
                                ActionChip(
                                  avatar: const Icon(
                                    Icons.draw_outlined,
                                    size: 16,
                                  ),
                                  label: const Text('Vẽ tay'),
                                  onPressed: () => _openCanvas(state.note.id),
                                  visualDensity: VisualDensity.compact,
                                ),
                              ],
                            ),
                          ),

                          // 2.1 Khay ảnh đính kèm (Horizontal Image Tray)
                          if (state.note.imagePaths.isNotEmpty)
                            Container(
                              height: 96,
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: state.note.imagePaths.length + 1,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(width: 8),
                                itemBuilder: (context, index) {
                                  if (index == state.note.imagePaths.length) {
                                    return OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12),
                                      ),
                                      icon: const Icon(
                                          Icons.add_photo_alternate_outlined,
                                          size: 18),
                                      label: const Text('Thêm ảnh'),
                                      onPressed: _showAddImageModal,
                                    );
                                  }
                                  final imgPath = state.note.imagePaths[index];
                                  final file = File(imgPath);
                                  return Stack(
                                    children: [
                                      InkWell(
                                        onTap: () => _viewOrAnnotateImage(
                                            state.note.id, imgPath),
                                        borderRadius: BorderRadius.circular(8),
                                        child: Container(
                                          width: 88,
                                          height: 88,
                                          decoration: BoxDecoration(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            border: Border.all(
                                              color: theme
                                                  .colorScheme.outlineVariant
                                                  .withValues(alpha: 0.6),
                                            ),
                                          ),
                                          clipBehavior: Clip.antiAlias,
                                          child: Image.file(
                                            file,
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (context, error, stackTrace) =>
                                                    const Center(
                                              child: Icon(Icons.broken_image,
                                                  size: 24, color: Colors.grey),
                                            ),
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        top: 2,
                                        right: 2,
                                        child: Material(
                                          color: Colors.black54,
                                          shape: const CircleBorder(),
                                          child: InkWell(
                                            customBorder: const CircleBorder(),
                                            onTap: () {
                                              context
                                                  .read<NoteEditorBloc>()
                                                  .add(RemoveImage(imgPath));
                                            },
                                            child: const Padding(
                                              padding: EdgeInsets.all(3.0),
                                              child: Icon(Icons.close,
                                                  size: 14,
                                                  color: Colors.white),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),

                          // 3. Note Title TextField
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  key: const ValueKey('note_title_field'),
                                  controller: _titleController,
                                  focusNode: _titleFocusNode,
                                  autofocus: false,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleLarge
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                  decoration: const InputDecoration(
                                    hintText: AppStrings.noteTitleHint,
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                  onChanged: (value) {
                                    context.read<NoteEditorBloc>().add(
                                          UpdateContent(title: value),
                                        );
                                  },
                                ),
                              ),
                            ],
                          ),

                          // Quick Timestamp button when typing with keyboard open
                          if (isKeyboardOpen && hasVideo)
                            Padding(
                              padding:
                                  const EdgeInsets.only(top: 4, bottom: 4),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: ActionChip(
                                  avatar: const Icon(
                                    Icons.bookmark_add_outlined,
                                    size: 16,
                                  ),
                                  label: const Text(
                                      AppStrings.videoTimestampButton),
                                  onPressed: () {
                                    _videoKey.currentState
                                        ?.insertCurrentTimestamp();
                                  },
                                ),
                              ),
                            ),

                          const Divider(height: 16),



                          // 5. Note Body TextField
                          TextField(
                            key: const ValueKey('note_content_field'),
                            controller: _bodyController,
                            focusNode: _bodyFocusNode,
                            autofocus: false,
                            maxLines: null,
                            minLines: 10,
                            textAlignVertical: TextAlignVertical.top,
                            style: Theme.of(context).textTheme.bodyLarge,
                            decoration: const InputDecoration(
                              hintText: AppStrings.noteContentHint,
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                            ),
                            onChanged: (value) {
                              context.read<NoteEditorBloc>().add(
                                    UpdateContent(bodyText: value),
                                  );
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
            },
          ),
        );
      },
    );
  }
}
