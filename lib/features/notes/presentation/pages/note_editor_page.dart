import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/l10n/strings.dart';
import '../../../../core/router/routes.dart';
import 'package:nhom_7/features/notes/domain/utils/timestamp_helper.dart';
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
    if (mounted) setState(() {});
  }

  void _saveIfUnsaved() {
    if (!mounted) return;
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
    if (_isExiting) return;
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
        final hasLinkage = state is NoteEditorLoaded &&
            ((state.note.subjectId.isNotEmpty &&
                    state.note.subjectId != 'general') ||
                (state.note.slotId != null && state.note.slotId!.isNotEmpty));

        return PopScope(
          canPop: _canPop,
          onPopInvokedWithResult: (didPop, result) async {
            if (didPop) return;
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
                    final hasVideo = state.note.videoPath != null &&
                        state.note.videoPath!.isNotEmpty;
                    final timestamps =
                        TimestampHelper.extractUniqueSorted(_bodyController.text);

                    return SingleChildScrollView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.manual,
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. Video Player — luôn tồn tại trong cây, AnimatedContainer
                          //    co chiều cao mượt mà thay vì unmount/mount lại.
                          //    Khi bàn phím mở: mini 68dp (góc phải).
                          //    Khi bàn phím đóng: full height tự nhiên.
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeInOut,
                            height: (isKeyboardOpen && hasVideo) ? 68.0 : null,
                            alignment: (isKeyboardOpen && hasVideo)
                                ? Alignment.centerRight
                                : Alignment.topCenter,
                            child: LectureVideoPlayer(
                              key: _videoKey,
                              videoPath: state.note.videoPath,
                              timestamps: timestamps,
                              isMini: isKeyboardOpen && hasVideo,
                              onVideoChanged: (newPath) {
                                context
                                    .read<NoteEditorBloc>()
                                    .add(AttachVideo(newPath));
                              },
                              onInsertTimestamp: _insertTimestampAtCursor,
                            ),
                          ),

                          // 2. Metadata Linkage Chips (Subject & Slot)
                          if (hasLinkage && !isKeyboardOpen)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: Wrap(
                                spacing: 8,
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
                                ],
                              ),
                            ),

                          // 3. Note Title TextField
                          //    ValueKey khóa cứng Element/State để Flutter
                          //    không bao giờ unmount ô này khi viewport thay đổi.
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
                          //    ValueKey khóa cứng Element/State, tránh unmount.
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
