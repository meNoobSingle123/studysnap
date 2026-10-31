import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nhom_7/features/ai_assistant/domain/entities/ai_quiz_question.dart';
import 'package:nhom_7/features/ai_assistant/domain/entities/ai_summary_result.dart';
import 'package:nhom_7/features/ai_assistant/domain/repositories/ai_assistant_repository.dart';
import 'package:nhom_7/features/ai_assistant/domain/usecases/generate_quiz_usecase.dart';
import 'package:nhom_7/features/ai_assistant/domain/usecases/summarize_note_usecase.dart';
import 'package:nhom_7/features/ai_assistant/presentation/bloc/ai_assistant_bloc.dart';
import 'package:nhom_7/features/ai_assistant/presentation/bloc/ai_assistant_event.dart';
import 'package:nhom_7/features/ai_assistant/presentation/bloc/ai_assistant_state.dart';

class MockSummarizeNoteUseCase extends Mock implements SummarizeNoteUseCase {}
class MockGenerateQuizUseCase extends Mock implements GenerateQuizUseCase {}
class MockAiAssistantRepository extends Mock implements AiAssistantRepository {}

void main() {
  late MockSummarizeNoteUseCase mockSummarizeUseCase;
  late MockGenerateQuizUseCase mockGenerateQuizUseCase;
  late MockAiAssistantRepository mockRepository;
  late AiAssistantBloc bloc;

  setUp(() {
    mockSummarizeUseCase = MockSummarizeNoteUseCase();
    mockGenerateQuizUseCase = MockGenerateQuizUseCase();
    mockRepository = MockAiAssistantRepository();

    bloc = AiAssistantBloc(
      summarizeNoteUseCase: mockSummarizeUseCase,
      generateQuizUseCase: mockGenerateQuizUseCase,
      repository: mockRepository,
    );
  });

  tearDown(() {
    bloc.close();
  });

  const sampleSummary = AiSummaryResult(
    title: 'Tóm tắt bài học',
    summary: 'Tổng quan bài giảng',
    keyPoints: ['Ý 1', 'Ý 2'],
    practicalTakeaways: ['Mẹo 1'],
  );

  const sampleQuestions = [
    AiQuizQuestion(
      id: 'q-1',
      question: 'Flutter dùng ngôn ngữ gì?',
      options: ['Dart', 'Kotlin', 'Java', 'Swift'],
      correctOptionIndex: 0,
      explanation: 'Flutter sử dụng ngôn ngữ Dart.',
    ),
  ];

  group('AiAssistantBloc Tests', () {
    test('initial state is AiAssistantInitial', () {
      expect(bloc.state, equals(const AiAssistantInitial()));
    });

    blocTest<AiAssistantBloc, AiAssistantState>(
      'emits [AiAssistantNeedsApiKey] when API key is missing',
      build: () {
        when(() => mockRepository.hasApiKey()).thenAnswer((_) async => false);
        when(() => mockRepository.getApiKey()).thenAnswer((_) async => null);
        return bloc;
      },
      act: (bloc) => bloc.add(const CheckApiKeyStatus()),
      expect: () => [
        const AiAssistantNeedsApiKey(existingKey: null),
      ],
    );

    blocTest<AiAssistantBloc, AiAssistantState>(
      'saves API key and resets to AiAssistantInitial',
      build: () {
        when(() => mockRepository.saveApiKey(any())).thenAnswer((_) async {});
        return bloc;
      },
      act: (bloc) => bloc.add(const SaveApiKeyRequested('my-test-key-123')),
      expect: () => [
        const AiAssistantInitial(),
      ],
      verify: (_) {
        verify(() => mockRepository.saveApiKey('my-test-key-123')).called(1);
      },
    );

    blocTest<AiAssistantBloc, AiAssistantState>(
      'emits [AiAssistantLoading, AiAssistantSummarySuccess] when summarize succeeds',
      build: () {
        when(() => mockRepository.hasApiKey()).thenAnswer((_) async => true);
        when(() => mockSummarizeUseCase(
              title: any(named: 'title'),
              content: any(named: 'content'),
              subjectName: any(named: 'subjectName'),
            )).thenAnswer((_) async => sampleSummary);
        return bloc;
      },
      act: (bloc) => bloc.add(const SummarizeNoteRequested(
        title: 'Lập trình di động',
        content: 'Nội dung bài học',
      )),
      expect: () => [
        const AiAssistantLoading('Trợ lý AI đang đọc và tóm tắt bài giảng...'),
        const AiAssistantSummarySuccess(summary: sampleSummary),
      ],
    );

    blocTest<AiAssistantBloc, AiAssistantState>(
      'emits [AiAssistantLoading, AiAssistantQuizSuccess] when quiz generation succeeds',
      build: () {
        when(() => mockRepository.hasApiKey()).thenAnswer((_) async => true);
        when(() => mockGenerateQuizUseCase(
              title: any(named: 'title'),
              content: any(named: 'content'),
              count: any(named: 'count'),
              difficulty: any(named: 'difficulty'),
            )).thenAnswer((_) async => sampleQuestions);
        return bloc;
      },
      act: (bloc) => bloc.add(const GenerateQuizRequested(
        title: 'Lập trình di động',
        content: 'Nội dung bài học',
      )),
      expect: () => [
        const AiAssistantLoading('Trợ lý AI đang sinh câu hỏi trắc nghiệm ôn tập...'),
        const AiAssistantQuizSuccess(questions: sampleQuestions),
      ],
    );

    blocTest<AiAssistantBloc, AiAssistantState>(
      'updates userAnswers when AnswerSelected event is triggered',
      build: () => bloc,
      seed: () => const AiAssistantQuizSuccess(questions: sampleQuestions),
      act: (bloc) => bloc.add(const AnswerSelected(questionId: 'q-1', selectedIndex: 0)),
      expect: () => [
        const AiAssistantQuizSuccess(
          questions: sampleQuestions,
          userAnswers: {'q-1': 0},
        ),
      ],
    );
  });
}

