import '../entities/lecture_note.dart';
import '../repositories/note_repository.dart';

/// UseCase to persist or update a lecture note.
class SaveNoteUseCase {
  final NoteRepository _repository;

  const SaveNoteUseCase(this._repository);

  Future<void> call(LectureNote note) {
    return _repository.saveNote(note);
  }
}
