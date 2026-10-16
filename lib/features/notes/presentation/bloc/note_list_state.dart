import 'package:equatable/equatable.dart';

import '../../domain/entities/lecture_note.dart';
import '../../../timetable/domain/entities/subject.dart';

enum NoteListStatus { initial, loading, success, failure }

enum NoteSortOption {
  newestFirst,
  oldestFirst,
  titleAz,
}

class NoteListState extends Equatable {
  final NoteListStatus status;
  final List<LectureNote> allNotes;
  final List<LectureNote> filteredNotes;
  final Map<String, Subject> subjectsMap;
  final String searchQuery;
  final String? selectedSubjectId;
  final DateTime? selectedDate;
  final NoteSortOption sortOption;
  final String? errorMessage;

  const NoteListState({
    this.status = NoteListStatus.initial,
    this.allNotes = const [],
    this.filteredNotes = const [],
    this.subjectsMap = const {},
    this.searchQuery = '',
    this.selectedSubjectId,
    this.selectedDate,
    this.sortOption = NoteSortOption.newestFirst,
    this.errorMessage,
  });

  bool get hasActiveFilters =>
      searchQuery.trim().isNotEmpty ||
      selectedSubjectId != null ||
      selectedDate != null;

  NoteListState copyWith({
    NoteListStatus? status,
    List<LectureNote>? allNotes,
    List<LectureNote>? filteredNotes,
    Map<String, Subject>? subjectsMap,
    String? searchQuery,
    String? Function()? selectedSubjectId,
    DateTime? Function()? selectedDate,
    NoteSortOption? sortOption,
    String? errorMessage,
  }) {
    return NoteListState(
      status: status ?? this.status,
      allNotes: allNotes ?? this.allNotes,
      filteredNotes: filteredNotes ?? this.filteredNotes,
      subjectsMap: subjectsMap ?? this.subjectsMap,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedSubjectId: selectedSubjectId != null
          ? selectedSubjectId()
          : this.selectedSubjectId,
      selectedDate:
          selectedDate != null ? selectedDate() : this.selectedDate,
      sortOption: sortOption ?? this.sortOption,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        status,
        allNotes,
        filteredNotes,
        subjectsMap,
        searchQuery,
        selectedSubjectId,
        selectedDate,
        sortOption,
        errorMessage,
      ];
}
