import '../entities/ai_quiz_question.dart';
import '../entities/ai_summary_result.dart';

/// Hợp đồng Repository cho các tính năng Trợ lý AI học tập.
abstract class AiAssistantRepository {
  /// Tóm tắt nội dung bài học thành văn bản súc tích và danh sách ý chính.
  Future<AiSummaryResult> summarizeNote({
    required String title,
    required String content,
    String? subjectName,
  });

  /// Sinh danh sách câu hỏi trắc nghiệm ôn tập (Active Recall) từ nội dung bài học.
  Future<List<AiQuizQuestion>> generateQuiz({
    required String title,
    required String content,
    int count = 5,
    String difficulty = 'Trung bình',
  });

  /// Kiểm tra xem API Key đã sẵn sàng chưa (qua env hoặc lưu trữ an toàn).
  Future<bool> hasApiKey();

  /// Lưu API Key do người dùng nhập vào bộ nhớ an toàn (Keystore/Keychain).
  Future<void> saveApiKey(String apiKey);

  /// Lấy API Key hiện tại (nếu có).
  Future<String?> getApiKey();
}

