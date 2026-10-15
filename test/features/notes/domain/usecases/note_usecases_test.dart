import 'package:flutter_test/flutter_test.dart';
import 'package:nhom_7/features/notes/data/repositories/in_memory_note_repository.dart';
import 'package:nhom_7/features/notes/domain/entities/lecture_note.dart';
import 'package:nhom_7/features/notes/domain/usecases/get_note_by_id_usecase.dart';
import 'package:nhom_7/features/notes/domain/usecases/save_note_usecase.dart';

void main() {
  late InMemoryNoteRepository repository;
  late GetNoteByIdUseCase getNoteByIdUseCase;
  late SaveNoteUseCase saveNoteUseCase;

  setUp(() {
    repository = InMemoryNoteRepository();
    getNoteByIdUseCase = GetNoteByIdUseCase(repository);
    saveNoteUseCase = SaveNoteUseCase(repository);
  });

  final testNote = LectureNote(
    id: 'note-1',
    subjectId: 'SUBJ-01',
    slotId: 'SLOT-01',
    title: 'Giải tích 1',
    bodyText: 'Nội dung đạo hàm và tích phân',
    createdAt: DateTime(2026, 10, 13, 8, 0),
    updatedAt: DateTime(2026, 10, 13, 8, 0),
  );

  group('GetNoteByIdUseCase', () {
    test('returns null when note does not exist', () async {
      final result = await getNoteByIdUseCase('non-existent');
      expect(result, isNull);
    });

    test('returns lecture note when note exists', () async {
      await repository.saveNote(testNote);

      final result = await getNoteByIdUseCase('note-1');
      expect(result, equals(testNote));
    });
  });

  group('SaveNoteUseCase', () {
    test('persists note in repository successfully', () async {
      await saveNoteUseCase(testNote);

      final retrieved = await repository.getNoteById('note-1');
      expect(retrieved, equals(testNote));
    });
  });
}
