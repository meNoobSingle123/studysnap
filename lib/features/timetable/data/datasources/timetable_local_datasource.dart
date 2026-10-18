import 'dart:async';
import 'package:hive_ce/hive.dart';
import '../../../../core/security/key_storage_service.dart';
import '../models/building_model.dart';
import '../models/exam_model.dart';
import '../models/slot_model.dart';
import '../models/subject_model.dart';
import 'timetable_mock_data.dart';

abstract class TimetableLocalDataSource {
  Future<void> init();
  Future<void> seedMockData({bool force = false});
  Stream<List<TimetableSlotModel>> watchSlotsByDay(int dayOfWeek);
  Stream<List<TimetableSlotModel>> watchAllSlots();
  Stream<List<SubjectModel>> watchSubjects();
  Future<List<SubjectModel>> getSubjects();
  Future<SubjectModel?> getSubjectById(String id);
  Future<void> saveSubject(SubjectModel subject);
  Future<void> softDeleteSubject(String id);
  Future<void> saveSlots(List<TimetableSlotModel> slots);
  Future<TimetableSlotModel?> getSlotById(String id);
  Future<void> deleteSlot(String id);
  Future<List<ExamScheduleModel>> getExams();
  Future<void> saveExams(List<ExamScheduleModel> exams);
  Future<List<CampusBuildingModel>> getBuildings();
  Future<void> saveBuildings(List<CampusBuildingModel> buildings);
}

class TimetableLocalDataSourceImpl implements TimetableLocalDataSource {
  final KeyStorageService keyStorageService;

  static const String kSubjectsBox = 'subjects';
  static const String kSlotsBox = 'slots';
  static const String kExamsBox = 'exams';
  static const String kBuildingsBox = 'buildings';

  Box<SubjectModel>? _subjectsBox;
  Box<TimetableSlotModel>? _slotsBox;
  Box<ExamScheduleModel>? _examsBox;
  Box<CampusBuildingModel>? _buildingsBox;

  TimetableLocalDataSourceImpl({required this.keyStorageService});

  Completer<void>? _initCompleter;

  Future<void> _ensureInitialized() async {
    if (_subjectsBox != null &&
        _subjectsBox!.isOpen &&
        _slotsBox != null &&
        _slotsBox!.isOpen &&
        _examsBox != null &&
        _examsBox!.isOpen &&
        _buildingsBox != null &&
        _buildingsBox!.isOpen) {
      return;
    }
    if (_initCompleter != null) {
      return _initCompleter!.future;
    }
    _initCompleter = Completer<void>();
    try {
      await init();
      _initCompleter!.complete();
    } catch (e, st) {
      _initCompleter!.completeError(e, st);
      _initCompleter = null;
      rethrow;
    }
  }

  @override
  Future<void> init() async {
    // 1. Đăng ký TypeAdapters nếu chưa đăng ký
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(SubjectModelAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(TimetableSlotModelAdapter());
    }
    if (!Hive.isAdapterRegistered(3)) {
      Hive.registerAdapter(ExamScheduleModelAdapter());
    }
    if (!Hive.isAdapterRegistered(4)) {
      Hive.registerAdapter(CampusBuildingModelAdapter());
    }

    // 2. Lấy khóa mã hóa AES-256 từ KeyStorageService (core)
    final encryptionKey = await keyStorageService.getOrCreateEncryptionKey();
    final cipher = HiveAesCipher(encryptionKey);

    // 3. Mở các box với mã hóa HiveAesCipher (kiểm tra isBoxOpen nếu đã mở trước đó)
    _subjectsBox = Hive.isBoxOpen(kSubjectsBox)
        ? Hive.box<SubjectModel>(kSubjectsBox)
        : await Hive.openBox<SubjectModel>(
            kSubjectsBox,
            encryptionCipher: cipher,
          );

    _slotsBox = Hive.isBoxOpen(kSlotsBox)
        ? Hive.box<TimetableSlotModel>(kSlotsBox)
        : await Hive.openBox<TimetableSlotModel>(
            kSlotsBox,
            encryptionCipher: cipher,
          );

    _examsBox = Hive.isBoxOpen(kExamsBox)
        ? Hive.box<ExamScheduleModel>(kExamsBox)
        : await Hive.openBox<ExamScheduleModel>(
            kExamsBox,
            encryptionCipher: cipher,
          );

    _buildingsBox = Hive.isBoxOpen(kBuildingsBox)
        ? Hive.box<CampusBuildingModel>(kBuildingsBox)
        : await Hive.openBox<CampusBuildingModel>(
            kBuildingsBox,
            encryptionCipher: cipher,
          );

    // 4. Tự động nạp dữ liệu mẫu ban đầu nếu CSDL trống
    if (_subjectsBox!.isEmpty) {
      await seedMockData();
    }
  }

