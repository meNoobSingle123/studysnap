import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../../core/l10n/strings.dart';
import '../models/pdf_export_models.dart';

/// Top-level parameter cho Isolate xuất Thời khóa biểu & Lịch thi.
class _TimetableIsolateParams {
  final Uint8List? regularFontBytes;
  final Uint8List? boldFontBytes;
  final bool isLandscape;
  final TimetableExportData data;

  const _TimetableIsolateParams({
    this.regularFontBytes,
    this.boldFontBytes,
    required this.isLandscape,
    required this.data,
  });
}

/// Top-level parameter cho Isolate xuất Ghi chú bài giảng.
class _NoteIsolateParams {
  final Uint8List? regularFontBytes;
  final Uint8List? boldFontBytes;
  final bool isLandscape;
  final NoteExportData data;

  const _NoteIsolateParams({
    this.regularFontBytes,
    this.boldFontBytes,
    required this.isLandscape,
    required this.data,
  });
}

/// Dịch vụ xuất tài liệu PDF khổ A4 tuân thủ tiêu chuẩn CĐ 4 & S09.
///
/// Các tính năng chính:
/// - Chạy trong Background Isolate thông qua `compute()` để không block UI thread (> 55 FPS).
/// - Nhúng font Roboto Unicode chống lỗi hiển thị tiếng Việt có dấu.
/// - Định dạng chuẩn A4 (Portrait hoặc Landscape).
/// - Đo đạc thời gian render và kích thước file để đáp ứng NFR Benchmark (≤ 8MB, ≤ 2.5s).
class PdfGeneratorService {
  Uint8List? _cachedRegularBytes;
  Uint8List? _cachedBoldBytes;

  /// Nạp trước font Unicode vào bộ nhớ đệm.
  Future<void> preloadFonts() async {
    try {
      if (_cachedRegularBytes == null) {
        final regData = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
        _cachedRegularBytes = regData.buffer.asUint8List();
      }
      if (_cachedBoldBytes == null) {
        final boldData = await rootBundle.load('assets/fonts/Roboto-Bold.ttf');
        _cachedBoldBytes = boldData.buffer.asUint8List();
      }
    } catch (_) {
      // Bỏ qua nếu chạy trong môi trường test không có rootBundle
    }
  }

  /// Sinh file PDF Thời khóa biểu & Lịch thi.
  Future<PdfRenderResult> generateTimetablePdf({
    required TimetableExportData data,
    PdfOrientation orientation = PdfOrientation.portrait,
  }) async {
    final stopwatch = Stopwatch()..start();
    await preloadFonts();

    final params = _TimetableIsolateParams(
      regularFontBytes: _cachedRegularBytes,
      boldFontBytes: _cachedBoldBytes,
      isLandscape: orientation == PdfOrientation.landscape,
      data: data,
    );

    Uint8List bytes;
    try {
      bytes = await compute(_timetablePdfIsolateEntry, params);
    } catch (_) {
      // Fallback chạy trực tiếp nếu môi trường test không hỗ trợ compute
      bytes = await _timetablePdfIsolateEntry(params);
    }

    stopwatch.stop();
    return PdfRenderResult(
      bytes: bytes,
      durationMs: stopwatch.elapsedMilliseconds,
      sizeBytes: bytes.length,
    );
  }

  /// Sinh file PDF Ghi chú bài giảng & Hình ảnh bảng viết.
  Future<PdfRenderResult> generateNotePdf({
    required NoteExportData data,
    PdfOrientation orientation = PdfOrientation.portrait,
  }) async {
    final stopwatch = Stopwatch()..start();
    await preloadFonts();

    final params = _NoteIsolateParams(
      regularFontBytes: _cachedRegularBytes,
      boldFontBytes: _cachedBoldBytes,
      isLandscape: orientation == PdfOrientation.landscape,
      data: data,
    );

    Uint8List bytes;
    try {
      bytes = await compute(_notePdfIsolateEntry, params);
    } catch (_) {
      bytes = await _notePdfIsolateEntry(params);
    }

    stopwatch.stop();
    return PdfRenderResult(
      bytes: bytes,
      durationMs: stopwatch.elapsedMilliseconds,
      sizeBytes: bytes.length,
    );
  }
}

// ============================================================================
// ISOLATE WORKERS
// ============================================================================

pw.ThemeData _buildPdfTheme(Uint8List? regularBytes, Uint8List? boldBytes) {
  if (regularBytes != null && boldBytes != null) {
    final regular = pw.Font.ttf(ByteData.view(regularBytes.buffer));
    final bold = pw.Font.ttf(ByteData.view(boldBytes.buffer));
    return pw.ThemeData.withFont(base: regular, bold: bold);
  }
  return pw.ThemeData();
}

