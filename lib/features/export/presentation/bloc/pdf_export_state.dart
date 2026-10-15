import 'package:equatable/equatable.dart';

import '../../../notes/domain/entities/lecture_note.dart';
import '../../domain/models/pdf_export_models.dart';

abstract class PdfExportState extends Equatable {
  const PdfExportState();

  @override
  List<Object?> get props => [];
}

class PdfExportInitial extends PdfExportState {
  const PdfExportInitial();
}

class PdfExportLoading extends PdfExportState {
  final String message;
  const PdfExportLoading({this.message = 'Đang kết xuất tài liệu PDF...'});

  @override
  List<Object?> get props => [message];
}

class PdfExportLoaded extends PdfExportState {
  final PdfRenderResult result;
  final PdfExportType exportType;
  final PdfOrientation orientation;
  final String? selectedNoteId;
  final List<LectureNote> availableNotes;
  final TimetableExportData? timetableData;
  final NoteExportData? currentNoteData;
  final String? actionFeedback; // Thông báo chia sẻ / mở file

  const PdfExportLoaded({
    required this.result,
    required this.exportType,
    required this.orientation,
    this.selectedNoteId,
    this.availableNotes = const [],
    this.timetableData,
    this.currentNoteData,
    this.actionFeedback,
  });

  PdfExportLoaded copyWith({
    PdfRenderResult? result,
    PdfExportType? exportType,
    PdfOrientation? orientation,
    String? selectedNoteId,
    List<LectureNote>? availableNotes,
    TimetableExportData? timetableData,
    NoteExportData? currentNoteData,
    String? actionFeedback,
    bool clearActionFeedback = false,
  }) {
    return PdfExportLoaded(
      result: result ?? this.result,
      exportType: exportType ?? this.exportType,
      orientation: orientation ?? this.orientation,
      selectedNoteId: selectedNoteId ?? this.selectedNoteId,
      availableNotes: availableNotes ?? this.availableNotes,
      timetableData: timetableData ?? this.timetableData,
      currentNoteData: currentNoteData ?? this.currentNoteData,
      actionFeedback: clearActionFeedback ? null : (actionFeedback ?? this.actionFeedback),
    );
  }

  @override
  List<Object?> get props => [
        result,
        exportType,
        orientation,
        selectedNoteId,
        availableNotes,
        timetableData,
        currentNoteData,
        actionFeedback,
      ];
}

class PdfExportError extends PdfExportState {
  final String message;

  const PdfExportError(this.message);

  @override
  List<Object?> get props => [message];
}
