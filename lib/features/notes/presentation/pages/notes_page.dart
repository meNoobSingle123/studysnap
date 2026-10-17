import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/l10n/strings.dart';
import '../../../../core/router/routes.dart';
import '../../../timetable/domain/entities/subject.dart';
import '../../data/repositories/in_memory_note_repository.dart';
import '../../domain/entities/lecture_note.dart';
import '../../domain/repositories/note_repository.dart';
import '../bloc/note_list_bloc.dart';
import '../bloc/note_list_event.dart';
import '../bloc/note_list_state.dart';

class NotesPage extends StatefulWidget {
  final NoteRepository? repository;

  const NotesPage({super.key, this.repository});

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  late final NoteRepository _repository;
  List<LectureNote> _notes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ??
        (getIt.isRegistered<NoteRepository>()
            ? getIt<NoteRepository>()
            : InMemoryNoteRepository());
    if (widget.repository != null) {
      _loadNotes();
    }
  }

  Future<void> _loadNotes() async {
    try {
      final list = await _repository.getAllNotes();
      if (mounted) {
        setState(() {
          _notes = list;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _openNoteEditor(String noteId) async {
    await context.push(Routes.noteEdit(noteId));
    if (widget.repository != null) {
      await _loadNotes();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.repository != null) {
      return _buildTeamNotesView();
    }

    return BlocProvider(
      create: (_) => getIt<NoteListBloc>()..add(const LoadNotesStarted()),
      child: const _HuyNotesView(),
    );
  }

  Widget _buildTeamNotesView() {
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');


    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.notesTab),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notes.isEmpty
              ? const Center(
                  child: Text(AppStrings.emptyNotesList),
                )
              : RefreshIndicator(
                  onRefresh: _loadNotes,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16.0),
                    itemCount: _notes.length,
                    itemBuilder: (context, index) {
                      final note = _notes[index];
                      final displayTitle = note.title.trim().isNotEmpty
                          ? note.title
                          : AppStrings.newNote;
                      final displayBody = note.bodyText.trim().isNotEmpty
                          ? note.bodyText
                          : AppStrings.noteContentHint;
                      final dateStr = dateFormat.format(note.updatedAt);

                      return Card(
                        elevation: 1,
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => _openNoteEditor(note.id),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        displayTitle,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const Icon(
                                      Icons.chevron_right,
                                      color: Colors.grey,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  displayBody,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                      ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.access_time,
                                      size: 14,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .outline,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      dateStr,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .outline,
                                          ),
                                    ),
                                    const Spacer(),
                                    if (note.videoPath != null &&
                                        note.videoPath!.isNotEmpty) ...[
                                      const Icon(
                                        Icons.videocam_outlined,
                                        size: 16,
                                        color: Colors.blueGrey,
                                      ),
                                      const SizedBox(width: 8),
                                    ],
                                    if (note.subjectId.isNotEmpty &&
                                        note.subjectId != 'general')
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .surfaceContainerHighest,
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          note.subjectId,
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelSmall,
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          final newNoteId = const Uuid().v4();
          _openNoteEditor(newNoteId);
        },
        icon: const Icon(Icons.add),
        label: const Text(AppStrings.createNote),
      ),
    );
  }
}

class _HuyNotesView extends StatefulWidget {

  const _HuyNotesView();

  @override
  State<_HuyNotesView> createState() => _HuyNotesViewState();
}

class _HuyNotesViewState extends State<_HuyNotesView> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null && mounted) {
      context.read<NoteListBloc>().add(FilterDateChanged(picked));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.notesTab),
        actions: [
          IconButton(
            tooltip: AppStrings.pdfExportTitle,
            icon: const Icon(Icons.picture_as_pdf_outlined),
            onPressed: () => context.push(Routes.pdfExportRoute()),
          ),
          BlocBuilder<NoteListBloc, NoteListState>(
            builder: (context, state) {
              return PopupMenuButton<NoteSortOption>(
                icon: const Icon(Icons.sort_rounded),
                tooltip: 'Sắp xếp ghi chú',
                initialValue: state.sortOption,
                onSelected: (option) {
                  context.read<NoteListBloc>().add(SortOptionChanged(option));
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: NoteSortOption.newestFirst,
                    child: Text(AppStrings.sortNewest),
                  ),
                  const PopupMenuItem(
                    value: NoteSortOption.oldestFirst,
                    child: Text(AppStrings.sortOldest),
                  ),
                  const PopupMenuItem(
                    value: NoteSortOption.titleAz,
                    child: Text(AppStrings.sortTitleAz),
                  ),
                ],
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. Search Box
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: AppStrings.searchNotesHint,
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          _searchController.clear();
                          context
                              .read<NoteListBloc>()
                              .add(const SearchQueryChanged(''));
                          setState(() {});
                        },
                      )
                    : null,
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              onChanged: (query) {
                context.read<NoteListBloc>().add(SearchQueryChanged(query));
                setState(() {});
              },
            ),
          ),

          // 2. Filter Bar (Subjects & Date)
          BlocBuilder<NoteListBloc, NoteListState>(
            builder: (context, state) {
              return SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    // "All Subjects" chip
                    ChoiceChip(
                      label: const Text(AppStrings.allSubjects),
                      selected: state.selectedSubjectId == null,
                      onSelected: (selected) {
                        if (selected) {
                          context
                              .read<NoteListBloc>()
                              .add(const FilterSubjectChanged(null));
                        }
                      },
                    ),
                    const SizedBox(width: 8),

                    // Subjects chips
                    ...state.subjectsMap.values.map((subject) {
                      final isSelected = state.selectedSubjectId == subject.id;
                      final color = Color(subject.colorArgb);
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          avatar: CircleAvatar(
                            backgroundColor: color,
                            radius: 6,
                          ),
                          label: Text(subject.name),
                          selected: isSelected,
                          onSelected: (_) {
                            context
                                .read<NoteListBloc>()
                                .add(FilterSubjectChanged(subject.id));
                          },
                        ),
                      );
                    }),

                    // Date filter chip
                    if (state.selectedDate == null)
                      ActionChip(
                        avatar: const Icon(Icons.calendar_today_outlined, size: 16),
                        label: const Text(AppStrings.filterByDate),
                        onPressed: _pickDate,
                      )
                    else
                      InputChip(
                        avatar: const Icon(Icons.calendar_today, size: 16),
                        label: Text(
                          '${state.selectedDate!.day.toString().padLeft(2, '0')}/${state.selectedDate!.month.toString().padLeft(2, '0')}/${state.selectedDate!.year}',
                        ),
                        selected: true,
                        onDeleted: () {
                          context
                              .read<NoteListBloc>()
                              .add(const FilterDateChanged(null));
                        },
                      ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 8),

          // 3. Notes List or Empty View
          Expanded(
            child: BlocBuilder<NoteListBloc, NoteListState>(
              builder: (context, state) {
                if (state.status == NoteListStatus.loading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (state.status == NoteListStatus.failure) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline_rounded,
                          size: 48,
                          color: theme.colorScheme.error,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          state.errorMessage ?? AppStrings.cannotLoadNotes,
                          style: theme.textTheme.bodyLarge,
                        ),
                      ],
                    ),
                  );
                }

                if (state.filteredNotes.isEmpty) {
                  final isFiltering = state.searchQuery.isNotEmpty ||
                      state.selectedSubjectId != null ||
                      state.selectedDate != null;

                  return Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isFiltering
                                ? Icons.filter_list_off_rounded
                                : Icons.note_alt_outlined,
                            size: 64,
                            color: theme.colorScheme.outlineVariant,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            isFiltering
                                ? AppStrings.noMatchingNotes
                                : AppStrings.emptyNotesList,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            isFiltering
                                ? 'Thử tìm kiếm với từ khóa khác hoặc xóa bộ lọc'
                                : 'Nhấn nút "+" bên dưới để tạo ghi chú bài giảng đầu tiên',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.outline,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                  itemCount: state.filteredNotes.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final note = state.filteredNotes[index];
                    final subject = state.subjectsMap[note.subjectId];

                    return _NoteCard(
                      note: note,
                      subject: subject,
                      onTap: () async {
                        await context.push(Routes.noteEdit(note.id));
                        if (context.mounted) {
                          context.read<NoteListBloc>().add(const LoadNotesStarted());
                        }
                      },
                      onDelete: () => _confirmDelete(context, note.id),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final newNoteId = const Uuid().v4();
          await context.push(Routes.noteEdit(newNoteId));
          if (context.mounted) {
            context.read<NoteListBloc>().add(const LoadNotesStarted());
          }
        },
        icon: const Icon(Icons.add),
        label: const Text(AppStrings.createNote),
      ),
    );

  }

  void _confirmDelete(BuildContext context, String noteId) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text(AppStrings.deleteNoteConfirmTitle),
        content: const Text(AppStrings.deleteNoteConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text(AppStrings.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () {
              Navigator.of(dialogCtx).pop();
              context.read<NoteListBloc>().add(DeleteNoteRequested(noteId));
            },
            child: const Text(AppStrings.delete),
          ),
        ],
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  final LectureNote note;
  final Subject? subject;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _NoteCard({
    required this.note,
    required this.subject,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subjectColor = subject != null
        ? Color(subject!.colorArgb)
        : theme.colorScheme.primary;

    final formattedDate =
        '${note.updatedAt.day.toString().padLeft(2, '0')}/${note.updatedAt.month.toString().padLeft(2, '0')}/${note.updatedAt.year}';

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
          width: 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Badges & Actions Row
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: subjectColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      subject?.name ?? note.subjectId,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: subjectColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (note.slotId != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.schedule,
                            size: 11,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            AppStrings.pinnedSlot,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const Spacer(),
                  // Ngày tạo / cập nhật hiển thị xám nhạt góc phải
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 12,
                        color: theme.colorScheme.outline,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        formattedDate,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18),
                    color: theme.colorScheme.outline,
                    visualDensity: VisualDensity.compact,
                    tooltip: AppStrings.delete,
                    onPressed: onDelete,
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Title in đậm vừa phải
              Text(
                note.title.isNotEmpty ? note.title : AppStrings.untitledNote,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),

              // Body Snippet: tối đa 2 dòng không bị tràn chữ
              if (note.bodyText.isNotEmpty)
                Text(
                  note.bodyText,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),

              // Ảnh thumbnail thu nhỏ chuẩn Google Keep
              if (note.imagePaths.isNotEmpty) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    height: 110,
                    width: double.infinity,
                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    child: kIsWeb
                        ? Center(
                            child: Icon(Icons.image, color: theme.colorScheme.outline),
                          )
                        : Image.file(
                            File(note.imagePaths.first),
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Center(
                              child: Icon(Icons.broken_image_outlined,
                                  color: theme.colorScheme.outline),
                            ),
                          ),
                  ),
                ),
              ],

              // Media & Location Badges
              if (note.videoPaths.isNotEmpty ||
                  (note.location != null && note.location!.isNotEmpty)) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    if (note.videoPaths.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.videocam_outlined,
                              size: 14,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              note.videoPaths.length > 1
                                  ? '${note.videoPaths.length} clips'
                                  : AppStrings.videoLecture,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (note.location != null && note.location!.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.place_outlined,
                              size: 13,
                              color: Colors.redAccent,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              note.location!,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

