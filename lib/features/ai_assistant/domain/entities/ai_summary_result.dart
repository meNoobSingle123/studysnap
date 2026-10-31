import 'package:equatable/equatable.dart';

/// Kết quả tóm tắt nội dung bài học từ Trợ lý AI.
class AiSummaryResult extends Equatable {
  final String title;
  final String summary;
  final List<String> keyPoints;
  final List<String> practicalTakeaways;

  const AiSummaryResult({
    required this.title,
    required this.summary,
    this.keyPoints = const [],
    this.practicalTakeaways = const [],
  });

  /// Chuyển đổi thành chuỗi định dạng Markdown để chèn vào ghi chú.
  String toMarkdown() {
    final buffer = StringBuffer();
    buffer.writeln('\n\n---');
    buffer.writeln('### 🤖 Tóm tắt thông minh (Trợ lý AI)');
    buffer.writeln(summary);
    if (keyPoints.isNotEmpty) {
      buffer.writeln('\n**Ý chính cốt lõi:**');
      for (final point in keyPoints) {
        buffer.writeln('- $point');
      }
    }
    if (practicalTakeaways.isNotEmpty) {
      buffer.writeln('\n**Lưu ý ôn thi / Thực hành:**');
      for (final item in practicalTakeaways) {
        buffer.writeln('💡 $item');
      }
    }
    return buffer.toString();
  }

  @override
  List<Object?> get props => [title, summary, keyPoints, practicalTakeaways];
}

