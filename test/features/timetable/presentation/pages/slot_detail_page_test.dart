import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:nhom_7/core/di/injection.dart';
import 'package:nhom_7/core/l10n/strings.dart';
import 'package:nhom_7/features/timetable/data/models/slot_model.dart';
import 'package:nhom_7/features/timetable/data/models/subject_model.dart';
import 'package:nhom_7/features/timetable/domain/repositories/timetable_repository.dart';
import 'package:nhom_7/features/timetable/presentation/pages/slot_detail_page.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('slot_detail_test_');
    Hive.init(tempDir.path);
    FlutterSecureStorage.setMockInitialValues({});
    await configureDependencies(isTest: true);

    // Seed test subject & slot
    final repo = getIt<TimetableRepository>();
    final now = DateTime(2026, 10, 24);
    final subject = SubjectModel(
      id: 'test_subj_flutter',
      code: 'CMP177',
      name: 'Lập trình di động Flutter',
      credits: 3,
      colorArgb: 0xFF1E88E5,
      createdAt: now,
      updatedAt: now,
    );
    await repo.saveSubject(subject);

    final slot = TimetableSlotModel(
      id: 'test_slot_101',
      subjectId: 'test_subj_flutter',
      dayOfWeek: 6, // Thứ Bảy
      startMin: 450, // 07:30
      endMin: 570, // 09:30
      room: 'A1.401',
      buildingId: 'A1',
      termStart: now,
      termEnd: now,
      source: 'user',
      updatedAt: now,
    );
    await repo.saveSlots([slot]);
  });

  tearDown(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
    await getIt.reset();
  });

  testWidgets('SlotDetailPage renders subject info, room and no directions button',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SlotDetailPage(slotId: 'test_slot_101'),
      ),
    );
    await tester.pumpAndSettle();

    // Verify subject name & code
    expect(find.text('Lập trình di động Flutter'), findsOneWidget);
    expect(find.text('CMP177'), findsOneWidget);

    // Verify room
    expect(find.text('Phòng A1.401'), findsOneWidget);

    // Verify Edit and Delete buttons on AppBar
    expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline_rounded), findsOneWidget);

    // Verify directions button is completely REMOVED
    expect(find.text(AppStrings.getDirections), findsNothing);
    expect(find.byIcon(Icons.directions_walk_rounded), findsNothing);

    // Verify Create Note button exists
    expect(find.text(AppStrings.createNoteForSlot), findsOneWidget);
  });

  testWidgets('SlotDetailPage tapping edit button opens _EditSlotBottomSheet',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SlotDetailPage(slotId: 'test_slot_101'),
      ),
    );
    await tester.pumpAndSettle();

    // Tap edit button
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();

    // Verify modal bottom sheet opens with prefilled data
    expect(find.text('Chỉnh sửa ca học'), findsOneWidget);
    expect(find.text('Lưu thay đổi'), findsOneWidget);
    expect(find.text('Lập trình di động Flutter'), findsWidgets);
    expect(find.text('A1.401'), findsOneWidget);
  });

  testWidgets('SlotDetailPage renders deadlines card and allows adding deadline',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SlotDetailPage(slotId: 'test_slot_101'),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Deadline Card exists
    expect(find.textContaining('Hạn nộp & Nhiệm vụ'), findsOneWidget);
    final addButton = find.text('Thêm');
    expect(addButton, findsOneWidget);

    // Scroll until visible then tap
    await tester.ensureVisible(addButton);
    await tester.pumpAndSettle();
    await tester.tap(addButton);
    await tester.pumpAndSettle();

    // Verify Add Deadline modal opens
    expect(find.text('Thêm hạn nộp bài / Nhiệm vụ'), findsOneWidget);
    expect(find.text('Tên bài tập / nhiệm vụ *'), findsOneWidget);

    // Enter title
    await tester.enterText(find.byType(TextField).first, 'Bài tập lớn cuối kỳ');
    await tester.pumpAndSettle();

    // Tap 'Thêm nhiệm vụ' button
    await tester.tap(find.text('Thêm nhiệm vụ'));
    await tester.pumpAndSettle();

    // Verify new deadline is displayed in list
    expect(find.text('Bài tập lớn cuối kỳ'), findsOneWidget);
  });

  testWidgets('SlotDetailPage persists reminder minutes when 5 mins is selected',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SlotDetailPage(slotId: 'test_slot_101'),
      ),
    );
    await tester.pumpAndSettle();

    final fiveMinsChip = find.text('5 phút');
    expect(fiveMinsChip, findsOneWidget);

    await tester.ensureVisible(fiveMinsChip);
    await tester.pumpAndSettle();
    await tester.tap(fiveMinsChip);
    await tester.pumpAndSettle();

    // Verify storage has '5'
    const storage = FlutterSecureStorage();
    final savedMins = await storage.read(key: 'slot_reminder_mins_test_slot_101');
    expect(savedMins, '5');

    // Reopen SlotDetailPage to verify persistence
    await tester.pumpWidget(
      const MaterialApp(
        home: SlotDetailPage(slotId: 'test_slot_101'),
      ),
    );
    await tester.pumpAndSettle();

    final choiceChipWidget = tester.widget<ChoiceChip>(
      find.ancestor(of: find.text('5 phút'), matching: find.byType(ChoiceChip)),
    );
    expect(choiceChipWidget.selected, isTrue);
  });
}
