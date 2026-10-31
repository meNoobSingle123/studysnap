import '../entities/ai_quiz_question.dart';
import '../repositories/ai_assistant_repository.dart';

/// UseCase: Yêu cầu AI tạo câu hỏi trắc nghiệm ôn tập từ nội dung bài học.
class GenerateQuizUseCase {
  final AiAssistantRepository repository;

  const GenerateQuizUseCase(this.repository);

  Future<List<AiQuizQuestion>> call({
    required String title,
    required String content,
    int count = 5,
    String difficulty = 'Trung bình',
  }) async {
    final trimmed = content.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Nội dung bài học không được để trống khi sinh câu hỏi');
    }
    return repository.generateQuiz(
      title: title,
      content: trimmed,
      count: count,
      difficulty: difficulty,
    );
  }
}

