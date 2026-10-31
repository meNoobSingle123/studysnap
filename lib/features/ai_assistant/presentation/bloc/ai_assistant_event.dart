import 'package:equatable/equatable.dart';

abstract class AiAssistantEvent extends Equatable {
  const AiAssistantEvent();

  @override
  List<Object?> get props => [];
}

class CheckApiKeyStatus extends AiAssistantEvent {
  const CheckApiKeyStatus();
}

class SaveApiKeyRequested extends AiAssistantEvent {
  final String apiKey;
  const SaveApiKeyRequested(this.apiKey);

  @override
  List<Object?> get props => [apiKey];
}

class SummarizeNoteRequested extends AiAssistantEvent {
  final String title;
  final String content;
  final String? subjectName;

  const SummarizeNoteRequested({
    required this.title,
    required this.content,
    this.subjectName,
  });

  @override
  List<Object?> get props => [title, content, subjectName];
}

class GenerateQuizRequested extends AiAssistantEvent {
  final String title;
  final String content;
  final int count;
  final String difficulty;

  const GenerateQuizRequested({
    required this.title,
    required this.content,
    this.count = 5,
    this.difficulty = 'Trung bình',
  });

  @override
  List<Object?> get props => [title, content, count, difficulty];
}

class AnswerSelected extends AiAssistantEvent {
  final String questionId;
  final int selectedIndex;

  const AnswerSelected({
    required this.questionId,
    required this.selectedIndex,
  });

  @override
  List<Object?> get props => [questionId, selectedIndex];
}

class ToggleShowExplanations extends AiAssistantEvent {
  const ToggleShowExplanations();
}

