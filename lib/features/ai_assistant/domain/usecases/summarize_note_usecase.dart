import '../entities/ai_summary_result.dart';
import '../repositories/ai_assistant_repository.dart';

/// UseCase: Yêu cầu AI tóm tắt nội dung bài học.
class SummarizeNoteUseCase {
  final AiAssistantRepository repository;

  const SummarizeNoteUseCase(this.repository);

  Future<AiSummaryResult> call({
    required String title,
    required String content,
    String? subjectName,
  }) async {
    final trimmed = content.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Nội dung bài học không được để trống khi tóm tắt');
    }
    return repository.summarizeNote(
      title: title,
      content: trimmed,
      subjectName: subjectName,
    );
  }
}

