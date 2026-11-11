import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:printing/printing.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/l10n/strings.dart';
import '../../domain/models/pdf_export_models.dart';
import '../bloc/pdf_export_bloc.dart';
import '../bloc/pdf_export_event.dart';
import '../bloc/pdf_export_state.dart';

/// Màn hình S09 - Xuất tài liệu & Xem trước PDF (A4).
///
/// Các chức năng chính (CĐ 4 & S09):
/// 1. Tương tác đa chế độ: Xuất Thời khóa biểu & Lịch thi hoặc Ghi chú bài giảng.
/// 2. Chuyển đổi linh hoạt khổ giấy A4: Khổ dọc (Portrait) hoặc Khổ ngang (Landscape).
/// 3. In ấn (Print), Chia sẻ (Share) qua mạng xã hội/AirDrop, Mở bằng ứng dụng đọc PDF ngoài.
/// 4. Giám sát thời gian thực chỉ số hiệu năng (NFR Benchmark: File size ≤ 8MB, Render ≤ 2.5s).
class PdfExportPage extends StatelessWidget {
  final PdfExportType initialType;
  final String? initialNoteId;

  const PdfExportPage({
    super.key,
    this.initialType = PdfExportType.timetable,
    this.initialNoteId,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => getIt<PdfExportBloc>()
        ..add(InitPdfExportEvent(
          type: initialType,
          initialNoteId: initialNoteId,
        )),
      child: const _PdfExportView(),
    );
  }
}

