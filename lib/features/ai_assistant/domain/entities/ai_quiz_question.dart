import 'package:equatable/equatable.dart';

/// Một câu hỏi trắc nghiệm ôn tập do AI sinh ra từ bài giảng.
class AiQuizQuestion extends Equatable {
  final String id;
  final String question;
  final List<String> options;
  final int correctOptionIndex;
  final String explanation;

  const AiQuizQuestion({
    required this.id,
    required this.question,
    required this.options,
    required this.correctOptionIndex,
    required this.explanation,
  });

  @override
  List<Object?> get props => [
        id,
        question,
        options,
        correctOptionIndex,
        explanation,
      ];
}

