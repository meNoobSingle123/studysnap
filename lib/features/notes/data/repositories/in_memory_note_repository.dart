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

  @override
  Future<List<LectureNote>> getAllNotes() async {
    final list = _storage.values.toList();
    list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }
}
