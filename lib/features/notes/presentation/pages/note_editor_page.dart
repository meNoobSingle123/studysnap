import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nhom_7/features/notes/domain/utils/timestamp_helper.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/l10n/strings.dart';
import '../../../../core/router/routes.dart';
import '../../../ocr/ocr_scanner_page.dart';
import '../bloc/note_editor_bloc.dart';
import '../bloc/note_editor_event.dart';
import '../bloc/note_editor_state.dart';
import '../widgets/media/lecture_video_player.dart';

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
      onInactive: _saveIfUnsaved,
      onHide: _saveIfUnsaved,
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

  Future<void> _showLocationDialog(
      BuildContext context, String? currentLocation) async {
    final ctrl = TextEditingController(text: currentLocation ?? '');
    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.place_outlined, color: Colors.red),
            SizedBox(width: 8),
            Text('Vị trí học tập'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ctrl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Nơi ngồi học / ghi chép',
                hintText: 'VD: Thư viện, Lab 2, Tầng 3...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              icon: const Icon(Icons.my_location),
              label: const Text('Lấy tọa độ GPS thực tế'),
              onPressed: () async {
                try {
                  bool serviceEnabled =
                      await Geolocator.isLocationServiceEnabled();
                  if (!serviceEnabled) {
                    if (dialogCtx.mounted) {
                      ScaffoldMessenger.of(dialogCtx).showSnackBar(
                        const SnackBar(
                            content: Text('Vui lòng bật định vị GPS')),
                      );
                    }
                    return;
                  }
                  LocationPermission perm = await Geolocator.checkPermission();
                  if (perm == LocationPermission.denied) {
                    perm = await Geolocator.requestPermission();
                    if (perm == LocationPermission.denied) return;
                  }
                  final pos = await Geolocator.getCurrentPosition(
                    locationSettings:
                        const LocationSettings(timeLimit: Duration(seconds: 5)),
                  );
                  ctrl.text =
                      'GPS: ${pos.latitude.toStringAsFixed(3)}, ${pos.longitude.toStringAsFixed(3)}';
                } catch (_) {
                  ctrl.text = 'GPS: Khuôn viên trường';
                }
              },
            ),
          ],
        ),
        actions: [
          if (currentLocation != null)
            TextButton(
              onPressed: () {
                context.read<NoteEditorBloc>().add(const UpdateLocation(null));
                Navigator.of(dialogCtx).pop();
              },
              child:
                  const Text('Xóa vị trí', style: TextStyle(color: Colors.red)),
            ),
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () {
              final val = ctrl.text.trim();
              context
                  .read<NoteEditorBloc>()
                  .add(UpdateLocation(val.isNotEmpty ? val : null));
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

                          // 2. Metadata Linkage Chips & Vị trí học tập
                          if (!isKeyboardOpen)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  if (state.note.subjectId.isNotEmpty &&
                                      state.note.subjectId != 'general')
                                    Chip(
                                      avatar: const Icon(
                                        Icons.school_outlined,
                                        size: 16,
                                      ),
                                      label: Text(
                                        '${AppStrings.pinnedSubject}: ${state.note.subjectId}',
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
                                        '${AppStrings.pinnedSlot}: ${state.note.slotId}',
                                      ),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  // Chip Vị trí học tập
                                  if (state.note.location != null &&
                                      state.note.location!.isNotEmpty)
                                    InputChip(
                                      avatar: const Icon(
                                        Icons.place,
                                        size: 16,
                                        color: Colors.red,
                                      ),
                                      label: Text(state.note.location!),
                                      onDeleted: () {
                                        context
                                            .read<NoteEditorBloc>()
                                            .add(const UpdateLocation(null));
                                      },
                                      onPressed: () => _showLocationDialog(
                                          context, state.note.location),
                                      visualDensity: VisualDensity.compact,
                                    )
                                  else
                                    ActionChip(
                                      avatar: const Icon(
                                        Icons.add_location_alt_outlined,
                                        size: 16,
                                      ),
                                      label: const Text('📍 Vị trí'),
                                      onPressed: () =>
                                          _showLocationDialog(context, null),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                ],
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

                          // 4. Canvas Drawing Attachment (S07 Entrypoint)
                          if (!isKeyboardOpen && !hasVideo)
                            Card(
                              elevation: 0,
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest,
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: ListTile(
                                leading: const Icon(Icons.draw_outlined),
                                title: const Text(
                                  AppStrings.canvasAttachmentTitle,
                                ),
                                subtitle: const Text(
                                  AppStrings.canvasAddAttachment,
                                ),
                                trailing: const Icon(
                                  Icons.arrow_forward_ios,
                                  size: 14,
                                ),
                                onTap: () {
                                  context.push(
                                    Routes.canvasRoute(
                                      noteId: state.note.id,
                                    ),
                                  );
                                },
                              ),
                            ),

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
