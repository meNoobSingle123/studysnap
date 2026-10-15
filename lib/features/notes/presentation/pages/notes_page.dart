import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/l10n/strings.dart';
import '../../../../core/router/routes.dart';
import '../../../timetable/domain/entities/subject.dart';
import '../../domain/entities/lecture_note.dart';
import '../bloc/note_list_bloc.dart';
import '../bloc/note_list_event.dart';
import '../bloc/note_list_state.dart';

class NotesPage extends StatelessWidget {
  const NotesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<NoteListBloc>()..add(const LoadNotesStarted()),
      child: const _NotesView(),
    );
  }
}

class _NotesView extends StatefulWidget {
  const _NotesView();

  @override
  State<_NotesView> createState() => _NotesViewState();
}

class _NotesViewState extends State<_NotesView> {
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
          // 1. Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: AppStrings.searchNotesHint,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
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
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(28),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (value) {
                context.read<NoteListBloc>().add(SearchQueryChanged(value));
                setState(() {});
              },
            ),
          ),

          // 2. Filter Bar
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

                    // Reset Filters chip (visible when active)
                    if (state.hasActiveFilters) ...[
                      const SizedBox(width: 8),
                      ActionChip(
                        avatar: const Icon(Icons.restart_alt, size: 16),
                        label: const Text(AppStrings.resetFilters),
                        onPressed: () {
                          _searchController.clear();
                          context
                              .read<NoteListBloc>()
                              .add(const ClearFiltersRequested());
                          setState(() {});
                        },
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 8),

          // 3. Notes List
          Expanded(
            child: BlocBuilder<NoteListBloc, NoteListState>(
              builder: (context, state) {
                if (state.status == NoteListStatus.loading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (state.status == NoteListStatus.failure) {
                  return Center(
                    child: Text(state.errorMessage ?? AppStrings.errorUnknown),
                  );
                }

                if (state.allNotes.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.note_alt_outlined,
                            size: 64,
                            color: theme.colorScheme.outline,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            AppStrings.emptyNotesList,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                if (state.filteredNotes.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.search_off_rounded,
                            size: 64,
                            color: theme.colorScheme.outline,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            AppStrings.noMatchingNotes,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 16),
                          FilledButton.tonal(
                            onPressed: () {
                              _searchController.clear();
                              context
                                  .read<NoteListBloc>()
                                  .add(const ClearFiltersRequested());
                              setState(() {});
                            },
                            child: const Text(AppStrings.resetFilters),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                  itemCount: state.filteredNotes.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final note = state.filteredNotes[index];
                    final subject = state.subjectsMap[note.subjectId];
                    return _NoteCard(
                      note: note,
                      subject: subject,
                      onTap: () => context.push(Routes.noteEdit(note.id)),
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
        onPressed: () {
          final newNoteId = const Uuid().v4();
          context.push(Routes.noteEdit(newNoteId));
        },
        icon: const Icon(Icons.edit_note),
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Badges Row
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: subjectColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
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
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.schedule,
                            size: 12,
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
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    color: theme.colorScheme.outline,
                    visualDensity: VisualDensity.compact,
                    tooltip: AppStrings.delete,
                    onPressed: onDelete,
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Title
              Text(
                note.title.isNotEmpty ? note.title : AppStrings.untitledNote,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),

              // Body Snippet
              if (note.bodyText.isNotEmpty)
                Text(
                  note.bodyText,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              const SizedBox(height: 12),

              // Footer: Date & Video status
              Row(
                children: [
                  Icon(
                    Icons.access_time,
                    size: 14,
                    color: theme.colorScheme.outline,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    formattedDate,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                  if (note.videoPath != null) ...[
                    const SizedBox(width: 12),
                    Icon(
                      Icons.videocam_outlined,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Video',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
