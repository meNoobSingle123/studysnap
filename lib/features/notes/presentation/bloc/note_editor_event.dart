import 'package:equatable/equatable.dart';

sealed class NoteEditorEvent extends Equatable {
  const NoteEditorEvent();

  @override
  List<Object?> get props => [];
}

/// Load an existing note or initialize a new note with a specific ID.
class LoadNote extends NoteEditorEvent {
  final String id;
  final String? subjectId;
  final String? slotId;

  const LoadNote(this.id, {this.subjectId, this.slotId});

  @override
  List<Object?> get props => [id, subjectId, slotId];
}

/// Updates title or body text in the current note draft.
class UpdateContent extends NoteEditorEvent {
  final String? title;
  final String? bodyText;

  const UpdateContent({this.title, this.bodyText});

  @override
  List<Object?> get props => [title, bodyText];
}

/// Triggers note persistence.
class SaveNote extends NoteEditorEvent {
  const SaveNote();
}

/// Attaches or detaches a lecture video file path to the note draft.
class AttachVideo extends NoteEditorEvent {
  final String? videoPath;

  const AttachVideo(this.videoPath);

  @override
  List<Object?> get props => [videoPath];
}

