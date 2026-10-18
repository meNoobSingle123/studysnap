import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';

import '../../../notes/domain/entities/lecture_note.dart';
import '../../../notes/domain/repositories/note_repository.dart';
import '../../../timetable/domain/entities/subject.dart';
import '../../../timetable/domain/entities/timetable_slot.dart';
import '../../../timetable/domain/repositories/timetable_repository.dart';
import '../../domain/models/pdf_export_models.dart';
import '../../domain/services/pdf_generator_service.dart';
import 'pdf_export_event.dart';
import 'pdf_export_state.dart';

class PdfExportBloc extends Bloc<PdfExportEvent, PdfExportState> {
  final PdfGeneratorService pdfGeneratorService;
  final TimetableRepository timetableRepository;
  final NoteRepository noteRepository;

  PdfExportBloc({
    required this.pdfGeneratorService,
    required this.timetableRepository,
    required this.noteRepository,
  }) : super(const PdfExportInitial()) {
    on<InitPdfExportEvent>(_onInit);
    on<ChangePdfTypeEvent>(_onChangeType);
    on<ChangePdfOrientationEvent>(_onChangeOrientation);
    on<SelectNoteForExportEvent>(_onSelectNote);
    on<SharePdfEvent>(_onSharePdf);
    on<OpenWithExternalAppEvent>(_onOpenWithExternalApp);
  }

  Future<void> _onInit(InitPdfExportEvent event, Emitter<PdfExportState> emit) async {
    emit(const PdfExportLoading(message: 'Đang chuẩn bị dữ liệu xuất PDF...'));
    try {
      final timetableData = await _loadTimetableData();
      final allNotes = await noteRepository.getAllNotes();

      String? targetNoteId = event.initialNoteId;
      if (targetNoteId == null && allNotes.isNotEmpty) {
        targetNoteId = allNotes.first.id;
      }

      NoteExportData? noteData;
      if (targetNoteId != null) {
        noteData = await _buildNoteExportData(targetNoteId, allNotes, timetableData.subjects);
      }

      final orientation = PdfOrientation.portrait;
      final result = await _renderDocument(
        type: event.type,
        orientation: orientation,
        timetableData: timetableData,
        noteData: noteData,
      );

      emit(PdfExportLoaded(
        result: result,
        exportType: event.type,
        orientation: orientation,
        selectedNoteId: targetNoteId,
        availableNotes: allNotes,
        timetableData: timetableData,
        currentNoteData: noteData,
      ));
    } catch (e) {
      emit(PdfExportError('Lỗi khởi tạo xuất PDF: ${e.toString()}'));
    }
  }

  Future<void> _onChangeType(ChangePdfTypeEvent event, Emitter<PdfExportState> emit) async {
    final current = state;
    if (current is! PdfExportLoaded) return;

    emit(const PdfExportLoading(message: 'Đang chuyển đổi định dạng tài liệu...'));
    try {
      NoteExportData? noteData = current.currentNoteData;
      String? noteId = event.noteId ?? current.selectedNoteId;

      if (event.type == PdfExportType.note && noteData == null && noteId != null) {
        noteData = await _buildNoteExportData(
          noteId,
          current.availableNotes,
          current.timetableData?.subjects ?? [],
        );
      }

      final result = await _renderDocument(
        type: event.type,
        orientation: current.orientation,
        timetableData: current.timetableData,
        noteData: noteData,
      );

      emit(current.copyWith(
        result: result,
        exportType: event.type,
        selectedNoteId: noteId,
        currentNoteData: noteData,
        clearActionFeedback: true,
      ));
    } catch (e) {
      emit(PdfExportError('Lỗi chuyển loại PDF: ${e.toString()}'));
    }
  }

  Future<void> _onChangeOrientation(
    ChangePdfOrientationEvent event,
    Emitter<PdfExportState> emit,
  ) async {
    final current = state;
    if (current is! PdfExportLoaded) return;
    if (current.orientation == event.orientation) return;

    emit(const PdfExportLoading(message: 'Đang định dạng lại khổ giấy...'));
    try {
      final result = await _renderDocument(
        type: current.exportType,
        orientation: event.orientation,
        timetableData: current.timetableData,
        noteData: current.currentNoteData,
      );

      emit(current.copyWith(
        result: result,
        orientation: event.orientation,
        clearActionFeedback: true,
      ));
    } catch (e) {
      emit(PdfExportError('Lỗi xoay khổ giấy: ${e.toString()}'));
    }
  }

  Future<void> _onSelectNote(
    SelectNoteForExportEvent event,
    Emitter<PdfExportState> emit,
  ) async {
    final current = state;
    if (current is! PdfExportLoaded) return;

    emit(const PdfExportLoading(message: 'Đang nạp ghi chú bài giảng...'));
    try {
      final noteData = await _buildNoteExportData(
        event.noteId,
        current.availableNotes,
        current.timetableData?.subjects ?? [],
      );

      final result = await _renderDocument(
        type: PdfExportType.note,
        orientation: current.orientation,
        timetableData: current.timetableData,
        noteData: noteData,
      );

      emit(current.copyWith(
        result: result,
        exportType: PdfExportType.note,
        selectedNoteId: event.noteId,
        currentNoteData: noteData,
        clearActionFeedback: true,
      ));
    } catch (e) {
      emit(PdfExportError('Lỗi nạp ghi chú: ${e.toString()}'));
    }
  }