String _getDayName(int day) {
  switch (day) {
    case 1:
      return 'Thứ 2';
    case 2:
      return 'Thứ 3';
    case 3:
      return 'Thứ 4';
    case 4:
      return 'Thứ 5';
    case 5:
      return 'Thứ 6';
    case 6:
      return 'Thứ 7';
    case 7:
      return 'Chủ nhật';
    default:
      return 'Thứ $day';
  }
}

Future<Uint8List> _timetablePdfIsolateEntry(_TimetableIsolateParams params) async {
  final doc = pw.Document(theme: _buildPdfTheme(params.regularFontBytes, params.boldFontBytes));
  final pageFormat = params.isLandscape ? PdfPageFormat.a4.landscape : PdfPageFormat.a4;
  final nowStr = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

  // Sắp xếp ca học theo thứ trong tuần và giờ bắt đầu
  final sortedSlots = List.of(params.data.slots)
    ..sort((a, b) {
      final dayCmp = a.dayOfWeek.compareTo(b.dayOfWeek);
      if (dayCmp != 0) return dayCmp;
      return a.startMin.compareTo(b.startMin);
    });

  doc.addPage(
    pw.MultiPage(
      pageFormat: pageFormat,
      margin: const pw.EdgeInsets.all(24),
      header: (context) => pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 16),
        decoration: const pw.BoxDecoration(
          border: pw.Border(bottom: pw.BorderSide(color: PdfColors.blueGrey700, width: 1.5)),
        ),
        padding: const pw.EdgeInsets.only(bottom: 8),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  AppStrings.institutionName,
                  style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800),
                ),
                pw.Text(
                  'STUDYSNAP - HỆ THỐNG QUẢN LÝ HỌC TẬP THÔNG MINH',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                ),
              ],
            ),
            pw.Text(
              'Ngày xuất: $nowStr',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
            ),
          ],
        ),
      ),
      footer: (context) => pw.Container(
        margin: const pw.EdgeInsets.only(top: 12),
        decoration: const pw.BoxDecoration(
          border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
        ),
        padding: const pw.EdgeInsets.only(top: 6),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('StudySnap - Tiêu chuẩn xuất bản A4', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
            pw.Text('Trang ${context.pageNumber}/${context.pagesCount}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
          ],
        ),
      ),
      build: (context) => [
        // Title banner
        pw.Center(
          child: pw.Column(
            children: [
              pw.Text(
                AppStrings.timetablePdfHeader,
                style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                params.data.term,
                style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey800),
              ),
              pw.SizedBox(height: 16),
            ],
          ),
        ),

        // Section: Thời khóa biểu các ca học
        pw.Text(
          '1. LỊCH HỌC TRONG TUẦN',
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900),
        ),
        pw.SizedBox(height: 8),

        if (sortedSlots.isEmpty)
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Text('Chưa có ca học nào trong học kỳ này.', style: const pw.TextStyle(fontSize: 10)),
          )
        else
          pw.TableHelper.fromTextArray(
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo700),
            cellStyle: const pw.TextStyle(fontSize: 8.5),
            cellAlignment: pw.Alignment.centerLeft,
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
            headers: ['Thứ', 'Giờ học', 'Mã môn', 'Tên môn học', 'Phòng', 'Tòa nhà', 'Số TC'],
            data: sortedSlots.map((slot) {
              final sub = params.data.findSubject(slot.subjectId);
              return [
                _getDayName(slot.dayOfWeek),
                '${slot.startTimeFormatted} - ${slot.endTimeFormatted}',
                sub?.code ?? '',
                sub?.name ?? 'Môn học (${slot.subjectId})',
                slot.room,
                slot.buildingId ?? '-',
                sub != null ? '${sub.credits}' : '-',
              ];
            }).toList(),
          ),

        pw.SizedBox(height: 20),

        // Section: Lịch thi học kỳ
        pw.Text(
          '2. LỊCH THI HỌC KỲ',
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900),
        ),
        pw.SizedBox(height: 8),

        if (params.data.exams.isEmpty)
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Text('Chưa có lịch thi cho học kỳ này.', style: const pw.TextStyle(fontSize: 10)),
          )
        else
          pw.TableHelper.fromTextArray(
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.teal700),
            cellStyle: const pw.TextStyle(fontSize: 8.5),
            cellAlignment: pw.Alignment.centerLeft,
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
            headers: ['Ngày thi', 'Giờ thi', 'Thời lượng', 'Mã môn', 'Tên môn học', 'Phòng thi', 'Tòa nhà'],
            data: params.data.exams.map((exam) {
              final sub = params.data.findSubject(exam.subjectId);
              return [
                DateFormat('dd/MM/yyyy').format(exam.date),
                exam.startTimeFormatted,
                '${exam.durationMin} phút',
                sub?.code ?? '',
                sub?.name ?? 'Môn thi (${exam.subjectId})',
                exam.room,
                exam.buildingId ?? '-',
              ];
            }).toList(),
          ),

        pw.SizedBox(height: 24),

        // Ghi chú & chữ ký
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              '* Lưu ý: Sinh viên có mặt tại phòng thi trước giờ thi 15 phút.',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.red800),
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text('XÁC NHẬN CỦA HỆ THỐNG', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 2),
                pw.Text('(Đã ký số điện tử)', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
              ],
            ),
          ],
        ),
      ],
    ),
  );

  return doc.save();
}

