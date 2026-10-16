import '../entities/lecture_note.dart';
import '../repositories/note_repository.dart';

/// Pure domain use case to retrieve all active lecture notes.
class GetAllNotesUseCase {
  final NoteRepository repository;

  const GetAllNotesUseCase(this.repository);

  Future<List<LectureNote>> call() {
    return repository.getAllNotes();
  }
}
