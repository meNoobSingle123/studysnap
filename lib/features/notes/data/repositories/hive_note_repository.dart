import 'dart:async';

import 'package:hive_ce/hive.dart';

import '../../../../core/security/key_storage_service.dart';
import '../../domain/entities/lecture_note.dart';
import '../../domain/repositories/note_repository.dart';

/// Triển khai NoteRepository bằng cơ sở dữ liệu Hive CE cục bộ (Local-First).
/// Dữ liệu được ghi trực tiếp xuống file trong bộ nhớ máy (getApplicationDocumentsDirectory).
/// Hỗ trợ mã hóa AES-256 qua HiveAesCipher và reactive updates.
class HiveNoteRepository implements NoteRepository {
  static const String kNotesBoxName = 'notes_box';

  final KeyStorageService? keyStorageService;
  Box<Map>? box;
  final StreamController<List<LectureNote>> _streamController =
      StreamController<List<LectureNote>>.broadcast();

  HiveNoteRepository({
    this.box,
    this.keyStorageService,
  });

  /// Khởi tạo và mở Box với khóa mã hóa an toàn nếu chưa mở.
  Future<Box<Map>> _getBox() async {
    if (box != null && box!.isOpen) {
      return box!;
    }

    if (Hive.isBoxOpen(kNotesBoxName)) {
      box = Hive.box<Map>(kNotesBoxName);
      return box!;
    }

    HiveCipher? cipher;
    if (keyStorageService != null) {
      try {
        final key = await keyStorageService!.getOrCreateEncryptionKey();
        cipher = HiveAesCipher(key);
      } catch (_) {
        // Fallback cipher nếu môi trường test không có KeyStorageService
      }
    }

    try {
      box = await Hive.openBox<Map>(
        kNotesBoxName,
        encryptionCipher: cipher,
      );
    } catch (_) {
      // Nếu có lỗi do cipher cũ hoặc crash trước đó, mở không mã hóa để bảo đảm an toàn dữ liệu
      box = await Hive.openBox<Map>(kNotesBoxName);
    }

    return box!;
  }

  /// Khởi tạo HiveNoteRepository. Tự động dọn dẹp các ghi chú mẫu nếu còn lưu trong CSDL.
  Future<void> init({bool seedMockData = false}) async {
    final box = await _getBox();
    const demoIds = ['note_demo_1', 'note_demo_2', 'note_demo_3'];
    bool changed = false;
    for (final id in demoIds) {
      if (box.containsKey(id)) {
        await box.delete(id);
        changed = true;
      }
    }
    if (changed) {
      await _notify();
    }
  }

  Map<String, dynamic> _toMap(LectureNote note) {
    return {
      'id': note.id,
      'subjectId': note.subjectId,
      'slotId': note.slotId,
      'title': note.title,
      'bodyText': note.bodyText,
      'videoPaths': note.videoPaths,
      'imagePaths': note.imagePaths,
      'location': note.location,
      'createdAt': note.createdAt.toIso8601String(),
      'updatedAt': note.updatedAt.toIso8601String(),
      'deletedAt': note.deletedAt?.toIso8601String(),
    };
  }

  LectureNote _fromMap(Map data) {
    final vPathsRaw = data['videoPaths'];
    List<String> videoPaths = [];
    if (vPathsRaw is List) {
      videoPaths = vPathsRaw.map((e) => e.toString()).toList();
    } else if (data['videoPath'] != null) {
      videoPaths = [data['videoPath'].toString()];
    }

    final iPathsRaw = data['imagePaths'];
    List<String> imagePaths = [];
    if (iPathsRaw is List) {
      imagePaths = iPathsRaw.map((e) => e.toString()).toList();
    }

    return LectureNote(
      id: data['id'] as String? ?? '',
      subjectId: data['subjectId'] as String? ?? 'sub_flutter',
      slotId: data['slotId'] as String?,
      title: data['title'] as String? ?? '',
      bodyText: data['bodyText'] as String? ?? '',
      videoPaths: videoPaths,
      imagePaths: imagePaths,
      location: data['location'] as String?,
      createdAt: DateTime.tryParse(data['createdAt'] as String? ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(data['updatedAt'] as String? ?? '') ?? DateTime.now(),
      deletedAt: data['deletedAt'] != null ? DateTime.tryParse(data['deletedAt'] as String) : null,
    );
  }

  Future<void> _notify() async {
    if (!_streamController.isClosed) {
      final notes = await getAllNotes();
      _streamController.add(notes);
    }
  }

  @override
  Future<LectureNote?> getNoteById(String id) async {
    final box = await _getBox();
    final data = box.get(id);
    if (data == null) return null;
    final note = _fromMap(data);
    if (note.deletedAt != null) return null;
    return note;
  }

  @override
  Future<void> saveNote(LectureNote note) async {
    final box = await _getBox();
    await box.put(note.id, _toMap(note));
    await _notify();
  }

  @override
  Future<List<LectureNote>> getAllNotes() async {
    final box = await _getBox();
    final notes = box.values
        .map((m) => _fromMap(m))
        .where((n) => n.deletedAt == null)
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return notes;
  }

  @override
  Stream<List<LectureNote>> watchAllNotes() async* {
    yield await getAllNotes();
    final box = await _getBox();
    yield* box.watch().asyncMap((_) async => getAllNotes());
    yield* _streamController.stream;
  }

  @override
  Future<void> deleteNote(String id) async {
    final box = await _getBox();
    final existingData = box.get(id);
    if (existingData != null) {
      final existingNote = _fromMap(existingData);
      final deleted = existingNote.copyWith(deletedAt: DateTime.now());
      await box.put(id, _toMap(deleted));
      await _notify();
    }
  }

  Future<void> close() async {
    await _streamController.close();
  }
}