class _PdfExportView extends StatelessWidget {
  const _PdfExportView();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<PdfExportBloc, PdfExportState>(
      listener: (context, state) {
        if (state is PdfExportLoaded && state.actionFeedback != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.actionFeedback!),
              duration: const Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(
            title: const Text(
              AppStrings.pdfExportTitle,
              style: TextStyle(fontSize: 18),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            actions: [
              if (state is PdfExportLoaded && state.result.bytes.isNotEmpty) ...[
                // Nút xoay khổ giấy
                IconButton(
                  tooltip: state.orientation == PdfOrientation.portrait
                      ? 'Chuyển sang khổ ngang (Landscape)'
                      : 'Chuyển sang khổ dọc (Portrait)',
                  icon: Icon(
                    state.orientation == PdfOrientation.portrait
                        ? Icons.stay_current_landscape_rounded
                        : Icons.stay_current_portrait_rounded,
                  ),
                  onPressed: () {
                    final next = state.orientation == PdfOrientation.portrait
                        ? PdfOrientation.landscape
                        : PdfOrientation.portrait;
                    context.read<PdfExportBloc>().add(ChangePdfOrientationEvent(next));
                  },
                ),
                // Nút chia sẻ PDF
                IconButton(
                  tooltip: AppStrings.sharePdf,
                  icon: const Icon(Icons.share_rounded),
                  onPressed: () {
                    context.read<PdfExportBloc>().add(const SharePdfEvent());
                  },
                ),
                // Menu tùy chọn thêm
                PopupMenuButton<String>(
                  tooltip: 'Tùy chọn khác',
                  onSelected: (value) {
                    if (value == 'open_external') {
                      context.read<PdfExportBloc>().add(const OpenWithExternalAppEvent());
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'open_external',
                      child: Row(
                        children: [
                          Icon(Icons.open_in_new_rounded, size: 20),
                          SizedBox(width: 8),
                          Text(AppStrings.openWithExternalApp),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
          body: _buildBody(context, state),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, PdfExportState state) {
    if (state is PdfExportLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(state.message, style: const TextStyle(fontSize: 14)),
          ],
        ),
      );
    }

    if (state is PdfExportError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text(
                state.message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Thử lại'),
                onPressed: () {
                  context.read<PdfExportBloc>().add(const InitPdfExportEvent());
                },
              ),
            ],
          ),
        ),
      );
    }

    if (state is PdfExportLoaded) {
      final hasPdfDocument = state.result.bytes.isNotEmpty;
      final validSelectedNoteId =
          state.availableNotes.any((n) => n.id == state.selectedNoteId)
              ? state.selectedNoteId
              : (state.availableNotes.isNotEmpty
                  ? state.availableNotes.first.id
                  : null);

      return Column(
        children: [
          // Bảng điều khiển chọn loại tài liệu
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            child: MediaQuery.withClampedTextScaling(
              maxScaleFactor: 1.05,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SegmentedButton<PdfExportType>(
                    showSelectedIcon: false,
                    style: SegmentedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                      textStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    segments: const [
                      ButtonSegment(
                        value: PdfExportType.timetable,
                        icon: Icon(Icons.calendar_month_rounded, size: 16),
                        label: Text(
                          AppStrings.exportTimetable,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      ),
                      ButtonSegment(
                        value: PdfExportType.note,
                        icon: Icon(Icons.menu_book_rounded, size: 16),
                        label: Text(
                          AppStrings.exportNotes,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                    selected: {state.exportType},
                    onSelectionChanged: (newSelection) {
                      context.read<PdfExportBloc>().add(ChangePdfTypeEvent(newSelection.first));
                    },
                  ),
                  // Nếu đang ở chế độ xuất ghi chú và có ghi chú
                  if (state.exportType == PdfExportType.note && state.availableNotes.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      key: ValueKey(validSelectedNoteId),
                      initialValue: validSelectedNoteId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        labelText: 'Chọn bài giảng muốn xuất',
                        border: OutlineInputBorder(),
                      ),
                      items: state.availableNotes.map((note) {
                        final noteTitle = note.title.trim().isNotEmpty
                            ? note.title
                            : AppStrings.untitledNote;
                        return DropdownMenuItem(
                          value: note.id,
                          child: Text(
                            noteTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (noteId) {
                        if (noteId != null) {
                          context.read<PdfExportBloc>().add(SelectNoteForExportEvent(noteId));
                        }
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Vùng hiển thị xem trước PDF tương tác hoặc trạng thái chưa có ghi chú
          Expanded(
            child: !hasPdfDocument && state.exportType == PdfExportType.note
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.note_alt_outlined,
                            size: 56,
                            color: Theme.of(context).colorScheme.outline,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Chưa có ghi chú bài giảng nào để xuất PDF',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Hãy tạo một ghi chú trong tab Ghi chú hoặc từ công cụ Chụp ảnh / Bảng vẽ trước khi xuất PDF.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                  )
                : PdfPreview(
                    build: (format) async => state.result.bytes,
                    canChangePageFormat: false,
                    canChangeOrientation: false,
                    canDebug: false,
                    scrollViewDecoration: const BoxDecoration(color: Colors.black12),
                    pdfFileName: state.exportType == PdfExportType.timetable
                        ? 'StudySnap_ThoiKhoaBieu.pdf'
                        : 'StudySnap_GhiChu.pdf',
                  ),
          ),

          // Thanh hiển thị chỉ số hiệu năng (NFR Benchmark)
          if (hasPdfDocument)
            SafeArea(
              top: false,
              child: _buildBenchmarkBanner(state.result),
            ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildBenchmarkBanner(PdfRenderResult result) {
    final isPass = result.isNfrCompliant;
    final color = isPass ? Colors.teal : Colors.deepOrange;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border(top: BorderSide(color: color.withValues(alpha: 0.3))),
      ),
      child: Row(
        children: [
          Icon(
            isPass ? Icons.check_circle_rounded : Icons.warning_rounded,
            color: color,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'NFR Benchmark: ${result.sizeInKb.toStringAsFixed(1)} KB (≤ 8MB) | Render: ${result.durationMs}ms (≤ 2500ms) - ${isPass ? "Đạt chuẩn" : "Chưa đạt"}',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
                color: color.shade800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
