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

    testWidgets('tapping save button saves note with updated title and body into repository',
        (tester) async {
      await tester.pumpWidget(buildTestHarness(noteId: 'test-note-save'));
      await tester.pumpAndSettle();

      // Enter title and body
      await tester.enterText(find.byType(TextField).first, 'Ghi chu tieu de');
      await tester.enterText(find.byType(TextField).last, 'Ghi chu noi dung');
      await tester.pump();

      // Tap Save
      await tester.tap(find.byIcon(Icons.save_outlined));
      await tester.pumpAndSettle();

      final savedNote = await repository.getNoteById('test-note-save');
      expect(savedNote, isNotNull);
      expect(savedNote!.title, 'Ghi chu tieu de');
      expect(savedNote.bodyText, 'Ghi chu noi dung');
    });

    testWidgets('back button automatically saves unsaved changes to repository',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => TextButton(
                onPressed: () {
                  Navigator.of(ctx).push(
                    MaterialPageRoute(
                      builder: (_) => const NoteEditorPage(noteId: 'test-note-back'),
                    ),
                  );
                },
                child: const Text('Open Editor'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Editor'));
      await tester.pumpAndSettle();

      // Enter title and body
      await tester.enterText(find.byType(TextField).first, 'Tieu de moi');
      await tester.enterText(find.byType(TextField).last, 'Noi dung moi');
      await tester.pump();

      // Tap Back button
      await tester.tap(find.byType(BackButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      // Verify note was saved in repository
      final savedNote = await repository.getNoteById('test-note-back');
      expect(savedNote, isNotNull);
      expect(savedNote!.title, 'Tieu de moi');
      expect(savedNote.bodyText, 'Noi dung moi');
    });

    testWidgets('renders action chips (Thêm ảnh, Vẽ tay) when note has no images',
        (tester) async {
      await tester.pumpWidget(buildTestHarness(noteId: 'test-note-actions'));
      await tester.pumpAndSettle();

      expect(find.text('Thêm ảnh'), findsOneWidget);
      expect(find.text('Vẽ tay'), findsOneWidget);
      expect(find.text(AppStrings.canvasAttachmentTitle), findsNothing);
      expect(find.byKey(const ValueKey('note_title_field')), findsOneWidget);
      expect(find.byKey(const ValueKey('note_content_field')), findsOneWidget);
    });

    testWidgets('renders horizontal image tray and handles remove image when note has images',
        (tester) async {
      final noteWithImages = LectureNote(
        id: 'test-note-images',
        subjectId: 'CS101',
        title: 'Ghi chú có ảnh',
        bodyText: 'Nội dung',
        imagePaths: ['test_image_1.png'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await repository.saveNote(noteWithImages);

      await tester.pumpWidget(buildTestHarness(noteId: 'test-note-images'));
      await tester.pumpAndSettle();

      // Action chips remain accessible
      expect(find.text('Thêm ảnh'), findsWidgets);
      expect(find.text('Vẽ tay'), findsOneWidget);

      // Verify close icon for removing image is present
      final closeFinder = find.byIcon(Icons.close);
      expect(closeFinder, findsOneWidget);

      // Tap close icon to remove image
      await tester.tap(closeFinder);
      await tester.pumpAndSettle();

      // Image should be removed and action chips still present
      expect(find.text('Vẽ tay'), findsOneWidget);
    });

    testWidgets('renders subject chip and does not show location chip',
        (tester) async {
      await tester.pumpWidget(buildTestHarness(noteId: 'test-note-subj-check'));
      await tester.pumpAndSettle();

      expect(find.text('Chọn môn'), findsOneWidget);
      expect(find.text('📍 Vị trí'), findsNothing);
    });

    testWidgets(
        'renders video action chip and does not show bulky video card when note has no video',
        (tester) async {
      await tester.pumpWidget(buildTestHarness(noteId: 'test-note-no-video'));
      await tester.pumpAndSettle();

      expect(find.text('Thêm video'), findsOneWidget);
      expect(find.text(AppStrings.videoAttach), findsNothing);
    });
  });
}