  Future<void> _onSharePdf(SharePdfEvent event, Emitter<PdfExportState> emit) async {
    final current = state;
    if (current is! PdfExportLoaded) return;

    final fileName = current.exportType == PdfExportType.timetable
        ? 'StudySnap_ThoiKhoaBieu_${DateTime.now().millisecondsSinceEpoch}.pdf'
        : 'StudySnap_GhiChu_${DateTime.now().millisecondsSinceEpoch}.pdf';

    try {
      await Printing.sharePdf(
        bytes: current.result.bytes,
        filename: fileName,
      );
      emit(current.copyWith(actionFeedback: 'Đã mở hộp thoại chia sẻ PDF.'));
    } catch (e) {
      emit(current.copyWith(actionFeedback: 'Không thể chia sẻ file: $e'));
    }
  }

  Future<void> _onOpenWithExternalApp(
    OpenWithExternalAppEvent event,
    Emitter<PdfExportState> emit,
  ) async {
    final current = state;
    if (current is! PdfExportLoaded) return;

    try {
      final tempDir = await getTemporaryDirectory();
      final prefix = current.exportType == PdfExportType.timetable ? 'tkb' : 'note';
      final file = File('${tempDir.path}/studysnap_${prefix}_${DateTime.now().millisecondsSinceEpoch}.pdf');
      await file.writeAsBytes(current.result.bytes, flush: true);

      final openResult = await OpenFilex.open(file.path);
      if (openResult.type == ResultType.done) {
        emit(current.copyWith(actionFeedback: 'Đã mở file bằng ứng dụng ngoài.'));
      } else {
        emit(current.copyWith(actionFeedback: 'Không thể mở: ${openResult.message}'));
      }
    } catch (e) {
      emit(current.copyWith(actionFeedback: 'Lỗi khi mở file ngoài: $e'));
    }
  }

  // ============================================================================
  // PRIVATE HELPERS
  // ============================================================================

  Future<TimetableExportData> _loadTimetableData() async {
    try {
      final subjects = await timetableRepository.getSubjects();
      final slots = await timetableRepository.watchAllSlots().first;
      final exams = await timetableRepository.getExams();
      final buildings = await timetableRepository.getBuildings();

      return TimetableExportData(
        term: 'Học kỳ 2026-1',
        subjects: subjects,
        slots: slots,
        exams: exams,
        buildings: buildings,
      );
    } catch (_) {
      return const TimetableExportData(
        term: 'Học kỳ 2026-1',
        subjects: [],
        slots: [],
        exams: [],
        buildings: [],
      );
    }
  }

  Future<NoteExportData?> _buildNoteExportData(
    String noteId,
    List<LectureNote> notes,
    List<Subject> subjects,
  ) async {
    LectureNote? targetNote;
    try {
      targetNote = notes.firstWhere((n) => n.id == noteId);
    } catch (_) {
      targetNote = await noteRepository.getNoteById(noteId);
    }
    if (targetNote == null) return null;

    Subject? matchedSubject;
    try {
      matchedSubject = subjects.firstWhere((s) => s.id == targetNote!.subjectId);
    } catch (_) {
      matchedSubject = await timetableRepository.getSubjectById(targetNote.subjectId);
    }

    TimetableSlot? matchedSlot;
    if (targetNote.slotId != null) {
      matchedSlot = await timetableRepository.getSlotById(targetNote.slotId!);
    }

    final imageBytesList = <Uint8List>[];
    for (final path in targetNote.imagePaths) {
      try {
        final file = File(path);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          if (bytes.isNotEmpty) {
            imageBytesList.add(bytes);
          }
        }
      } catch (_) {
        // Skip unreadable image file
      }
    }

    return NoteExportData(
      note: targetNote,
      subject: matchedSubject,
      slot: matchedSlot,
      imageBytesList: imageBytesList,
    );
  }

  Future<PdfRenderResult> _renderDocument({
    required PdfExportType type,
    required PdfOrientation orientation,
    TimetableExportData? timetableData,
    NoteExportData? noteData,
  }) async {
    if (type == PdfExportType.timetable) {
      final data = timetableData ?? await _loadTimetableData();
      return pdfGeneratorService.generateTimetablePdf(
        data: data,
        orientation: orientation,
      );
    } else {
      if (noteData == null) {
        throw Exception('Chưa có dữ liệu ghi chú để xuất PDF');
      }
      return pdfGeneratorService.generateNotePdf(
        data: noteData,
        orientation: orientation,
      );
    }
  }
}