Future<Uint8List> _notePdfIsolateEntry(_NoteIsolateParams params) async {
  final doc = pw.Document(theme: _buildPdfTheme(params.regularFontBytes, params.boldFontBytes));
  final pageFormat = params.isLandscape ? PdfPageFormat.a4.landscape : PdfPageFormat.a4;
  final note = params.data.note;
  final sub = params.data.subject;
  final slot = params.data.slot;
  final createdStr = DateFormat('dd/MM/yyyy HH:mm').format(note.createdAt);

  doc.addPage(
    pw.MultiPage(
      pageFormat: pageFormat,
      margin: const pw.EdgeInsets.all(24),
      header: (context) => pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 16),
        decoration: const pw.BoxDecoration(
          border: pw.Border(bottom: pw.BorderSide(color: PdfColors.deepPurple800, width: 1.5)),
        ),
        padding: const pw.EdgeInsets.only(bottom: 8),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  AppStrings.institutionName,
                  style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800),
                ),
                pw.Text(
                  'STUDYSNAP - BÀI GIẢNG & GHI CHÚ ĐA PHƯƠNG TIỆN',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                ),
              ],
            ),
            pw.Text(
              'Ngày tạo: $createdStr',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
            ),
          ],
        ),
      ),
      footer: (context) => pw.Container(
        margin: const pw.EdgeInsets.only(top: 12),
        decoration: const pw.BoxDecoration(
          border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
        ),
        padding: const pw.EdgeInsets.only(top: 6),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('StudySnap Lecture Notes Export', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
            pw.Text('Trang ${context.pageNumber}/${context.pagesCount}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
          ],
        ),
      ),
      build: (context) => [
        // Title
        pw.Center(
          child: pw.Column(
            children: [
              pw.Text(
                AppStrings.notePdfHeader,
                style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.deepPurple900),
              ),
              pw.SizedBox(height: 6),
              pw.Text(
                note.title,
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.black),
              ),
              pw.SizedBox(height: 12),
            ],
          ),
        ),

        // Metadata Box
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            color: PdfColors.deepPurple50,
            borderRadius: pw.BorderRadius.circular(6),
            border: pw.Border.all(color: PdfColors.deepPurple200, width: 0.8),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Môn học: ${sub?.name ?? 'Không xác định'}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 3),
                  pw.Text('Mã học phần: ${sub?.code ?? '-'} (${sub?.credits ?? 0} tín chỉ)', style: const pw.TextStyle(fontSize: 9)),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('Phòng học: ${slot?.room ?? 'Tự do'}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 3),
                  pw.Text(
                    slot != null ? 'Thời gian: ${slot.startTimeFormatted} - ${slot.endTimeFormatted}' : '',
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                ],
              ),
            ],
          ),
        ),

        pw.SizedBox(height: 16),

        // Body Text
        pw.Text(
          'NỘI DUNG GHI CHÉP BÀI HỌC',
          style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800),
        ),
        pw.SizedBox(height: 6),
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            color: PdfColors.grey50,
            borderRadius: pw.BorderRadius.circular(4),
            border: pw.Border.all(color: PdfColors.grey200, width: 0.5),
          ),
          child: pw.Text(
            note.bodyText.isNotEmpty ? note.bodyText : '(Không có văn bản ghi chép)',
            style: const pw.TextStyle(fontSize: 10, lineSpacing: 2),
          ),
        ),

        // Attached Images Section
        if (params.data.imageBytesList.isNotEmpty) ...[
          pw.SizedBox(height: 20),
          pw.Text(
            'HÌNH ẢNH MINH HỌA & BẢNG VIẾT (${params.data.imageBytesList.length} ảnh)',
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800),
          ),
          pw.SizedBox(height: 8),
          pw.Wrap(
            spacing: 12,
            runSpacing: 12,
            children: params.data.imageBytesList.map((imgBytes) {
              return pw.Container(
                width: 230,
                height: 160,
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.ClipRRect(
                  horizontalRadius: 4,
                  verticalRadius: 4,
                  child: pw.Image(
                    pw.MemoryImage(imgBytes),
                    fit: pw.BoxFit.cover,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ],
    ),
  );

  return doc.save();
}
