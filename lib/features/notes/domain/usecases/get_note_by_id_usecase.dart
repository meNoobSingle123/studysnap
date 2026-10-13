import '../entities/lecture_note.dart';
import '../repositories/note_repository.dart';

/// UseCase to retrieve a lecture note by its ID.
class GetNoteByIdUseCase {
  final NoteRepository _repository;

  const GetNoteByIdUseCase(this._repository);

  Future<LectureNote?> call(String id) {
    return _repository.getNoteById(id);
  }
}
