import 'package:flutter_test/flutter_test.dart';
import 'package:nhom_7/features/notes/data/repositories/in_memory_note_repository.dart';
import 'package:nhom_7/features/notes/domain/entities/lecture_note.dart';
import 'package:nhom_7/features/notes/domain/usecases/delete_note_usecase.dart';
import 'package:nhom_7/features/notes/domain/usecases/watch_all_notes_usecase.dart';
import 'package:nhom_7/features/notes/presentation/bloc/note_list_bloc.dart';
import 'package:nhom_7/features/notes/presentation/bloc/note_list_event.dart';
import 'package:nhom_7/features/notes/presentation/bloc/note_list_state.dart';
import 'package:nhom_7/features/timetable/domain/entities/campus_building.dart';
import 'package:nhom_7/features/timetable/domain/entities/exam_schedule.dart';
import 'package:nhom_7/features/timetable/domain/entities/subject.dart';
import 'package:nhom_7/features/timetable/domain/entities/timetable_slot.dart';
import 'package:nhom_7/features/timetable/domain/repositories/timetable_repository.dart';
import 'package:nhom_7/features/timetable/domain/usecases/get_subjects_usecase.dart';

class _FakeTimetableRepository implements TimetableRepository {
  final List<Subject> subjects;

  _FakeTimetableRepository(this.subjects);

  @override
  Future<List<Subject>> getSubjects() async => subjects;

  @override
  Stream<List<Subject>> watchSubjects() async* {
    yield subjects;
  }

