import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:nhom_7/features/notes/data/repositories/hive_note_repository.dart';
import 'package:nhom_7/features/notes/domain/entities/lecture_note.dart';

void main() {
  late Directory tempDir;
  late Box<Map> box;
  late HiveNoteRepository repository;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync();
    Hive.init(tempDir.path);
    box = await Hive.openBox<Map>('test_notes_box_${DateTime.now().microsecondsSinceEpoch}');
    repository = HiveNoteRepository(box: box);
  });

  tearDown(() async {
    await box.close();
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('HiveNoteRepository Unit Tests (Local-First Persistence)', () {
    final testNote = LectureNote(
      id: 'test_note_1',
      subjectId: 'sub_flutter',
      title: 'Học Clean Architecture',
      bodyText: 'Nội dung chi tiết ghi chú...',
      videoPaths: const ['/path/to/video1.mp4', '/path/to/video2.mp4'],
      imagePaths: const ['/path/to/image1.jpg'],
      location: 'Phòng B204',
      createdAt: DateTime(2026, 10, 18, 10, 0),
      updatedAt: DateTime(2026, 10, 18, 10, 30),
    );

    test('saveNote saves note into physical Hive box and getNoteById retrieves it', () async {
      await repository.saveNote(testNote);

      final retrieved = await repository.getNoteById(testNote.id);

      expect(retrieved, isNotNull);
      expect(retrieved!.id, equals(testNote.id));
      expect(retrieved.title, equals('Học Clean Architecture'));
      expect(retrieved.bodyText, equals('Nội dung chi tiết ghi chú...'));
      expect(retrieved.videoPaths, equals(['/path/to/video1.mp4', '/path/to/video2.mp4']));
      expect(retrieved.imagePaths, equals(['/path/to/image1.jpg']));
      expect(retrieved.location, equals('Phòng B204'));
    });

    test('getAllNotes returns active notes sorted by updatedAt descending', () async {
      final noteOlder = testNote.copyWith(
        id: 'note_older',
        updatedAt: DateTime(2026, 10, 17, 8, 0),
      );
      final noteNewer = testNote.copyWith(
        id: 'note_newer',
        updatedAt: DateTime(2026, 10, 18, 12, 0),
      );

      await repository.saveNote(noteOlder);
      await repository.saveNote(noteNewer);

      final all = await repository.getAllNotes();

      expect(all.length, equals(2));
      expect(all.first.id, equals('note_newer'));
      expect(all.last.id, equals('note_older'));
    });

    test('deleteNote soft-deletes the note so it is excluded from getNoteById and getAllNotes', () async {
      await repository.saveNote(testNote);

      await repository.deleteNote(testNote.id);

      final single = await repository.getNoteById(testNote.id);
      final all = await repository.getAllNotes();

      expect(single, isNull);
      expect(all.where((n) => n.id == testNote.id), isEmpty);
    });

    test('watchAllNotes emits updated notes reactively', () async {
      final stream = repository.watchAllNotes();

      expectLater(
        stream,
        emitsInOrder([
          isEmpty,
          predicate<List<LectureNote>>((list) => list.length == 1 && list.first.id == testNote.id),
        ]),
      );

      await Future.delayed(const Duration(milliseconds: 50));
      await repository.saveNote(testNote);
    });

    test('persistence across app restart: re-opening the box retains stored notes 100%', () async {
      final boxName = box.name;
      await repository.saveNote(testNote);

      // Giả lập tắt app và đóng box
      await box.close();

      // Giả lập mở lại app từ cùng thư mục lưu trữ
      final reOpenedBox = await Hive.openBox<Map>(boxName);
      final reOpenedRepo = HiveNoteRepository(box: reOpenedBox);

      final retrieved = await reOpenedRepo.getNoteById(testNote.id);
      expect(retrieved, isNotNull);
      expect(retrieved!.id, equals(testNote.id));
      expect(retrieved.title, equals(testNote.title));
      expect(retrieved.location, equals('Phòng B204'));

      await reOpenedBox.close();
    });
  });
}
