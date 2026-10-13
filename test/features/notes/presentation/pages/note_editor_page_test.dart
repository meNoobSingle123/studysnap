import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:nhom_7/core/l10n/strings.dart';
import 'package:nhom_7/features/notes/data/repositories/in_memory_note_repository.dart';
import 'package:nhom_7/features/notes/domain/entities/lecture_note.dart';
import 'package:nhom_7/features/notes/domain/usecases/get_note_by_id_usecase.dart';
import 'package:nhom_7/features/notes/domain/usecases/save_note_usecase.dart';
import 'package:nhom_7/features/notes/presentation/bloc/note_editor_bloc.dart';
import 'package:nhom_7/features/notes/presentation/pages/note_editor_page.dart';
import 'package:nhom_7/features/notes/presentation/widgets/media/lecture_video_player.dart';

void main() {
  late InMemoryNoteRepository repository;

  setUp(() {
    repository = InMemoryNoteRepository();
    final getIt = GetIt.instance;
    if (!getIt.isRegistered<NoteEditorBloc>()) {
      getIt.registerFactory<NoteEditorBloc>(
        () => NoteEditorBloc(
          getNoteByIdUseCase: GetNoteByIdUseCase(repository),
          saveNoteUseCase: SaveNoteUseCase(repository),
        ),
      );
    }
  });

  tearDown(() {
    GetIt.instance.reset();
  });

  Widget buildTestHarness({
    String noteId = 'test-note-1',
    double bottomInset = 0.0,
  }) {
    return MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: const Size(400, 800),
          viewInsets: EdgeInsets.only(bottom: bottomInset),
        ),
        child: NoteEditorPage(noteId: noteId),
      ),
    );
  }

  group('NoteEditorPage S06 Split-View & Mini-Player', () {
    testWidgets('renders Split-View video player when note has video and keyboard is closed',
        (tester) async {
      final noteWithVideo = LectureNote(
        id: 'test-note-video',
        subjectId: 'CS101',
        title: 'Buổi 1: Giới thiệu',
        bodyText: 'Nội dung [01:30] bắt đầu phần 1',
        videoPath: 'sample_video.mp4',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await repository.saveNote(noteWithVideo);

      await tester.pumpWidget(buildTestHarness(noteId: 'test-note-video'));
      await tester.pumpAndSettle();

      // Video player in standard Split-View
      expect(find.byType(LectureVideoPlayer), findsOneWidget);
      expect(find.text(AppStrings.videoTimestampButton), findsOneWidget);
      expect(find.text('[01:30]'), findsOneWidget);
    });

    testWidgets('switches to floating Mini-Player without overflow when keyboard opens',
        (tester) async {
      final noteWithVideo = LectureNote(
        id: 'test-note-video-kb',
        subjectId: 'CS101',
        title: 'Buổi 2: Thuật toán',
        bodyText: 'Lý thuyết [02:15]',
        videoPath: 'sample_video.mp4',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await repository.saveNote(noteWithVideo);

      // Simulate keyboard open with 320dp height
      await tester.pumpWidget(
        buildTestHarness(noteId: 'test-note-video-kb', bottomInset: 320.0),
      );
      await tester.pumpAndSettle();

      // Find the Mini-Player in Positioned stack
      final miniPlayerFinder = find.byWidgetPredicate(
        (widget) => widget is LectureVideoPlayer && widget.isMini == true,
      );
      expect(miniPlayerFinder, findsOneWidget);

      // Quick timestamp button is visible in keyboard mode
      expect(find.text(AppStrings.videoTimestampButton), findsOneWidget);

      // Verify no RenderFlex overflow exception was logged
      expect(tester.takeException(), isNull);
    });

    testWidgets('tapping timestamp button inserts [mm:ss] token into editor',
        (tester) async {
      final noteWithVideo = LectureNote(
        id: 'test-note-ts',
        subjectId: 'CS101',
        title: 'Buổi 3',
        bodyText: 'Ghi chú bài học: ',
        videoPath: 'sample.mp4',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await repository.saveNote(noteWithVideo);

      await tester.pumpWidget(buildTestHarness(noteId: 'test-note-ts'));
      await tester.pumpAndSettle();

      // Tap "Gắn mốc"
      await tester.tap(find.text(AppStrings.videoTimestampButton).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Body text should now contain [00:00] (initial position)
      expect(find.textContaining('[00:00]'), findsWidgets);
    });
  });
}
