import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nhom_7/core/l10n/strings.dart';
import 'package:nhom_7/features/export/domain/models/pdf_export_models.dart';
import 'package:nhom_7/features/export/domain/services/pdf_generator_service.dart';
import 'package:nhom_7/features/export/presentation/bloc/pdf_export_bloc.dart';
import 'package:nhom_7/features/export/presentation/pages/pdf_export_page.dart';
import 'package:nhom_7/features/notes/domain/entities/lecture_note.dart';
import 'package:nhom_7/features/notes/domain/repositories/note_repository.dart';
import 'package:nhom_7/features/timetable/domain/entities/subject.dart';
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

  final sampleNote = LectureNote(
    id: 'note_1',
    subjectId: 'sub_1',
    title: 'Ghi chú bài 1',
    bodyText: 'Nội dung bài học',
    createdAt: DateTime(2026, 9, 15),
    updatedAt: DateTime(2026, 9, 15),
  );

  final mockResult = PdfRenderResult(
    bytes: Uint8List.fromList([0x25, 0x50, 0x44, 0x46, 0x2D, 0x31, 0x2E, 0x35]),
    durationMs: 95,
    sizeBytes: 153600, // 150 KB
  );

  setUp(() async {
    await GetIt.instance.reset();

    mockPdfService = MockPdfGeneratorService();
    mockTimetableRepo = MockTimetableRepository();
    mockNoteRepo = MockNoteRepository();

    when(() => mockTimetableRepo.getSubjects()).thenAnswer((_) async => [sampleSubject]);
    when(() => mockTimetableRepo.watchAllSlots()).thenAnswer((_) => Stream.value([]));
    when(() => mockTimetableRepo.getExams()).thenAnswer((_) async => []);
    when(() => mockTimetableRepo.getBuildings()).thenAnswer((_) async => []);
    when(() => mockTimetableRepo.getSubjectById(any())).thenAnswer((_) async => sampleSubject);
    when(() => mockTimetableRepo.getSlotById(any())).thenAnswer((_) async => null);

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

    GetIt.instance.registerFactory<PdfExportBloc>(
      () => PdfExportBloc(
        pdfGeneratorService: mockPdfService,
        timetableRepository: mockTimetableRepo,
        noteRepository: mockNoteRepo,
      ),
    );
  });

  tearDown(() async {
    await GetIt.instance.reset();
  });

  testWidgets('PdfExportPage renders title and segments correctly', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: PdfExportPage(initialType: PdfExportType.timetable),
      ),
    );

    // Initial loading
    expect(find.text(AppStrings.pdfExportTitle), findsOneWidget);

    // Pump until loaded
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 200));

    // Verify segments
    expect(find.text(AppStrings.exportTimetable), findsOneWidget);
    expect(find.text(AppStrings.exportNotes), findsOneWidget);

    // Verify benchmark banner
    expect(find.textContaining('NFR Benchmark:'), findsOneWidget);
    expect(find.textContaining('Đạt chuẩn'), findsOneWidget);

    // Verify action buttons
    expect(find.byIcon(Icons.stay_current_landscape_rounded), findsOneWidget);
    expect(find.byIcon(Icons.share_rounded), findsOneWidget);
  });

  testWidgets('PdfExportPage in note mode has no overflow on narrow 360px phone screen',
      (tester) async {
    tester.view.physicalSize = const Size(360, 760);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final longNote = LectureNote(
      id: 'note_long',
      subjectId: 'sub_1',
      title: 'Bài giảng rất dài về kiến trúc phần mềm và xuất PDF Unicode',
      bodyText: 'Nội dung chi tiết',
      createdAt: DateTime(2026, 9, 15),
      updatedAt: DateTime(2026, 9, 15),
    );
    when(() => mockNoteRepo.getAllNotes()).thenAnswer((_) async => [longNote]);
    when(() => mockNoteRepo.getNoteById(any())).thenAnswer((_) async => longNote);

    await tester.pumpWidget(
      const MaterialApp(
        home: PdfExportPage(initialType: PdfExportType.note),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text(AppStrings.exportTimetable), findsOneWidget);
    expect(find.text(AppStrings.exportNotes), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('PdfExportPage in note mode with 1.3x text scale on 320px width has zero overflow',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: Size(320, 640),
            textScaler: TextScaler.linear(1.3),
          ),
          child: PdfExportPage(initialType: PdfExportType.note),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text(AppStrings.exportTimetable), findsOneWidget);
    expect(find.text(AppStrings.exportNotes), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('PdfExportPage in note mode with no notes shows empty guidance while keeping mode switcher',
      (tester) async {
    when(() => mockNoteRepo.getAllNotes()).thenAnswer((_) async => []);

    await tester.pumpWidget(
      const MaterialApp(
        home: PdfExportPage(initialType: PdfExportType.note),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text(AppStrings.exportTimetable), findsOneWidget);
    expect(find.text(AppStrings.exportNotes), findsOneWidget);
    expect(find.text('Chưa có ghi chú bài giảng nào để xuất PDF'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