  @override
  Future<void> seedMockData({bool force = false}) async {
    if (_subjectsBox == null || !_subjectsBox!.isOpen) {
      await _ensureInitialized();
    }
    if (force || _sBox.isEmpty) {
      final subjectEntries = {
        for (final s in TimetableMockData.subjects) s.id: s
      };
      await _sBox.putAll(subjectEntries);

      final slotEntries = {
        for (final slot in TimetableMockData.getSlots()) slot.id: slot
      };
      await _slBox.putAll(slotEntries);

      final bEntries = {
        for (final b in TimetableMockData.buildings) b.id: b
      };
      await _bBox.putAll(bEntries);

      final eEntries = {
        for (final e in TimetableMockData.exams) e.id: e
      };
      await _eBox.putAll(eEntries);
      await _sBox.flush();
      await _slBox.flush();
      await _bBox.flush();
      await _eBox.flush();
    }
  }

  Box<SubjectModel> get _sBox => _subjectsBox!;
  Box<TimetableSlotModel> get _slBox => _slotsBox!;
  Box<ExamScheduleModel> get _eBox => _examsBox!;
  Box<CampusBuildingModel> get _bBox => _buildingsBox!;

  List<TimetableSlotModel> _filterSlotsByDay(int dayOfWeek) {
    return _slBox.values
        .where((s) => s.dayOfWeek == dayOfWeek && !s.isDeleted)
        .toList()
      ..sort((a, b) => a.startMin.compareTo(b.startMin));
  }

  List<TimetableSlotModel> _filterAllActiveSlots() {
    return _slBox.values.where((s) => !s.isDeleted).toList()
      ..sort((a, b) {
        final dayCmp = a.dayOfWeek.compareTo(b.dayOfWeek);
        if (dayCmp != 0) return dayCmp;
        return a.startMin.compareTo(b.startMin);
      });
  }

  List<SubjectModel> _filterActiveSubjects() {
    return _sBox.values.where((s) => !s.isDeleted).toList()
      ..sort((a, b) => a.code.compareTo(b.code));
  }

  @override
  Stream<List<TimetableSlotModel>> watchSlotsByDay(int dayOfWeek) async* {
    await _ensureInitialized();
    yield _filterSlotsByDay(dayOfWeek);
    yield* _slBox.watch().map((_) => _filterSlotsByDay(dayOfWeek));
  }

  @override
  Stream<List<TimetableSlotModel>> watchAllSlots() async* {
    await _ensureInitialized();
    yield _filterAllActiveSlots();
    yield* _slBox.watch().map((_) => _filterAllActiveSlots());
  }

  @override
  Stream<List<SubjectModel>> watchSubjects() async* {
    await _ensureInitialized();
    yield _filterActiveSubjects();
    yield* _sBox.watch().map((_) => _filterActiveSubjects());
  }

  @override
  Future<List<SubjectModel>> getSubjects() async {
    await _ensureInitialized();
    return _filterActiveSubjects();
  }

  @override
  Future<SubjectModel?> getSubjectById(String id) async {
    await _ensureInitialized();
    try {
      final s = _sBox.get(id);
      if (s != null && !s.isDeleted) return s;
      return null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> saveSubject(SubjectModel subject) async {
    await _ensureInitialized();
    await _sBox.put(subject.id, subject);
    await _sBox.flush();
  }

  @override
  Future<void> softDeleteSubject(String id) async {
    await _ensureInitialized();
    final s = _sBox.get(id);
    if (s != null) {
      final deleted = s.copyWith(deletedAt: DateTime.now());
      await _sBox.put(id, SubjectModel.fromEntity(deleted));
      await _sBox.flush();
    }
  }

  @override
  Future<void> saveSlots(List<TimetableSlotModel> slots) async {
    await _ensureInitialized();
    final entries = {for (final slot in slots) slot.id: slot};
    await _slBox.putAll(entries);
    await _slBox.flush();
  }

  @override
  Future<TimetableSlotModel?> getSlotById(String id) async {
    await _ensureInitialized();
    try {
      final slot = _slBox.get(id);
      if (slot != null && !slot.isDeleted) return slot;
      return null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> deleteSlot(String id) async {
    await _ensureInitialized();
    final slot = _slBox.get(id);
    if (slot != null) {
      final deleted = slot.copyWith(deletedAt: DateTime.now());
      await _slBox.put(id, TimetableSlotModel.fromEntity(deleted));
      await _slBox.flush();
    }
  }

  @override
  Future<List<ExamScheduleModel>> getExams() async {
    await _ensureInitialized();
    return _eBox.values.toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  @override
  Future<void> saveExams(List<ExamScheduleModel> exams) async {
    await _ensureInitialized();
    final entries = {for (final exam in exams) exam.id: exam};
    await _eBox.putAll(entries);
  }

  @override
  Future<List<CampusBuildingModel>> getBuildings() async {
    await _ensureInitialized();
    return _bBox.values.toList();
  }

  @override
  Future<void> saveBuildings(List<CampusBuildingModel> buildings) async {
    await _ensureInitialized();
    final entries = {for (final b in buildings) b.id: b};
    await _bBox.putAll(entries);
  }
}