  @override
  Future<Subject?> getSubjectById(String id) async {
    return subjects.where((s) => s.id == id).firstOrNull;
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
  Future<void> saveSlots(List<TimetableSlot> slots) async {}

  @override
  Future<void> deleteSlot(String id) async {}

  @override
  Future<List<ExamSchedule>> getExams() async => [];

  @override
  Future<void> saveExams(List<ExamSchedule> exams) async {}

  @override
  Future<List<CampusBuilding>> getBuildings() async => [];

  @override
  Future<void> saveBuildings(List<CampusBuilding> buildings) async {}
}


void main() {
  late InMemoryNoteRepository noteRepository;
  late WatchAllNotesUseCase watchAllNotesUseCase;
  late DeleteNoteUseCase deleteNoteUseCase;
  late GetSubjectsUseCase getSubjectsUseCase;
  late NoteListBloc bloc;

  final subject1 = Subject(
    id: 'sub_flutter',
    code: 'IT3100',
    name: 'Lập trình thiết bị di động',
    credits: 3,
    colorArgb: 0xFF2196F3,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  final subject2 = Subject(
    id: 'sub_db',
    code: 'IT3020',
    name: 'Cơ sở dữ liệu',
    credits: 3,
    colorArgb: 0xFF4CAF50,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  final date1 = DateTime(2026, 10, 10, 8, 0);
  final date2 = DateTime(2026, 10, 12, 14, 0);
  final date3 = DateTime(2026, 10, 14, 9, 30);

  final note1 = LectureNote(
    id: 'note_1',
    subjectId: 'sub_flutter',
    title: 'Học Clean Architecture',
    bodyText: 'Presentation, Domain, Data separation.',
    createdAt: date1,
    updatedAt: date1,
  );

  final note2 = LectureNote(
    id: 'note_2',
    subjectId: 'sub_db',
    title: 'Indexing B-Tree',
    bodyText: 'Chỉ mục tăng tốc tìm kiếm cơ sở dữ liệu.',
    createdAt: date2,
    updatedAt: date2,
  );

  final note3 = LectureNote(
    id: 'note_3',
    subjectId: 'sub_flutter',
    title: 'BLoC State Management',
    bodyText: 'Quản lý state bất đồng bộ trong Flutter.',
    createdAt: date3,
    updatedAt: date3,
  );

  setUp(() {
    noteRepository = InMemoryNoteRepository(seedMockData: false);
    watchAllNotesUseCase = WatchAllNotesUseCase(noteRepository);
    deleteNoteUseCase = DeleteNoteUseCase(noteRepository);
    final timetableRepo = _FakeTimetableRepository([subject1, subject2]);
    getSubjectsUseCase = GetSubjectsUseCase(timetableRepo);

    bloc = NoteListBloc(
      watchAllNotesUseCase: watchAllNotesUseCase,
      deleteNoteUseCase: deleteNoteUseCase,
      getSubjectsUseCase: getSubjectsUseCase,
    );
  });

  tearDown(() {
    bloc.close();
  });

  test('initial state has default status and empty collections', () {
    expect(bloc.state.status, equals(NoteListStatus.initial));
    expect(bloc.state.allNotes, isEmpty);
    expect(bloc.state.filteredNotes, isEmpty);
    expect(bloc.state.searchQuery, isEmpty);
    expect(bloc.state.selectedSubjectId, isNull);
    expect(bloc.state.selectedDate, isNull);
    expect(bloc.state.sortOption, equals(NoteSortOption.newestFirst));
  });

  test('LoadNotesStarted loads subjects and streams saved notes', () async {
    await noteRepository.saveNote(note1);
    await noteRepository.saveNote(note2);

    bloc.add(const LoadNotesStarted());

    await expectLater(
      bloc.stream,
      emitsThrough(
        predicate<NoteListState>((state) {
          return state.status == NoteListStatus.success &&
              state.allNotes.length == 2 &&
              state.subjectsMap.containsKey('sub_flutter') &&
              state.subjectsMap.containsKey('sub_db');
        }),
      ),
    );
  });

  group('In-Memory Filtering and Searching', () {
    setUp(() async {
      await noteRepository.saveNote(note1);
      await noteRepository.saveNote(note2);
      await noteRepository.saveNote(note3);
      bloc.add(const LoadNotesStarted());
      await bloc.stream.firstWhere((s) => s.status == NoteListStatus.success);
    });

    test('SearchQueryChanged filters notes by title (case-insensitive)', () async {
      bloc.add(const SearchQueryChanged('clean'));

      await expectLater(
        bloc.stream,
        emitsThrough(
          predicate<NoteListState>((state) {
            return state.searchQuery == 'clean' &&
                state.filteredNotes.length == 1 &&
                state.filteredNotes.first.id == 'note_1';
          }),
        ),
      );
    });

    test('SearchQueryChanged filters notes by bodyText', () async {
      bloc.add(const SearchQueryChanged('tăng tốc'));

      await expectLater(
        bloc.stream,
        emitsThrough(
          predicate<NoteListState>((state) {
            return state.filteredNotes.length == 1 &&
                state.filteredNotes.first.id == 'note_2';
          }),
        ),
      );
    });

    test('FilterSubjectChanged filters notes by subjectId and toggles off', () async {
      // Select sub_db
      bloc.add(const FilterSubjectChanged('sub_db'));
      await expectLater(
        bloc.stream,
        emitsThrough(
          predicate<NoteListState>((state) {
            return state.selectedSubjectId == 'sub_db' &&
                state.filteredNotes.length == 1 &&
                state.filteredNotes.first.id == 'note_2';
          }),
        ),
      );

      // Select sub_db again -> should toggle off (null) and show all 3
      bloc.add(const FilterSubjectChanged('sub_db'));
      await expectLater(
        bloc.stream,
        emitsThrough(
          predicate<NoteListState>((state) {
            return state.selectedSubjectId == null &&
                state.filteredNotes.length == 3;
          }),
        ),
      );
    });

    test('FilterDateChanged filters notes by creation day', () async {
      bloc.add(FilterDateChanged(DateTime(2026, 10, 12)));

      await expectLater(
        bloc.stream,
        emitsThrough(
          predicate<NoteListState>((state) {
            return state.filteredNotes.length == 1 &&
                state.filteredNotes.first.id == 'note_2';
          }),
        ),
      );
    });

    test('SortOptionChanged sorts notes alphabetically A-Z', () async {
      bloc.add(const SortOptionChanged(NoteSortOption.titleAz));

      await expectLater(
        bloc.stream,
        emitsThrough(
          predicate<NoteListState>((state) {
            return state.sortOption == NoteSortOption.titleAz &&
                state.filteredNotes.length == 3 &&
                state.filteredNotes[0].id == 'note_3' && // BLoC State Management
                state.filteredNotes[1].id == 'note_1' && // Học Clean Architecture
                state.filteredNotes[2].id == 'note_2'; // Indexing B-Tree
          }),
        ),
      );
    });

    test('DeleteNoteRequested removes note from active list', () async {
      bloc.add(const DeleteNoteRequested('note_1'));

      await expectLater(
        bloc.stream,
        emitsThrough(
          predicate<NoteListState>((state) {
            return state.allNotes.length == 2 &&
                !state.allNotes.any((n) => n.id == 'note_1');
          }),
        ),
      );
    });

    test('ClearFiltersRequested resets search query, subject and date', () async {
      bloc.add(const SearchQueryChanged('flutter'));
      bloc.add(const FilterSubjectChanged('sub_flutter'));
      bloc.add(FilterDateChanged(DateTime(2026, 10, 10)));
      bloc.add(const ClearFiltersRequested());

      await expectLater(
        bloc.stream,
        emitsThrough(
          predicate<NoteListState>((state) {
            return state.searchQuery == '' &&
                state.selectedSubjectId == null &&
                state.selectedDate == null &&
                state.filteredNotes.length == 3;
          }),
        ),
      );
    });
  });
}
