import 'dart:typed_data';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nhom_7/features/export/domain/models/pdf_export_models.dart';
import 'package:nhom_7/features/export/domain/services/pdf_generator_service.dart';
import 'package:nhom_7/features/export/presentation/bloc/pdf_export_bloc.dart';
import 'package:nhom_7/features/export/presentation/bloc/pdf_export_event.dart';
import 'package:nhom_7/features/export/presentation/bloc/pdf_export_state.dart';
import 'package:nhom_7/features/notes/domain/entities/lecture_note.dart';
import 'package:nhom_7/features/notes/domain/repositories/note_repository.dart';
import 'package:nhom_7/features/timetable/domain/entities/campus_building.dart';
import 'package:nhom_7/features/timetable/domain/entities/exam_schedule.dart';
import 'package:nhom_7/features/timetable/domain/entities/subject.dart';
import 'package:nhom_7/features/timetable/domain/entities/timetable_slot.dart';
import 'package:nhom_7/features/timetable/domain/repositories/timetable_repository.dart';

class MockPdfGeneratorService extends Mock implements PdfGeneratorService {}
class MockTimetableRepository extends Mock implements TimetableRepository {}
class MockNoteRepository extends Mock implements NoteRepository {}

class FakeTimetableExportData extends Fake implements TimetableExportData {}
class FakeNoteExportData extends Fake implements NoteExportData {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(FakeTimetableExportData());
    registerFallbackValue(FakeNoteExportData());
    registerFallbackValue(PdfOrientation.portrait);
  });

  late MockPdfGeneratorService mockPdfService;
  late MockTimetableRepository mockTimetableRepo;
  late MockNoteRepository mockNoteRepo;

  final sampleSubject = Subject(
    id: 'sub_1',
    code: 'CSC10006',
    name: 'Mạng máy tính',
    credits: 4,
    colorArgb: 0xFF1976D2,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  final sampleSlot = TimetableSlot(
    id: 'slot_1',
    subjectId: 'sub_1',
    dayOfWeek: 2,
    startMin: 450,
    endMin: 540,
    room: 'H2.304',
    termStart: DateTime(2026, 9, 1),
    termEnd: DateTime(2026, 12, 31),
    source: 'system',
    updatedAt: DateTime(2026, 9, 1),
  );

  final sampleExam = ExamSchedule(
    id: 'exam_1',
    subjectId: 'sub_1',
    date: DateTime(2026, 11, 20),
    startMin: 480,
    durationMin: 90,
    room: 'H2.101',
    source: 'system',
  );

  final sampleBuilding = const CampusBuilding(
    id: 'H2',
    code: 'H2',
    name: 'Tòa nhà H2',
    latitude: 10.8,
    longitude: 106.8,
  );

  final sampleNote = LectureNote(
    id: 'note_1',
    subjectId: 'sub_1',
    slotId: 'slot_1',
    title: 'Ghi chú bài 1',
    bodyText: 'Nội dung bài học',
    createdAt: DateTime(2026, 9, 15),
    updatedAt: DateTime(2026, 9, 15),
  );

  final mockResult = PdfRenderResult(
    bytes: Uint8List.fromList([0x25, 0x50, 0x44, 0x46, 0x2D, 0x31, 0x2E, 0x35]), // %PDF-1.5
    durationMs: 120,
    sizeBytes: 102400,
  );

  setUp(() {
    mockPdfService = MockPdfGeneratorService();
    mockTimetableRepo = MockTimetableRepository();
    mockNoteRepo = MockNoteRepository();

    when(() => mockTimetableRepo.getSubjects()).thenAnswer((_) async => [sampleSubject]);
    when(() => mockTimetableRepo.watchAllSlots()).thenAnswer((_) => Stream.value([sampleSlot]));
    when(() => mockTimetableRepo.getExams()).thenAnswer((_) async => [sampleExam]);
    when(() => mockTimetableRepo.getBuildings()).thenAnswer((_) async => [sampleBuilding]);
    when(() => mockTimetableRepo.getSubjectById(any())).thenAnswer((_) async => sampleSubject);
    when(() => mockTimetableRepo.getSlotById(any())).thenAnswer((_) async => sampleSlot);

    when(() => mockNoteRepo.getAllNotes()).thenAnswer((_) async => [sampleNote]);
    when(() => mockNoteRepo.getNoteById(any())).thenAnswer((_) async => sampleNote);

    when(() => mockPdfService.generateTimetablePdf(
          data: any(named: 'data'),
          orientation: any(named: 'orientation'),
        )).thenAnswer((_) async => mockResult);

    when(() => mockPdfService.generateNotePdf(
          data: any(named: 'data'),
          orientation: any(named: 'orientation'),
        )).thenAnswer((_) async => mockResult);
  });

  PdfExportBloc buildBloc() {
    return PdfExportBloc(
      pdfGeneratorService: mockPdfService,
      timetableRepository: mockTimetableRepo,
      noteRepository: mockNoteRepo,
    );
  }

  group('PdfExportBloc Tests', () {
    test('initial state is PdfExportInitial', () {
      final bloc = buildBloc();
      expect(bloc.state, equals(const PdfExportInitial()));
    });

    blocTest<PdfExportBloc, PdfExportState>(
      'emits [PdfExportLoading, PdfExportLoaded] when InitPdfExportEvent is added for timetable',
      build: buildBloc,
      act: (bloc) => bloc.add(const InitPdfExportEvent(type: PdfExportType.timetable)),
      expect: () => [
        isA<PdfExportLoading>(),
        isA<PdfExportLoaded>()
            .having((s) => s.exportType, 'exportType', PdfExportType.timetable)
            .having((s) => s.orientation, 'orientation', PdfOrientation.portrait)
            .having((s) => s.result.bytes, 'bytes', mockResult.bytes),
      ],
      verify: (_) {
        verify(() => mockPdfService.generateTimetablePdf(
              data: any(named: 'data'),
              orientation: PdfOrientation.portrait,
            )).called(1);
      },
    );

    blocTest<PdfExportBloc, PdfExportState>(
      'emits [PdfExportLoading, PdfExportLoaded] when InitPdfExportEvent is added for note',
      build: buildBloc,
      act: (bloc) => bloc.add(const InitPdfExportEvent(
        type: PdfExportType.note,
        initialNoteId: 'note_1',
      )),
      expect: () => [
        isA<PdfExportLoading>(),
        isA<PdfExportLoaded>()
            .having((s) => s.exportType, 'exportType', PdfExportType.note)
            .having((s) => s.selectedNoteId, 'selectedNoteId', 'note_1')
            .having((s) => s.result.bytes, 'bytes', mockResult.bytes),
      ],
      verify: (_) {
        verify(() => mockPdfService.generateNotePdf(
              data: any(named: 'data'),
              orientation: PdfOrientation.portrait,
            )).called(1);
      },
    );

    blocTest<PdfExportBloc, PdfExportState>(
      'switches orientation when ChangePdfOrientationEvent is added',
      build: buildBloc,
      seed: () => PdfExportLoaded(
        result: mockResult,
        exportType: PdfExportType.timetable,
        orientation: PdfOrientation.portrait,
      ),
      act: (bloc) => bloc.add(const ChangePdfOrientationEvent(PdfOrientation.landscape)),
      expect: () => [
        isA<PdfExportLoading>(),
        isA<PdfExportLoaded>()
            .having((s) => s.orientation, 'orientation', PdfOrientation.landscape),
      ],
      verify: (_) {
        verify(() => mockPdfService.generateTimetablePdf(
              data: any(named: 'data'),
              orientation: PdfOrientation.landscape,
            )).called(1);
      },
    );

    blocTest<PdfExportBloc, PdfExportState>(
      'switches export type when ChangePdfTypeEvent is added',
      build: buildBloc,
      seed: () => PdfExportLoaded(
        result: mockResult,
        exportType: PdfExportType.timetable,
        orientation: PdfOrientation.portrait,
        availableNotes: [sampleNote],
        selectedNoteId: 'note_1',
      ),
      act: (bloc) => bloc.add(const ChangePdfTypeEvent(PdfExportType.note, noteId: 'note_1')),
      expect: () => [
        isA<PdfExportLoading>(),
        isA<PdfExportLoaded>()
            .having((s) => s.exportType, 'exportType', PdfExportType.note),
      ],
      verify: (_) {
        verify(() => mockPdfService.generateNotePdf(
              data: any(named: 'data'),
              orientation: PdfOrientation.portrait,
            )).called(1);
      },
    );
  });
}
