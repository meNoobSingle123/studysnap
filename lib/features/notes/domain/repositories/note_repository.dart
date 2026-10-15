import '../entities/lecture_note.dart';

/// Abstract contract for notes persistence and retrieval.
abstract class NoteRepository {
  /// Retrieves a lecture note by its ID.
  Future<LectureNote?> getNoteById(String id);

  /// Saves or updates a lecture note.
  Future<void> saveNote(LectureNote note);

  /// Retrieves all notes (excluding soft-deleted ones).
  Future<List<LectureNote>> getAllNotes();

  /// Reactive stream of all active notes for real-time UI updates.
  Stream<List<LectureNote>> watchAllNotes();

  /// Deletes a note by its ID (soft-delete).
  Future<void> deleteNote(String id);
}
