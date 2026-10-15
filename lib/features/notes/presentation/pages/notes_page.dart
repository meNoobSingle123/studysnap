import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
<<<<<<< HEAD
import 'package:uuid/uuid.dart';

import '../../../../core/l10n/strings.dart';
import '../../../../core/router/routes.dart';

class NotesPage extends StatelessWidget {
  const NotesPage({super.key});

  @override
  Widget build(BuildContext context) {
=======
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/l10n/strings.dart';
import '../../../../core/router/routes.dart';
import '../../domain/entities/lecture_note.dart';
import '../../domain/repositories/note_repository.dart';

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
            : getIt<NoteRepository>());
    _loadNotes();
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
    await _loadNotes();
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

>>>>>>> 65bb05b538bafaaf5ee63db54ee8a586f3e3f474
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.notesTab),
      ),
<<<<<<< HEAD
      body: const Center(
        child: Text(AppStrings.emptyNotesList),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          final newNoteId = const Uuid().v4();
          context.push(Routes.noteEdit(newNoteId));
        },
        icon: const Icon(Icons.edit_note),
=======
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
>>>>>>> 65bb05b538bafaaf5ee63db54ee8a586f3e3f474
        label: const Text(AppStrings.createNote),
      ),
    );
  }
}
