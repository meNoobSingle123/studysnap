import 'package:equatable/equatable.dart';
import '../../domain/models/pdf_export_models.dart';

abstract class PdfExportEvent extends Equatable {
  const PdfExportEvent();

  @override
  List<Object?> get props => [];
}

/// Khởi tạo xuất PDF với chế độ và dữ liệu tương ứng.
class InitPdfExportEvent extends PdfExportEvent {
  final PdfExportType type;
  final String? initialNoteId;

  const InitPdfExportEvent({
    this.type = PdfExportType.timetable,
    this.initialNoteId,
  });

  @override
  List<Object?> get props => [type, initialNoteId];
}

/// Thay đổi loại tài liệu muốn xuất (Thời khóa biểu hoặc Ghi chú).
class ChangePdfTypeEvent extends PdfExportEvent {
  final PdfExportType type;
  final String? noteId;

  const ChangePdfTypeEvent(this.type, {this.noteId});

  @override
  List<Object?> get props => [type, noteId];
}

/// Thay đổi khổ giấy (Dọc hoặc Ngang).
class ChangePdfOrientationEvent extends PdfExportEvent {
  final PdfOrientation orientation;

  const ChangePdfOrientationEvent(this.orientation);

  @override
  List<Object?> get props => [orientation];
}

/// Chọn một ghi chú khác để xem và xuất PDF.
class SelectNoteForExportEvent extends PdfExportEvent {
  final String noteId;

  const SelectNoteForExportEvent(this.noteId);

  @override
  List<Object?> get props => [noteId];
}

/// Chia sẻ file PDF đang xem qua hệ điều hành.
class SharePdfEvent extends PdfExportEvent {
  const SharePdfEvent();
}

/// Lưu và mở file PDF bằng ứng dụng đọc PDF ngoài.
class OpenWithExternalAppEvent extends PdfExportEvent {
  const OpenWithExternalAppEvent();
}
