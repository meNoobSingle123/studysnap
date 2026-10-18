import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:nhom_7/core/security/key_storage_service.dart';
import 'package:nhom_7/features/timetable/data/datasources/timetable_local_datasource.dart';
import 'package:nhom_7/features/timetable/data/models/slot_model.dart';
import 'package:nhom_7/features/timetable/data/models/subject_model.dart';

void main() {
  late Directory tempDir;
  late KeyStorageService keyStorageService;
  late TimetableLocalDataSourceImpl dataSource;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('timetable_ds_test_');
    Hive.init(tempDir.path);

    FlutterSecureStorage.setMockInitialValues({});
    keyStorageService = KeyStorageService(
      storage: const FlutterSecureStorage(),
    );

    dataSource = TimetableLocalDataSourceImpl(
      keyStorageService: keyStorageService,
    );
  });

  tearDown(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('TimetableLocalDataSource Tests', () {
    test('1. init() opens encrypted boxes and seeds initial mock data', () async {
      await dataSource.init();

      final subjects = await dataSource.getSubjects();
      expect(subjects.isNotEmpty, isTrue);

      final allSlots = await dataSource.watchAllSlots().first;
      expect(allSlots.isNotEmpty, isTrue);
    });

    test('2. saveSubject() and getSubjectById() persists and retrieves subject',
        () async {
      await dataSource.init();

      final now = DateTime(2026, 10, 20);
      final newSubject = SubjectModel(
        id: 'test_sub_101',
        code: 'TEST101',
        name: 'Kiểm thử phần mềm',
        credits: 3,
        colorArgb: 0xFF123456,
        createdAt: now,
        updatedAt: now,
      );

      await dataSource.saveSubject(newSubject);
      final retrieved = await dataSource.getSubjectById('test_sub_101');

      expect(retrieved, isNotNull);
      expect(retrieved!.name, 'Kiểm thử phần mềm');
      expect(retrieved.code, 'TEST101');
    });

    test('3. saveSlots() persists slots and watchAllSlots() streams new slots',
        () async {
      await dataSource.init();

      final now = DateTime(2026, 10, 20);
      final slot1 = TimetableSlotModel(
        id: 'slot_test_1',
        subjectId: 'test_sub_101',
        dayOfWeek: 2, // Thứ 3
        startMin: 420, // 07:00
        endMin: 540, // 09:00
        room: 'H2.304',
        buildingId: 'H2',
        termStart: now,
        termEnd: now,
        source: 'user',
        updatedAt: now,
      );

      await dataSource.saveSlots([slot1]);

      final retrieved = await dataSource.getSlotById('slot_test_1');
      expect(retrieved, isNotNull);
      expect(retrieved!.room, 'H2.304');
      expect(retrieved.dayOfWeek, 2);

      // Verify watchSlotsByDay
      final daySlots = await dataSource.watchSlotsByDay(2).first;
      expect(daySlots.any((s) => s.id == 'slot_test_1'), isTrue);
    });

    test('4. deleteSlot() soft deletes slot correctly', () async {
      await dataSource.init();

      final now = DateTime(2026, 10, 20);
      final slot = TimetableSlotModel(
        id: 'slot_to_delete',
        subjectId: 'test_sub_101',
        dayOfWeek: 3,
        startMin: 480,
        endMin: 600,
        room: 'Online',
        termStart: now,
        termEnd: now,
        source: 'user',
        updatedAt: now,
      );

      await dataSource.saveSlots([slot]);
      expect(await dataSource.getSlotById('slot_to_delete'), isNotNull);

      await dataSource.deleteSlot('slot_to_delete');
      expect(await dataSource.getSlotById('slot_to_delete'), isNull);
    });

    test('5. _ensureInitialized() automatically opens boxes even if init() was not called directly',
        () async {
      // KHÔNG gọi dataSource.init() trước
      final now = DateTime(2026, 10, 20);
      final newSubject = SubjectModel(
        id: 'auto_init_sub',
        code: 'AUTO101',
        name: 'Tự động mở box',
        credits: 2,
        colorArgb: 0xFF654321,
        createdAt: now,
        updatedAt: now,
      );

      // Phải tự động mở box mà không văng NullCheckOperatorException
      await dataSource.saveSubject(newSubject);
      final found = await dataSource.getSubjectById('auto_init_sub');

      expect(found, isNotNull);
      expect(found!.name, 'Tự động mở box');
    });
  });
}
