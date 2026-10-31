import 'dart:convert';
import 'package:uuid/uuid.dart';

import '../../domain/entities/ai_quiz_question.dart';
import '../../domain/entities/ai_summary_result.dart';
import '../../domain/repositories/ai_assistant_repository.dart';
import '../datasources/gemini_remote_datasource.dart';

class AiAssistantRepositoryImpl implements AiAssistantRepository {
  final GeminiRemoteDataSource remoteDataSource;

  AiAssistantRepositoryImpl({
    required this.remoteDataSource,
  });

  @override
  Future<bool> hasApiKey() => remoteDataSource.hasApiKey();

  @override
  Future<String?> getApiKey() => remoteDataSource.getApiKey();

  @override
  Future<void> saveApiKey(String apiKey) => remoteDataSource.saveApiKey(apiKey);

  @override
  Future<AiSummaryResult> summarizeNote({
    required String title,
    required String content,
    String? subjectName,
  }) async {
    final prompt = '''
Bạn là trợ lý học tập đại học thông minh. Hãy đọc nội dung bài học dưới đây và tóm tắt cô đọng, dễ hiểu bằng tiếng Việt chuẩn.
Tiêu đề: "${title.isNotEmpty ? title : 'Bài giảng'}"
Môn học: "${subjectName ?? 'Tự do'}"
Nội dung bài học:
"""
$content
"""

Yêu cầu xuất ra ĐỊNH DẠNG JSON DUY NHẤT theo cấu trúc sau (không kèm lời chào hay văn bản ngoài JSON):
{
  "title": "Tiêu đề tóm tắt",
  "summary": "Tóm tắt tổng quan 2-3 câu súc tích",
  "keyPoints": [
    "Ý quan trọng 1",
    "Ý quan trọng 2",
    "Ý quan trọng 3"
  ],
  "practicalTakeaways": [
    "Lưu ý ôn thi / Mẹo nhớ nhanh / Ứng dụng"
  ]
}
''';

    final responseText = await remoteDataSource.generateContent(prompt: prompt);
    final cleanedJson = _extractJsonText(responseText);

    try {
      final Map<String, dynamic> parsed =
          jsonDecode(cleanedJson) as Map<String, dynamic>;

      final rawKeyPoints = parsed['keyPoints'] as List<dynamic>? ?? [];
      final rawTakeaways =
          parsed['practicalTakeaways'] as List<dynamic>? ?? [];

      return AiSummaryResult(
        title: parsed['title'] as String? ?? title,
        summary: parsed['summary'] as String? ?? responseText,
        keyPoints: rawKeyPoints.map((e) => e.toString()).toList(),
        practicalTakeaways: rawTakeaways.map((e) => e.toString()).toList(),
      );
    } catch (_) {
      // Fallback nếu JSON bị lệch chuẩn: giữ trọn vẹn văn bản tóm tắt
      return AiSummaryResult(
        title: title.isNotEmpty ? title : 'Tóm tắt bài giảng',
        summary: responseText.trim(),
        keyPoints: const [],
        practicalTakeaways: const [],
      );
    }
  }

  @override
  Future<List<AiQuizQuestion>> generateQuiz({
    required String title,
    required String content,
    int count = 5,
    String difficulty = 'Trung bình',
  }) async {
    final prompt = '''
Bạn là giảng viên đại học. Hãy tạo $count câu hỏi trắc nghiệm ôn tập (Active Recall) sát với nội dung bài học dưới đây ở mức độ: $difficulty.
- Nếu là Dễ (Nhận biết): Tập trung vào định nghĩa, thuật ngữ, sự kiện và khái niệm cốt lõi.
- Nếu là Trung bình (Thông hiểu): Yêu cầu liên hệ, phân biệt khái niệm, áp dụng công thức hoặc giải thích nguyên lý.
- Nếu là Khó (Vận dụng cao): Đưa ra tình huống thực tế, bài toán suy luận logic hoặc phân tích trường hợp chuyên sâu.

Nội dung bài học / slide:
"""
$content
"""

Yêu cầu xuất ra MẢNG JSON DUY NHẤT theo mẫu sau (không kèm lời dẫn ngoài JSON):
[
  {
    "question": "Nội dung câu hỏi?",
    "options": ["Lựa chọn A", "Lựa chọn B", "Lựa chọn C", "Lựa chọn D"],
    "correctOptionIndex": 0,
    "explanation": "Giải thích ngắn gọn lý do vì sao đáp án này đúng."
  }
]
''';

    final responseText = await remoteDataSource.generateContent(prompt: prompt);
    final cleanedJson = _extractJsonText(responseText);

    try {
      final List<dynamic> list = jsonDecode(cleanedJson) as List<dynamic>;
      final questions = <AiQuizQuestion>[];

      for (var i = 0; i < list.length; i++) {
        final item = list[i] as Map<String, dynamic>;
        final rawOptions = item['options'] as List<dynamic>? ?? [];
        final options = rawOptions.map((e) => e.toString()).toList();
        final correctIdx = item['correctOptionIndex'] as int? ?? 0;

        questions.add(
          AiQuizQuestion(
            id: const Uuid().v4(),
            question: item['question'] as String? ?? 'Câu hỏi ${i + 1}',
            options: options,
            correctOptionIndex: (correctIdx >= 0 && correctIdx < options.length)
                ? correctIdx
                : 0,
            explanation: item['explanation'] as String? ?? '',
          ),
        );
      }

      if (questions.isNotEmpty) {
        return questions;
      }
      throw Exception('Không có câu hỏi nào được sinh ra.');
    } catch (e) {
      if (e is Exception && e.toString().contains('Không có câu hỏi')) {
        rethrow;
      }
      throw Exception('Không thể phân tích định dạng câu hỏi từ AI. Vui lòng thử lại.');
    }
  }

  /// Làm sạch phản hồi từ AI nếu bị bọc trong khối markdown ```json ... ```
  String _extractJsonText(String raw) {
    var text = raw.trim();
    if (text.startsWith('```json')) {
      text = text.substring(7);
    } else if (text.startsWith('```')) {
      text = text.substring(3);
    }
    if (text.endsWith('```')) {
      text = text.substring(0, text.length - 3);
    }
    return text.trim();
  }
}
