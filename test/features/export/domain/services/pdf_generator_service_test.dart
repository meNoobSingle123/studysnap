import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:nhom_7/features/export/domain/models/pdf_export_models.dart';
import 'package:nhom_7/features/export/domain/services/pdf_generator_service.dart';
import 'package:nhom_7/features/notes/domain/entities/lecture_note.dart';
import 'package:nhom_7/features/timetable/domain/entities/campus_building.dart';
import 'package:nhom_7/features/timetable/domain/entities/exam_schedule.dart';
import 'package:nhom_7/features/timetable/domain/entities/subject.dart';
import 'package:nhom_7/features/timetable/domain/entities/timetable_slot.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PdfGeneratorService service;

  final sampleSubject = Subject(
    id: 'sub_1',
    code: 'CSC10006',
    name: 'Mạng máy tính cơ bản',
    credits: 4,
    colorArgb: 0xFF1976D2,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  final sampleSlot = TimetableSlot(
    id: 'slot_1',
    subjectId: 'sub_1',
    dayOfWeek: 2, // Thứ 3
    startMin: 450, // 07:30
    endMin: 540, // 09:00
    room: 'H2.304',
    buildingId: 'H2',
    termStart: DateTime(2026, 9, 1),
    termEnd: DateTime(2026, 12, 31),
    source: 'system',
    updatedAt: DateTime(2026, 9, 1),
  );

  final sampleExam = ExamSchedule(
    id: 'exam_1',
    subjectId: 'sub_1',
    date: DateTime(2026, 11, 20),
    startMin: 480, // 08:00
    durationMin: 90,
    room: 'H2.101',
    buildingId: 'H2',
    source: 'system',
  );

  final sampleBuilding = const CampusBuilding(
    id: 'H2',
    code: 'H2',
    name: 'Tòa nhà H2 - Cơ sở Linh Trung',
    latitude: 10.875,
    longitude: 106.800,
  );

  final sampleTimetableData = TimetableExportData(
    term: 'Học kỳ 2026-1',
    subjects: [sampleSubject],
    slots: [sampleSlot],
    exams: [sampleExam],
    buildings: [sampleBuilding],
  );

  final sampleNote = LectureNote(
    id: 'note_1',
    subjectId: 'sub_1',
    slotId: 'slot_1',
    title: 'Ghi chú Bài 1: Mô hình OSI & TCP/IP',
    bodyText: 'Mô hình OSI có 7 tầng: Vật lý, Liên kết dữ liệu, Mạng, Giao vận, Phiên, Trình diễn, Ứng dụng.',
    createdAt: DateTime(2026, 9, 15, 8, 30),
    updatedAt: DateTime(2026, 9, 15, 9, 0),
  );

  final sampleNoteData = NoteExportData(
    note: sampleNote,
    subject: sampleSubject,
    slot: sampleSlot,
  );

  setUp(() {
    service = PdfGeneratorService();
  });

  group('PdfGeneratorService - Timetable Export Tests', () {
    test('generateTimetablePdf generates valid PDF bytes in Portrait mode', () async {
      final result = await service.generateTimetablePdf(
        data: sampleTimetableData,
        orientation: PdfOrientation.portrait,
      );

      expect(result.bytes, isNotEmpty);
      // Kiểm tra magic number của PDF: %PDF-1.
      final headerStr = utf8.decode(result.bytes.sublist(0, 8), allowMalformed: true);
      expect(headerStr.startsWith('%PDF-1.'), isTrue);

      // Kiểm tra NFR: File ≤ 8MB và Render ≤ 2500ms
      expect(result.isNfrCompliant, isTrue);
      expect(result.sizeBytes, lessThan(8 * 1024 * 1024));
      expect(result.durationMs, lessThan(2500));
    });

    test('generateTimetablePdf generates valid PDF bytes in Landscape mode', () async {
      final result = await service.generateTimetablePdf(
        data: sampleTimetableData,
        orientation: PdfOrientation.landscape,
      );

      expect(result.bytes, isNotEmpty);
      final headerStr = utf8.decode(result.bytes.sublist(0, 8), allowMalformed: true);
      expect(headerStr.startsWith('%PDF-1.'), isTrue);
      expect(result.isNfrCompliant, isTrue);
    });

    test('generateTimetablePdf handles empty slots and exams gracefully', () async {
      final emptyData = const TimetableExportData(
        term: 'Học kỳ trống 2026-2',
        subjects: [],
        slots: [],
        exams: [],
        buildings: [],
      );

      final result = await service.generateTimetablePdf(data: emptyData);

      expect(result.bytes, isNotEmpty);
      expect(result.isNfrCompliant, isTrue);
    });
  });

  group('PdfGeneratorService - Lecture Note Export Tests', () {
    test('generateNotePdf generates valid PDF bytes with full note content', () async {
      final result = await service.generateNotePdf(
        data: sampleNoteData,
        orientation: PdfOrientation.portrait,
      );

      expect(result.bytes, isNotEmpty);
      final headerStr = utf8.decode(result.bytes.sublist(0, 8), allowMalformed: true);
      expect(headerStr.startsWith('%PDF-1.'), isTrue);
      expect(result.isNfrCompliant, isTrue);
      expect(result.sizeBytes, lessThan(8 * 1024 * 1024));
    });

    test('generateNotePdf handles note without slot and subject gracefully', () async {
      final soloNote = LectureNote(
        id: 'solo_note',
        subjectId: 'unknown',
        title: 'Ghi chú tự do ngoài giờ',
        bodyText: 'Ý tưởng nghiên cứu cá nhân.',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final result = await service.generateNotePdf(
        data: NoteExportData(note: soloNote),
      );

      expect(result.bytes, isNotEmpty);
      expect(result.isNfrCompliant, isTrue);
    });
  });
}
