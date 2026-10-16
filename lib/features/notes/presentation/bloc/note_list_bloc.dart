import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/lecture_note.dart';
import '../../domain/usecases/delete_note_usecase.dart';
import '../../domain/usecases/watch_all_notes_usecase.dart';
import '../../../timetable/domain/usecases/get_subjects_usecase.dart';
import 'note_list_event.dart';
import 'note_list_state.dart';

class NoteListBloc extends Bloc<NoteListEvent, NoteListState> {
  final WatchAllNotesUseCase watchAllNotesUseCase;
  final DeleteNoteUseCase deleteNoteUseCase;
  final GetSubjectsUseCase getSubjectsUseCase;

  StreamSubscription<List<LectureNote>>? _notesSubscription;

  NoteListBloc({
    required this.watchAllNotesUseCase,
    required this.deleteNoteUseCase,
    required this.getSubjectsUseCase,
  }) : super(const NoteListState()) {
    on<LoadNotesStarted>(_onLoadNotesStarted);
    on<NotesStreamUpdated>(_onNotesStreamUpdated);
    on<SearchQueryChanged>(_onSearchQueryChanged);
    on<FilterSubjectChanged>(_onFilterSubjectChanged);
    on<FilterDateChanged>(_onFilterDateChanged);
    on<SortOptionChanged>(_onSortOptionChanged);
    on<DeleteNoteRequested>(_onDeleteNoteRequested);
    on<ClearFiltersRequested>(_onClearFiltersRequested);
  }

  Future<void> _onLoadNotesStarted(
    LoadNotesStarted event,
    Emitter<NoteListState> emit,
  ) async {
    emit(state.copyWith(status: NoteListStatus.loading));
    try {
      final subjects = await getSubjectsUseCase.getSubjects();
      final subjectsMap = {for (final s in subjects) s.id: s};
      emit(state.copyWith(subjectsMap: subjectsMap));

      await _notesSubscription?.cancel();
      _notesSubscription = watchAllNotesUseCase().listen(
        (notes) {
          if (!isClosed) {
            add(NotesStreamUpdated(notes));
          }
        },
        onError: (e) {
          if (!isClosed) {
            emit(state.copyWith(
              status: NoteListStatus.failure,
              errorMessage: e.toString(),
            ));
          }
        },
      );
    } catch (e) {
      if (!emit.isDone) {
        emit(state.copyWith(
          status: NoteListStatus.failure,
          errorMessage: e.toString(),
        ));
      }
    }
  }

  void _onNotesStreamUpdated(
    NotesStreamUpdated event,
    Emitter<NoteListState> emit,
  ) {
    final filtered = filterAndSortNotes(
      notes: event.notes,
      query: state.searchQuery,
      selectedSubjectId: state.selectedSubjectId,
      selectedDate: state.selectedDate,
      sortOption: state.sortOption,
    );
    emit(state.copyWith(
      status: NoteListStatus.success,
      allNotes: event.notes,
      filteredNotes: filtered,
    ));
  }

  void _onSearchQueryChanged(
    SearchQueryChanged event,
    Emitter<NoteListState> emit,
  ) {
    final filtered = filterAndSortNotes(
      notes: state.allNotes,
      query: event.query,
      selectedSubjectId: state.selectedSubjectId,
      selectedDate: state.selectedDate,
      sortOption: state.sortOption,
    );
    emit(state.copyWith(
      searchQuery: event.query,
      filteredNotes: filtered,
    ));
  }

  void _onFilterSubjectChanged(
    FilterSubjectChanged event,
    Emitter<NoteListState> emit,
  ) {
    // Toggle subject if already selected
    final newSubjectId =
        state.selectedSubjectId == event.subjectId ? null : event.subjectId;

    final filtered = filterAndSortNotes(
      notes: state.allNotes,
      query: state.searchQuery,
      selectedSubjectId: newSubjectId,
      selectedDate: state.selectedDate,
      sortOption: state.sortOption,
    );
    emit(state.copyWith(
      selectedSubjectId: () => newSubjectId,
      filteredNotes: filtered,
    ));
  }

  void _onFilterDateChanged(
    FilterDateChanged event,
    Emitter<NoteListState> emit,
  ) {
    final filtered = filterAndSortNotes(
      notes: state.allNotes,
      query: state.searchQuery,
      selectedSubjectId: state.selectedSubjectId,
      selectedDate: event.date,
      sortOption: state.sortOption,
    );
    emit(state.copyWith(
      selectedDate: () => event.date,
      filteredNotes: filtered,
    ));
  }

  void _onSortOptionChanged(
    SortOptionChanged event,
    Emitter<NoteListState> emit,
  ) {
    final filtered = filterAndSortNotes(
      notes: state.allNotes,
      query: state.searchQuery,
      selectedSubjectId: state.selectedSubjectId,
      selectedDate: state.selectedDate,
      sortOption: event.sortOption,
    );
    emit(state.copyWith(
      sortOption: event.sortOption,
      filteredNotes: filtered,
    ));
  }

  Future<void> _onDeleteNoteRequested(
    DeleteNoteRequested event,
    Emitter<NoteListState> emit,
  ) async {
    try {
      await deleteNoteUseCase(event.noteId);
    } catch (e) {
      emit(state.copyWith(errorMessage: e.toString()));
    }
  }

  void _onClearFiltersRequested(
    ClearFiltersRequested event,
    Emitter<NoteListState> emit,
  ) {
    final filtered = filterAndSortNotes(
      notes: state.allNotes,
      query: '',
      selectedSubjectId: null,
      selectedDate: null,
      sortOption: state.sortOption,
    );
    emit(state.copyWith(
      searchQuery: '',
      selectedSubjectId: () => null,
      selectedDate: () => null,
      filteredNotes: filtered,
    ));
  }

  /// Pure filtering and sorting function for in-memory note management.
  static List<LectureNote> filterAndSortNotes({
    required List<LectureNote> notes,
    required String query,
    required String? selectedSubjectId,
    required DateTime? selectedDate,
    required NoteSortOption sortOption,
  }) {
    final cleanQuery = query.trim().toLowerCase();

    final result = notes.where((note) {
      // 1. Filter by subject
      if (selectedSubjectId != null && note.subjectId != selectedSubjectId) {
        return false;
      }

      // 2. Filter by date (compare year-month-day with note.createdAt)
      if (selectedDate != null) {
        final d = note.createdAt;
        final matchesDate = d.year == selectedDate.year &&
            d.month == selectedDate.month &&
            d.day == selectedDate.day;
        if (!matchesDate) {
          return false;
        }
      }

      // 3. Filter by search query (case-insensitive in title or bodyText)
      if (cleanQuery.isNotEmpty) {
        final titleMatch = note.title.toLowerCase().contains(cleanQuery);
        final bodyMatch = note.bodyText.toLowerCase().contains(cleanQuery);
        if (!titleMatch && !bodyMatch) {
          return false;
        }
      }

      return true;
    }).toList();

    // 4. Sort
    switch (sortOption) {
      case NoteSortOption.newestFirst:
        result.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        break;
      case NoteSortOption.oldestFirst:
        result.sort((a, b) => a.updatedAt.compareTo(b.updatedAt));
        break;
      case NoteSortOption.titleAz:
        result.sort((a, b) {
          final tA = a.title.trim().toLowerCase();
          final tB = b.title.trim().toLowerCase();
          return tA.compareTo(tB);
        });
        break;
    }

    return result;
  }

  @override
  Future<void> close() {
    _notesSubscription?.cancel();
    return super.close();
  }
}
