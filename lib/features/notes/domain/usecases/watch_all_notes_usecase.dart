import '../entities/lecture_note.dart';
import '../repositories/note_repository.dart';

/// Pure domain use case to watch real-time updates for all lecture notes.
class WatchAllNotesUseCase {
  final NoteRepository repository;

  const WatchAllNotesUseCase(this.repository);

  Stream<List<LectureNote>> call() {
    return repository.watchAllNotes();
  }
}
