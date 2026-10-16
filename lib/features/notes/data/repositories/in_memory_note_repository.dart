import 'dart:async';

import '../../domain/entities/lecture_note.dart';
import '../../domain/repositories/note_repository.dart';

/// In-memory implementation of NoteRepository.
/// Stores notes temporarily in RAM with reactive broadcast stream.
class InMemoryNoteRepository implements NoteRepository {
  final Map<String, LectureNote> _storage = {};
  final StreamController<List<LectureNote>> _controller =
      StreamController<List<LectureNote>>.broadcast();

  InMemoryNoteRepository({bool seedMockData = false}) {
    if (seedMockData) {
      seedSampleNotes();
    }
  }

  /// Populates standard demo notes covering subjects and timetable slots.
  void seedSampleNotes() {
    final now = DateTime.now();
    final sampleNotes = [
      LectureNote(
        id: 'note_demo_1',
        subjectId: 'sub_flutter',
        slotId: 'slot_mon_m1',
        title: 'Kiến trúc Clean Architecture & BLoC',
        bodyText:
            'Clean Architecture phân tách thành 3 tầng: Presentation, Domain, Data. BLoC xử lý sự kiện bất đồng bộ theo luồng Stream.',
        createdAt: now.subtract(const Duration(days: 2)),
        updatedAt: now.subtract(const Duration(days: 2)),
      ),
      LectureNote(
        id: 'note_demo_2',
        subjectId: 'sub_db',
        slotId: 'slot_wed_m1',
        title: 'Tối ưu hóa B-Tree & Indexing trong CSDL',
        bodyText:
            'Chỉ mục B-Tree giúp giảm độ phức tạp truy vấn từ O(N) xuống O(log N). Cần tránh tạo quá nhiều index gây chậm lệnh INSERT/UPDATE.',
        createdAt: now.subtract(const Duration(days: 1)),
        updatedAt: now.subtract(const Duration(days: 1)),
      ),
      LectureNote(
        id: 'note_demo_3',
        subjectId: 'sub_network',
        slotId: null,
        title: 'Giao thức TCP/IP và Quản lý Tắc nghẽn',
        bodyText:
            'TCP bảo đảm gói tin tới đích đúng thứ tự với 3-Way Handshake và thuật toán Slow Start / Congestion Avoidance.',
        createdAt: now,
        updatedAt: now,
      ),
    ];
    for (final note in sampleNotes) {
      _storage[note.id] = note;
    }
    _notify();
  }

  void _notify() {
    if (!_controller.isClosed) {
      final activeNotes = _storage.values
          .where((note) => note.deletedAt == null)
          .toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      _controller.add(activeNotes);
    }
  }

  @override
  Future<LectureNote?> getNoteById(String id) async {
    final note = _storage[id];
    if (note == null || note.deletedAt != null) return null;
    return note;
  }

  @override
  Future<void> saveNote(LectureNote note) async {
    _storage[note.id] = note;
    _notify();
  }

  @override
  Future<List<LectureNote>> getAllNotes() async {
    return _storage.values
        .where((note) => note.deletedAt == null)
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  @override
  Stream<List<LectureNote>> watchAllNotes() async* {
    yield await getAllNotes();
    yield* _controller.stream;
  }

  @override
  Future<void> deleteNote(String id) async {
    final existing = _storage[id];
    if (existing != null) {
      _storage[id] = existing.copyWith(deletedAt: DateTime.now());
      _notify();
    }
  }

  void dispose() {
    _controller.close();
  }
}

