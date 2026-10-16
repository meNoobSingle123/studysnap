import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:nhom_7/core/l10n/strings.dart';
import 'package:nhom_7/features/notes/data/repositories/in_memory_note_repository.dart';
import 'package:nhom_7/features/notes/domain/entities/lecture_note.dart';
import 'package:nhom_7/features/notes/domain/repositories/note_repository.dart';
import 'package:nhom_7/features/notes/domain/usecases/delete_note_usecase.dart';
import 'package:nhom_7/features/notes/domain/usecases/watch_all_notes_usecase.dart';
import 'package:nhom_7/features/notes/presentation/bloc/note_list_bloc.dart';
import 'package:nhom_7/features/notes/presentation/pages/notes_page.dart';
import 'package:nhom_7/features/timetable/domain/entities/campus_building.dart';
import 'package:nhom_7/features/timetable/domain/entities/exam_schedule.dart';
import 'package:nhom_7/features/timetable/domain/entities/subject.dart';
import 'package:nhom_7/features/timetable/domain/entities/timetable_slot.dart';
import 'package:nhom_7/features/timetable/domain/repositories/timetable_repository.dart';
import 'package:nhom_7/features/timetable/domain/usecases/get_subjects_usecase.dart';

class _MockTimetableRepo implements TimetableRepository {
  final List<Subject> subjects;

  _MockTimetableRepo(this.subjects);

  @override
  Future<List<Subject>> getSubjects() async => subjects;

  @override
  Stream<List<Subject>> watchSubjects() async* {
    yield subjects;
  }

  @override
  Future<Subject?> getSubjectById(String id) async =>
      subjects.where((s) => s.id == id).firstOrNull;

  @override
  Future<List<TimetableSlot>> getSlots() async => [];

  @override
  Stream<List<TimetableSlot>> watchSlots() async* {
    yield [];
  }

  @override
  Stream<List<TimetableSlot>> watchAllSlots() async* {
    yield [];
  }

  @override
  Stream<List<TimetableSlot>> watchSlotsByDay(int dayOfWeek) async* {
    yield [];
  }

  @override
  Future<TimetableSlot?> getSlotById(String id) async => null;

  @override
  Future<void> saveSubject(Subject subject) async {}

  @override
  Future<void> softDeleteSubject(String id) async {}

  @override
  Future<void> saveSlot(TimetableSlot slot) async {}

  @override
  Future<void> saveSlots(List<TimetableSlot> slots) async {}

  @override
  Future<void> deleteSlot(String id) async {}

  @override
  Future<List<ExamSchedule>> getExams() async => [];

  @override
  Stream<List<ExamSchedule>> watchExams() async* {
    yield [];
  }

  @override
  Future<void> saveExams(List<ExamSchedule> exams) async {}

  @override
  Future<List<CampusBuilding>> getCampusBuildings() async => [];

  @override
  Future<List<CampusBuilding>> getBuildings() async => [];

  @override
  Future<void> saveBuildings(List<CampusBuilding> buildings) async {}
}

