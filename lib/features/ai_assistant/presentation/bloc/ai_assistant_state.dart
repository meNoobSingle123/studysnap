import 'package:equatable/equatable.dart';

import '../../domain/entities/ai_quiz_question.dart';
import '../../domain/entities/ai_summary_result.dart';

abstract class AiAssistantState extends Equatable {
  const AiAssistantState();

  @override
  List<Object?> get props => [];
}

class AiAssistantInitial extends AiAssistantState {
  const AiAssistantInitial();
}

class AiAssistantLoading extends AiAssistantState {
  final String message;
  const AiAssistantLoading(this.message);

  @override
  List<Object?> get props => [message];
}

class AiAssistantNeedsApiKey extends AiAssistantState {
  final String? existingKey;
  const AiAssistantNeedsApiKey({this.existingKey});

  @override
  List<Object?> get props => [existingKey];
}

class AiAssistantSummarySuccess extends AiAssistantState {
  final AiSummaryResult summary;

  const AiAssistantSummarySuccess({required this.summary});

  @override
  List<Object?> get props => [summary];
}

class AiAssistantQuizSuccess extends AiAssistantState {
  final List<AiQuizQuestion> questions;
  final Map<String, int> userAnswers; // questionId -> selectedIndex
  final bool showExplanations;

  const AiAssistantQuizSuccess({
    required this.questions,
    this.userAnswers = const {},
    this.showExplanations = false,
  });

  int get correctCount {
    var count = 0;
    for (final q in questions) {
      if (userAnswers[q.id] == q.correctOptionIndex) {
        count++;
      }
    }
    return count;
  }

  AiAssistantQuizSuccess copyWith({
    List<AiQuizQuestion>? questions,
    Map<String, int>? userAnswers,
    bool? showExplanations,
  }) {
    return AiAssistantQuizSuccess(
      questions: questions ?? this.questions,
      userAnswers: userAnswers ?? this.userAnswers,
      showExplanations: showExplanations ?? this.showExplanations,
    );
  }

  @override
  List<Object?> get props => [questions, userAnswers, showExplanations];
}

class AiAssistantFailure extends AiAssistantState {
  final String errorMessage;
  final bool isApiKeyError;

  const AiAssistantFailure({
    required this.errorMessage,
    this.isApiKeyError = false,
  });

  @override
  List<Object?> get props => [errorMessage, isApiKeyError];
}

