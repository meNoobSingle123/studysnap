import '../../domain/entities/lecture_note.dart';
import '../../domain/repositories/note_repository.dart';

/// In-memory implementation of NoteRepository.
/// Stores notes temporarily in RAM without persisting to Hive.
class InMemoryNoteRepository implements NoteRepository {
  final Map<String, LectureNote> _storage = {};

  @override
  Future<LectureNote?> getNoteById(String id) async {
    return _storage[id];
  }

  @override
  Future<void> saveNote(LectureNote note) async {
    _storage[note.id] = note;
  }
<<<<<<< HEAD
=======

  @override
  Future<List<LectureNote>> getAllNotes() async {
    final list = _storage.values.toList();
    list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }
>>>>>>> 65bb05b538bafaaf5ee63db54ee8a586f3e3f474
}
