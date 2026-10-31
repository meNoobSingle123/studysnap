import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nhom_7/features/ai_assistant/domain/entities/ai_quiz_question.dart';
import 'package:nhom_7/features/ai_assistant/domain/entities/ai_summary_result.dart';
import 'package:nhom_7/features/ai_assistant/domain/repositories/ai_assistant_repository.dart';
import 'package:nhom_7/features/ai_assistant/domain/usecases/generate_quiz_usecase.dart';
import 'package:nhom_7/features/ai_assistant/domain/usecases/summarize_note_usecase.dart';

class MockAiAssistantRepository extends Mock implements AiAssistantRepository {}

void main() {
  late MockAiAssistantRepository mockRepository;
  late SummarizeNoteUseCase summarizeUseCase;
  late GenerateQuizUseCase generateQuizUseCase;

  setUp(() {
    mockRepository = MockAiAssistantRepository();
    summarizeUseCase = SummarizeNoteUseCase(mockRepository);
    generateQuizUseCase = GenerateQuizUseCase(mockRepository);
  });

  group('SummarizeNoteUseCase Tests', () {
    const sampleSummary = AiSummaryResult(
      title: 'Tóm tắt bài học',
      summary: 'Nội dung cốt lõi của bài giảng về Flutter BLoC.',
      keyPoints: ['BLoC tách biệt UI và logic', 'Sử dụng Stream'],
      practicalTakeaways: ['Không gọi setState trong BLoC'],
    );

    test('throws ArgumentError when content is empty or whitespace only', () async {
      expect(
        () => summarizeUseCase(title: 'Bài 1', content: '   '),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('calls repository.summarizeNote and returns AiSummaryResult on success', () async {
      when(() => mockRepository.summarizeNote(
            title: 'Bài 1',
            content: 'Nội dung bài học Flutter',
            subjectName: 'Lập trình di động',
          )).thenAnswer((_) async => sampleSummary);

      final result = await summarizeUseCase(
        title: 'Bài 1',
        content: 'Nội dung bài học Flutter',
        subjectName: 'Lập trình di động',
      );

      expect(result, equals(sampleSummary));
      expect(result.toMarkdown(), contains('### 🤖 Tóm tắt thông minh'));
      verify(() => mockRepository.summarizeNote(
            title: 'Bài 1',
            content: 'Nội dung bài học Flutter',
            subjectName: 'Lập trình di động',
          )).called(1);
    });
  });

  group('GenerateQuizUseCase Tests', () {
    const sampleQuestions = [
      AiQuizQuestion(
        id: 'q-1',
        question: 'BLoC viết tắt của từ gì?',
        options: [
          'Business Logic Component',
          'Basic Logic Class',
          'Build Layout Controller',
          'Binary Logic Code'
        ],
        correctOptionIndex: 0,
        explanation: 'BLoC là viết tắt của Business Logic Component.',
      ),
    ];

    test('throws ArgumentError when content is empty or whitespace only', () async {
      expect(
        () => generateQuizUseCase(title: 'Bài 1', content: ''),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('calls repository.generateQuiz and returns list of questions', () async {
      when(() => mockRepository.generateQuiz(
            title: 'Bài 1',
            content: 'Kiến thức BLoC Flutter',
            count: 4,
          )).thenAnswer((_) async => sampleQuestions);

      final result = await generateQuizUseCase(
        title: 'Bài 1',
        content: 'Kiến thức BLoC Flutter',
        count: 4,
      );

      expect(result, equals(sampleQuestions));
      expect(result.first.correctOptionIndex, 0);
      verify(() => mockRepository.generateQuiz(
            title: 'Bài 1',
            content: 'Kiến thức BLoC Flutter',
            count: 4,
          )).called(1);
    });

    test('calls repository.generateQuiz with customized count and difficulty level', () async {
      when(() => mockRepository.generateQuiz(
            title: 'Slide 1 - Kiến trúc Clean',
            content: 'Nội dung slide bài giảng chi tiết',
            count: 10,
            difficulty: 'Khó',
          )).thenAnswer((_) async => sampleQuestions);

      final result = await generateQuizUseCase(
        title: 'Slide 1 - Kiến trúc Clean',
        content: 'Nội dung slide bài giảng chi tiết',
        count: 10,
        difficulty: 'Khó',
      );

      expect(result, equals(sampleQuestions));
      verify(() => mockRepository.generateQuiz(
            title: 'Slide 1 - Kiến trúc Clean',
            content: 'Nội dung slide bài giảng chi tiết',
            count: 10,
            difficulty: 'Khó',
          )).called(1);
    });
  });
}

