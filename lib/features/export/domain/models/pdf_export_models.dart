import 'dart:typed_data';
import 'package:equatable/equatable.dart';

import '../../../notes/domain/entities/lecture_note.dart';
import '../../../timetable/domain/entities/campus_building.dart';
import '../../../timetable/domain/entities/exam_schedule.dart';
import '../../../timetable/domain/entities/subject.dart';
import '../../../timetable/domain/entities/timetable_slot.dart';

/// Chế độ xuất PDF: Thời khóa biểu & Lịch thi, hoặc Ghi chú bài giảng.
enum PdfExportType {
  timetable,
  note,
}

/// Khổ giấy xuất file A4: Khổ dọc (Portrait) hoặc Khổ ngang (Landscape).
enum PdfOrientation {
  portrait,
  landscape,
}

/// Dữ liệu phục vụ xuất Thời khóa biểu & Lịch thi sang PDF.
class TimetableExportData extends Equatable {
  final String term;
  final List<Subject> subjects;
  final List<TimetableSlot> slots;
  final List<ExamSchedule> exams;
  final List<CampusBuilding> buildings;

  const TimetableExportData({
    this.term = 'Học kỳ 2026-1',
    required this.subjects,
    required this.slots,
    required this.exams,
    required this.buildings,
  });

  Subject? findSubject(String subjectId) {
    try {
      return subjects.firstWhere((s) => s.id == subjectId);
    } catch (_) {
      return null;
    }
  }

  CampusBuilding? findBuilding(String? buildingId) {
    if (buildingId == null) return null;
    try {
      return buildings.firstWhere((b) => b.id == buildingId);
    } catch (_) {
      return null;
    }
  }

  @override
  List<Object?> get props => [term, subjects, slots, exams, buildings];
}

/// Dữ liệu phục vụ xuất Ghi chú bài giảng sang PDF.
class NoteExportData extends Equatable {
  final LectureNote note;
  final Subject? subject;
  final TimetableSlot? slot;
  final List<Uint8List> imageBytesList;

  const NoteExportData({
    required this.note,
    this.subject,
    this.slot,
    this.imageBytesList = const [],
  });

  @override
  List<Object?> get props => [note, subject, slot, imageBytesList];
}

/// Kết quả render file PDF kèm chỉ số hiệu năng (NFR Benchmark).
class PdfRenderResult extends Equatable {
  final Uint8List bytes;
  final int durationMs;
  final int sizeBytes;

  const PdfRenderResult({
    required this.bytes,
    required this.durationMs,
    required this.sizeBytes,
  });

  /// DoD NFR: Kích thước ≤ 8MB (8,388,608 bytes) và thời gian sinh ≤ 2.5s (2500ms).
  bool get isNfrCompliant => sizeBytes <= 8 * 1024 * 1024 && durationMs <= 2500;

  double get sizeInKb => sizeBytes / 1024;
  double get sizeInMb => sizeBytes / (1024 * 1024);

  @override
  List<Object?> get props => [bytes, durationMs, sizeBytes];
}
