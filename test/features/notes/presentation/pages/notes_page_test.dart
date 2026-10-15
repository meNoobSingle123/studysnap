import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:nhom_7/core/l10n/strings.dart';
import 'package:nhom_7/features/notes/data/repositories/in_memory_note_repository.dart';
import 'package:nhom_7/features/notes/domain/entities/lecture_note.dart';
import 'package:nhom_7/features/notes/domain/repositories/note_repository.dart';
import 'package:nhom_7/features/notes/presentation/pages/notes_page.dart';

void main() {
  late InMemoryNoteRepository repository;

  setUp(() {
    repository = InMemoryNoteRepository();
    final getIt = GetIt.instance;
    if (!getIt.isRegistered<NoteRepository>()) {
      getIt.registerSingleton<NoteRepository>(repository);
    }
  });

  tearDown(() {
    GetIt.instance.reset();
  });

  Widget buildTestableWidget({InMemoryNoteRepository? customRepo}) {
    return MaterialApp(
      home: NotesPage(repository: customRepo ?? repository),
    );
  }

  group('NotesPage Widget Tests', () {
    testWidgets('renders empty state when there are no notes', (tester) async {
      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.notesTab), findsOneWidget);
      expect(find.text(AppStrings.emptyNotesList), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsOneWidget);
    });

    testWidgets('renders note cards with title, snippet, and timestamp',
        (tester) async {
      final now = DateTime(2026, 10, 15, 14, 30);
      final note1 = LectureNote(
        id: 'note-1',
        subjectId: 'CS101',
        title: 'Nhập môn Lập trình',
        bodyText: 'Hôm nay học cấu trúc rẽ nhánh if else',
        createdAt: now,
        updatedAt: now,
      );
      final note2 = LectureNote(
        id: 'note-2',
        subjectId: 'MATH101',
        title: 'Giải tích 1',
        bodyText: 'Đạo hàm và tích phân cơ bản',
        videoPath: 'math_video.mp4',
        createdAt: now,
        updatedAt: now,
      );
      await repository.saveNote(note1);
      await repository.saveNote(note2);

      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      // Verify note cards
      expect(find.text('Nhập môn Lập trình'), findsOneWidget);
      expect(find.text('Hôm nay học cấu trúc rẽ nhánh if else'), findsOneWidget);
      expect(find.text('CS101'), findsOneWidget);

      expect(find.text('Giải tích 1'), findsOneWidget);
      expect(find.text('Đạo hàm và tích phân cơ bản'), findsOneWidget);
      expect(find.text('MATH101'), findsOneWidget);
      expect(find.byIcon(Icons.videocam_outlined), findsOneWidget);

      expect(find.text(AppStrings.emptyNotesList), findsNothing);
    });
  });
}
