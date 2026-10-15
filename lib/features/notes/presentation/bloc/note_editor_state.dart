import 'package:equatable/equatable.dart';

import '../../domain/entities/lecture_note.dart';

sealed class NoteEditorState extends Equatable {
  const NoteEditorState();

  @override
  List<Object?> get props => [];
}

/// Initial state before any action is triggered.
class NoteEditorInitial extends NoteEditorState {
  const NoteEditorInitial();
}

/// State when note content is being fetched.
class NoteEditorLoading extends NoteEditorState {
  const NoteEditorLoading();
}

/// State when note is loaded and ready for editing.
class NoteEditorLoaded extends NoteEditorState {
  final LectureNote note;
  final bool isSaving;
  final bool isSaveSuccess;
  final bool hasUnsavedChanges;

  const NoteEditorLoaded({
    required this.note,
    this.isSaving = false,
    this.isSaveSuccess = false,
    this.hasUnsavedChanges = false,
  });

  NoteEditorLoaded copyWith({
    LectureNote? note,
    bool? isSaving,
    bool? isSaveSuccess,
    bool? hasUnsavedChanges,
  }) {
    return NoteEditorLoaded(
      note: note ?? this.note,
      isSaving: isSaving ?? this.isSaving,
      isSaveSuccess: isSaveSuccess ?? this.isSaveSuccess,
      hasUnsavedChanges: hasUnsavedChanges ?? this.hasUnsavedChanges,
    );
  }

  @override
  List<Object?> get props => [note, isSaving, isSaveSuccess, hasUnsavedChanges];
}

/// State when an error occurs during loading or saving.
class NoteEditorFailure extends NoteEditorState {
  final String message;

  const NoteEditorFailure(this.message);

  @override
  List<Object?> get props => [message];
}
