import '../repositories/note_repository.dart';

/// Pure domain use case to delete (soft-delete) a lecture note by its ID.
class DeleteNoteUseCase {
  final NoteRepository repository;

  const DeleteNoteUseCase(this.repository);

  Future<void> call(String id) {
    return repository.deleteNote(id);
  }
}
