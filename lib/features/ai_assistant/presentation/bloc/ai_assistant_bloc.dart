import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/repositories/ai_assistant_repository.dart';
import '../../domain/usecases/generate_quiz_usecase.dart';
import '../../domain/usecases/summarize_note_usecase.dart';
import 'ai_assistant_event.dart';
import 'ai_assistant_state.dart';

class AiAssistantBloc extends Bloc<AiAssistantEvent, AiAssistantState> {
  final SummarizeNoteUseCase summarizeNoteUseCase;
  final GenerateQuizUseCase generateQuizUseCase;
  final AiAssistantRepository repository;

  AiAssistantBloc({
    required this.summarizeNoteUseCase,
    required this.generateQuizUseCase,
    required this.repository,
  }) : super(const AiAssistantInitial()) {
    on<CheckApiKeyStatus>(_onCheckApiKey);
    on<SaveApiKeyRequested>(_onSaveApiKey);
    on<SummarizeNoteRequested>(_onSummarizeNote);
    on<GenerateQuizRequested>(_onGenerateQuiz);
    on<AnswerSelected>(_onAnswerSelected);
    on<ToggleShowExplanations>(_onToggleExplanations);
  }

  Future<void> _onCheckApiKey(
    CheckApiKeyStatus event,
    Emitter<AiAssistantState> emit,
  ) async {
    final hasKey = await repository.hasApiKey();
    if (!hasKey) {
      final key = await repository.getApiKey();
      emit(AiAssistantNeedsApiKey(existingKey: key));
    }
  }

  Future<void> _onSaveApiKey(
    SaveApiKeyRequested event,
    Emitter<AiAssistantState> emit,
  ) async {
    final key = event.apiKey.trim();
    if (key.isEmpty) {
      emit(const AiAssistantFailure(
        errorMessage: 'Vui lòng nhập API Key hợp lệ',
        isApiKeyError: true,
      ));
      return;
    }
    await repository.saveApiKey(key);
    emit(const AiAssistantInitial());
  }

  Future<void> _onSummarizeNote(
    SummarizeNoteRequested event,
    Emitter<AiAssistantState> emit,
  ) async {
    final hasKey = await repository.hasApiKey();
    if (!hasKey) {
      emit(const AiAssistantNeedsApiKey());
      return;
    }

    emit(const AiAssistantLoading('Trợ lý AI đang đọc và tóm tắt bài giảng...'));
    try {
      final summary = await summarizeNoteUseCase(
        title: event.title,
        content: event.content,
        subjectName: event.subjectName,
      );
      emit(AiAssistantSummarySuccess(summary: summary));
    } catch (e) {
      final msg = e.toString().replaceAll('Exception:', '').trim();
      final isKeyErr = msg.contains('API Key') || msg.contains('hết hạn');
      emit(AiAssistantFailure(errorMessage: msg, isApiKeyError: isKeyErr));
    }
  }

  Future<void> _onGenerateQuiz(
    GenerateQuizRequested event,
    Emitter<AiAssistantState> emit,
  ) async {
    final hasKey = await repository.hasApiKey();
    if (!hasKey) {
      emit(const AiAssistantNeedsApiKey());
      return;
    }

    emit(const AiAssistantLoading('Trợ lý AI đang sinh câu hỏi trắc nghiệm ôn tập...'));
    try {
      final questions = await generateQuizUseCase(
        title: event.title,
        content: event.content,
        count: event.count,
        difficulty: event.difficulty,
      );
      emit(AiAssistantQuizSuccess(questions: questions));
    } catch (e) {
      final msg = e.toString().replaceAll('Exception:', '').trim();
      final isKeyErr = msg.contains('API Key') || msg.contains('hết hạn');
      emit(AiAssistantFailure(errorMessage: msg, isApiKeyError: isKeyErr));
    }
  }

  void _onAnswerSelected(
    AnswerSelected event,
    Emitter<AiAssistantState> emit,
  ) {
    final current = state;
    if (current is! AiAssistantQuizSuccess) return;

    final updatedAnswers = Map<String, int>.from(current.userAnswers);
    updatedAnswers[event.questionId] = event.selectedIndex;

    emit(current.copyWith(userAnswers: updatedAnswers));
  }

  void _onToggleExplanations(
    ToggleShowExplanations event,
    Emitter<AiAssistantState> emit,
  ) {
    final current = state;
    if (current is! AiAssistantQuizSuccess) return;

    emit(current.copyWith(showExplanations: !current.showExplanations));
  }
}

