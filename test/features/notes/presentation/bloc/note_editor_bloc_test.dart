import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nhom_7/features/notes/data/repositories/in_memory_note_repository.dart';
import 'package:nhom_7/features/notes/domain/entities/lecture_note.dart';
import 'package:nhom_7/features/notes/domain/usecases/get_note_by_id_usecase.dart';
import 'package:nhom_7/features/notes/domain/usecases/save_note_usecase.dart';
import 'package:nhom_7/features/notes/presentation/bloc/note_editor_bloc.dart';
import 'package:nhom_7/features/notes/presentation/bloc/note_editor_event.dart';
import 'package:nhom_7/features/notes/presentation/bloc/note_editor_state.dart';

void main() {
  late InMemoryNoteRepository repository;
  late GetNoteByIdUseCase getNoteByIdUseCase;
  late SaveNoteUseCase saveNoteUseCase;

  setUp(() {
    repository = InMemoryNoteRepository();
    getNoteByIdUseCase = GetNoteByIdUseCase(repository);
    saveNoteUseCase = SaveNoteUseCase(repository);
  });

  final existingNote = LectureNote(
    id: 'existing-id',
    subjectId: 'SUBJ-01',
    slotId: 'SLOT-01',
    title: 'Tiêu đề cũ',
    bodyText: 'Nội dung cũ',
    createdAt: DateTime(2026, 10, 13, 8, 0),
    updatedAt: DateTime(2026, 10, 13, 8, 0),
  );

  group('NoteEditorBloc', () {
    test('initial state is NoteEditorInitial', () {
      final bloc = NoteEditorBloc(
        getNoteByIdUseCase: getNoteByIdUseCase,
        saveNoteUseCase: saveNoteUseCase,
      );
      expect(bloc.state, equals(const NoteEditorInitial()));
      bloc.close();
    });

    blocTest<NoteEditorBloc, NoteEditorState>(
      'emits [NoteEditorLoading, NoteEditorLoaded] when loading new draft note',
      build: () => NoteEditorBloc(
        getNoteByIdUseCase: getNoteByIdUseCase,
        saveNoteUseCase: saveNoteUseCase,
      ),
      act: (bloc) => bloc.add(const LoadNote('new-id', subjectId: 'SUBJ-MATH', slotId: 'SLOT-A')),
      expect: () => [
        const NoteEditorLoading(),
        isA<NoteEditorLoaded>()
            .having((s) => s.note.id, 'note.id', 'new-id')
            .having((s) => s.note.subjectId, 'note.subjectId', 'SUBJ-MATH')
            .having((s) => s.note.slotId, 'note.slotId', 'SLOT-A')
            .having((s) => s.note.title, 'note.title', '')
            .having((s) => s.note.bodyText, 'note.bodyText', ''),
      ],
    );

    blocTest<NoteEditorBloc, NoteEditorState>(
      'emits [NoteEditorLoading, NoteEditorLoaded] when loading existing note',
      setUp: () async {
        await repository.saveNote(existingNote);
      },
      build: () => NoteEditorBloc(
        getNoteByIdUseCase: getNoteByIdUseCase,
        saveNoteUseCase: saveNoteUseCase,
      ),
      act: (bloc) => bloc.add(const LoadNote('existing-id')),
      expect: () => [
        const NoteEditorLoading(),
        NoteEditorLoaded(note: existingNote),
      ],
    );

    blocTest<NoteEditorBloc, NoteEditorState>(
      'emits NoteEditorLoaded with updated content and hasUnsavedChanges=true on UpdateContent',
      build: () => NoteEditorBloc(
        getNoteByIdUseCase: getNoteByIdUseCase,
        saveNoteUseCase: saveNoteUseCase,
        // Set a long autoSaveDuration to test just the UpdateContent emission before auto-save
        autoSaveDuration: const Duration(seconds: 10),
      ),
      seed: () => NoteEditorLoaded(note: existingNote),
      act: (bloc) => bloc.add(const UpdateContent(
        title: 'Tiêu đề mới',
        bodyText: 'Nội dung mới',
      )),
      expect: () => [
        isA<NoteEditorLoaded>()
            .having((s) => s.note.title, 'note.title', 'Tiêu đề mới')
            .having((s) => s.note.bodyText, 'note.bodyText', 'Nội dung mới')
            .having((s) => s.isSaveSuccess, 'isSaveSuccess', false)
            .having((s) => s.hasUnsavedChanges, 'hasUnsavedChanges', true),
      ],
    );

    blocTest<NoteEditorBloc, NoteEditorState>(
      'auto-saves after debounce duration on UpdateContent',
      build: () => NoteEditorBloc(
        getNoteByIdUseCase: getNoteByIdUseCase,
        saveNoteUseCase: saveNoteUseCase,
        autoSaveDuration: const Duration(milliseconds: 50),
      ),
      seed: () => NoteEditorLoaded(note: existingNote),
      act: (bloc) => bloc.add(const UpdateContent(title: 'Tự động lưu')),
      wait: const Duration(milliseconds: 100),
      expect: () => [
        isA<NoteEditorLoaded>()
            .having((s) => s.note.title, 'note.title', 'Tự động lưu')
            .having((s) => s.hasUnsavedChanges, 'hasUnsavedChanges', true),
        isA<NoteEditorLoaded>()
            .having((s) => s.isSaving, 'isSaving', true)
            .having((s) => s.hasUnsavedChanges, 'hasUnsavedChanges', true),
        isA<NoteEditorLoaded>()
            .having((s) => s.isSaving, 'isSaving', false)
            .having((s) => s.isSaveSuccess, 'isSaveSuccess', true)
            .having((s) => s.hasUnsavedChanges, 'hasUnsavedChanges', false),
      ],
      verify: (_) async {
        final saved = await repository.getNoteById('existing-id');
        expect(saved?.title, equals('Tự động lưu'));
      },
    );

    blocTest<NoteEditorBloc, NoteEditorState>(
      'cancels debounce and performs immediate save on SaveNote',
      build: () => NoteEditorBloc(
        getNoteByIdUseCase: getNoteByIdUseCase,
        saveNoteUseCase: saveNoteUseCase,
        autoSaveDuration: const Duration(seconds: 5),
      ),
      seed: () => NoteEditorLoaded(note: existingNote, hasUnsavedChanges: true),
      act: (bloc) => bloc.add(const SaveNote()),
      expect: () => [
        isA<NoteEditorLoaded>()
            .having((s) => s.isSaving, 'isSaving', true)
            .having((s) => s.isSaveSuccess, 'isSaveSuccess', false),
        isA<NoteEditorLoaded>()
            .having((s) => s.isSaving, 'isSaving', false)
            .having((s) => s.isSaveSuccess, 'isSaveSuccess', true)
            .having((s) => s.hasUnsavedChanges, 'hasUnsavedChanges', false),
      ],
      verify: (_) async {
        final saved = await repository.getNoteById('existing-id');
        expect(saved, isNotNull);
        expect(saved!.title, equals('Tiêu đề cũ'));
      },
    );
  });
}