void main() {
  group('Team NotesPage Tests (Custom Repository)', () {
    late InMemoryNoteRepository repository;

    setUp(() {
      repository = InMemoryNoteRepository();
      final getIt = GetIt.instance;
      if (!getIt.isRegistered<NoteRepository>()) {
        getIt.registerSingleton<NoteRepository>(repository);
      }
    });

    tearDown(() {
      GetIt.instance.reset();
    });

    Widget buildTestableWidget({InMemoryNoteRepository? customRepo}) {
      return MaterialApp(
        home: NotesPage(repository: customRepo ?? repository),
      );
    }

    testWidgets('renders empty state when there are no notes', (tester) async {
      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.notesTab), findsOneWidget);
      expect(find.text(AppStrings.emptyNotesList), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsOneWidget);
    });

    testWidgets('renders note cards with title, snippet, and timestamp',
        (tester) async {
      final now = DateTime(2026, 10, 15, 14, 30);
      final note1 = LectureNote(
        id: 'note-1',
        subjectId: 'CS101',
        title: 'Nhập môn Lập trình',
        bodyText: 'Hôm nay học cấu trúc rẽ nhánh if else',
        createdAt: now,
        updatedAt: now,
      );
      final note2 = LectureNote(
        id: 'note-2',
        subjectId: 'MATH101',
        title: 'Giải tích 1',
        bodyText: 'Đạo hàm và tích phân cơ bản',
        videoPath: 'math_video.mp4',
        createdAt: now,
        updatedAt: now,
      );
      await repository.saveNote(note1);
      await repository.saveNote(note2);

      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      // Verify note cards
      expect(find.text('Nhập môn Lập trình'), findsOneWidget);
      expect(find.text('Hôm nay học cấu trúc rẽ nhánh if else'), findsOneWidget);
      expect(find.text('CS101'), findsOneWidget);

      expect(find.text('Giải tích 1'), findsOneWidget);
      expect(find.text('Đạo hàm và tích phân cơ bản'), findsOneWidget);
      expect(find.text('MATH101'), findsOneWidget);
      expect(find.byIcon(Icons.videocam_outlined), findsOneWidget);

      expect(find.text(AppStrings.emptyNotesList), findsNothing);
  });

  group('Huy NotesPage Tests (S05 Reactive Stream & Multi-Criteria Filtering)', () {
    late InMemoryNoteRepository noteRepository;
    final getIt = GetIt.instance;

    final testSubject = Subject(
      id: 'sub_flutter',
      code: 'IT3100',
      name: 'Lập trình thiết bị di động',
      credits: 3,
      colorArgb: 0xFF2196F3,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    setUp(() {
      noteRepository = InMemoryNoteRepository(seedMockData: false);
      final timetableRepo = _MockTimetableRepo([testSubject]);
      final getSubjectsUseCase = GetSubjectsUseCase(timetableRepo);
      final watchAllNotesUseCase = WatchAllNotesUseCase(noteRepository);
      final deleteNoteUseCase = DeleteNoteUseCase(noteRepository);

      if (!getIt.isRegistered<NoteListBloc>()) {
        getIt.registerFactory<NoteListBloc>(
          () => NoteListBloc(
            watchAllNotesUseCase: watchAllNotesUseCase,
            deleteNoteUseCase: deleteNoteUseCase,
            getSubjectsUseCase: getSubjectsUseCase,
          ),
        );
      }
    });

    tearDown(() {
      getIt.reset();
    });

    Widget buildTestHarness() {
      return const MaterialApp(
        home: NotesPage(),
      );
    }

    testWidgets('renders NotesPage with search bar, filter bar and FAB', (tester) async {
      await tester.pumpWidget(buildTestHarness());
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.notesTab), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.text(AppStrings.allSubjects), findsOneWidget);
      expect(find.text('Lập trình thiết bị di động'), findsOneWidget);
    });

    testWidgets('shows empty state when no notes exist', (tester) async {
      await tester.pumpWidget(buildTestHarness());
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.emptyNotesList), findsOneWidget);
    });

    testWidgets('renders note card with title, snippet, and subject badge', (tester) async {
      final note = LectureNote(
        id: 'note-01',
        subjectId: 'sub_flutter',
        title: 'Học Widget Tree',
        bodyText: 'StatelessWidget và StatefulWidget trong Flutter.',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await noteRepository.saveNote(note);

      await tester.pumpWidget(buildTestHarness());
      await tester.pumpAndSettle();

      expect(find.text('Học Widget Tree'), findsOneWidget);
      expect(find.text('StatelessWidget và StatefulWidget trong Flutter.'), findsOneWidget);
      expect(find.text('Lập trình thiết bị di động'), findsWidgets);
    });

    testWidgets('typing in search bar filters note list in real-time', (tester) async {
      final note1 = LectureNote(
        id: 'n1',
        subjectId: 'sub_flutter',
        title: 'Clean Architecture',
        bodyText: 'Presentation and Domain',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      final note2 = LectureNote(
        id: 'n2',
        subjectId: 'sub_flutter',
        title: 'Database SQLite',
        bodyText: 'Local storage',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await noteRepository.saveNote(note1);
      await noteRepository.saveNote(note2);

      await tester.pumpWidget(buildTestHarness());
      await tester.pumpAndSettle();

      expect(find.text('Clean Architecture'), findsOneWidget);
      expect(find.text('Database SQLite'), findsOneWidget);

      // Enter search text "clean"
      await tester.enterText(find.byType(TextField), 'clean');
      await tester.pumpAndSettle();

      expect(find.text('Clean Architecture'), findsOneWidget);
      expect(find.text('Database SQLite'), findsNothing);
    });

    testWidgets('tapping delete icon shows confirmation dialog', (tester) async {
      final note = LectureNote(
        id: 'n1',
        subjectId: 'sub_flutter',
        title: 'Note to Delete',
        bodyText: 'Some text',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await noteRepository.saveNote(note);

      await tester.pumpWidget(buildTestHarness());
      await tester.pumpAndSettle();

      // Find and tap delete button
      final deleteBtn = find.byIcon(Icons.delete_outline);
      expect(deleteBtn, findsOneWidget);
      await tester.tap(deleteBtn);
      await tester.pumpAndSettle();

      // Confirmation dialog should be displayed
      expect(find.text(AppStrings.deleteNoteConfirmTitle), findsOneWidget);
      expect(find.text(AppStrings.deleteNoteConfirmMessage), findsOneWidget);

      // Confirm deletion
      await tester.tap(find.text(AppStrings.delete));
      await tester.pumpAndSettle();

      // Note should now be deleted, showing empty state
      expect(find.text('Note to Delete'), findsNothing);
      expect(find.text(AppStrings.emptyNotesList), findsOneWidget);
    });
  });
}
