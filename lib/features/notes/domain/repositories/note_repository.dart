import '../entities/lecture_note.dart';

/// Abstract contract for notes persistence and retrieval.
abstract class NoteRepository {
  /// Retrieves a lecture note by its ID.
  Future<LectureNote?> getNoteById(String id);

  /// Saves or updates a lecture note.
  Future<void> saveNote(LectureNote note);
<<<<<<< HEAD
=======

  /// Retrieves all saved lecture notes.
  Future<List<LectureNote>> getAllNotes();
>>>>>>> 65bb05b538bafaaf5ee63db54ee8a586f3e3f474
}
