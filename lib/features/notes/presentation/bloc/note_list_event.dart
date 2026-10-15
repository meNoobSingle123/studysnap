import 'package:equatable/equatable.dart';

import '../../domain/entities/lecture_note.dart';
import 'note_list_state.dart';

sealed class NoteListEvent extends Equatable {
  const NoteListEvent();

  @override
  List<Object?> get props => [];
}

class LoadNotesStarted extends NoteListEvent {
  const LoadNotesStarted();
}

class NotesStreamUpdated extends NoteListEvent {
  final List<LectureNote> notes;

  const NotesStreamUpdated(this.notes);

  @override
  List<Object?> get props => [notes];
}

class SearchQueryChanged extends NoteListEvent {
  final String query;

  const SearchQueryChanged(this.query);

  @override
  List<Object?> get props => [query];
}

class FilterSubjectChanged extends NoteListEvent {
  final String? subjectId;

  const FilterSubjectChanged(this.subjectId);

  @override
  List<Object?> get props => [subjectId];
}

class FilterDateChanged extends NoteListEvent {
  final DateTime? date;

  const FilterDateChanged(this.date);

  @override
  List<Object?> get props => [date];
}

class SortOptionChanged extends NoteListEvent {
  final NoteSortOption sortOption;

  const SortOptionChanged(this.sortOption);

  @override
  List<Object?> get props => [sortOption];
}

class DeleteNoteRequested extends NoteListEvent {
  final String noteId;

  const DeleteNoteRequested(this.noteId);

  @override
  List<Object?> get props => [noteId];
}

class ClearFiltersRequested extends NoteListEvent {
  const ClearFiltersRequested();
}
