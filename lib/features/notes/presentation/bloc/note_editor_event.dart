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

/// Adds a video to the note's videoPaths list.
class AddVideo extends NoteEditorEvent {
  final String videoPath;
  const AddVideo(this.videoPath);

  @override
  List<Object?> get props => [videoPath];
}

/// Removes a video from the note's videoPaths list.
class RemoveVideo extends NoteEditorEvent {
  final String videoPath;
  const RemoveVideo(this.videoPath);

  @override
  List<Object?> get props => [videoPath];
}

/// Updates the study location.
class UpdateLocation extends NoteEditorEvent {
  final String? location;
  const UpdateLocation(this.location);

  @override
  List<Object?> get props => [location];
}

/// Adds an image to the note's imagePaths list.
class AddImage extends NoteEditorEvent {
  final String imagePath;
  const AddImage(this.imagePath);

  @override
  List<Object?> get props => [imagePath];
}

/// Removes an image from the note's imagePaths list.
class RemoveImage extends NoteEditorEvent {
  final String imagePath;
  const RemoveImage(this.imagePath);

  @override
  List<Object?> get props => [imagePath];
}

