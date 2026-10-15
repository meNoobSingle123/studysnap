import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nhom_7/features/notifications/domain/services/notification_service.dart';
import 'package:nhom_7/features/timetable/domain/entities/subject.dart';
import 'package:nhom_7/features/timetable/domain/entities/timetable_slot.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class MockFlutterLocalNotificationsPlugin extends Mock
    implements FlutterLocalNotificationsPlugin {}

class FakeNotificationDetails extends Fake implements NotificationDetails {}
class FakeTZDateTime extends Fake implements tz.TZDateTime {}
class FakeInitializationSettings extends Fake implements InitializationSettings {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockFlutterLocalNotificationsPlugin mockPlugin;
  late NotificationService service;

  final sampleSubject = Subject(

    id: 'sub_1',
    code: 'CSC10006',
    name: 'Mạng máy tính',
    credits: 4,
    colorArgb: 0xFF1976D2,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  setUpAll(() {
    tz_data.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation('Asia/Ho_Chi_Minh'));
    } catch (_) {}

    registerFallbackValue(FakeNotificationDetails());
    registerFallbackValue(FakeTZDateTime());
    registerFallbackValue(FakeInitializationSettings());
    registerFallbackValue(AndroidScheduleMode.exactAllowWhileIdle);
  });


  setUp(() {
    mockPlugin = MockFlutterLocalNotificationsPlugin();
    service = NotificationService(plugin: mockPlugin);

    when(() => mockPlugin.initialize(
          settings: any(named: 'settings'),
          onDidReceiveNotificationResponse: any(named: 'onDidReceiveNotificationResponse'),
        )).thenAnswer((_) async => true);

    when(() => mockPlugin.show(
          id: any(named: 'id'),
          title: any(named: 'title'),
          body: any(named: 'body'),
          notificationDetails: any(named: 'notificationDetails'),
          payload: any(named: 'payload'),
        )).thenAnswer((_) async {});

    when(() => mockPlugin.zonedSchedule(
          id: any(named: 'id'),
          title: any(named: 'title'),
          body: any(named: 'body'),
          scheduledDate: any(named: 'scheduledDate'),
          notificationDetails: any(named: 'notificationDetails'),
          androidScheduleMode: any(named: 'androidScheduleMode'),
          payload: any(named: 'payload'),
        )).thenAnswer((_) async {});

    when(() => mockPlugin.cancel(id: any(named: 'id'))).thenAnswer((_) async {});
    when(() => mockPlugin.cancelAll()).thenAnswer((_) async {});
    when(() => mockPlugin.pendingNotificationRequests())
        .thenAnswer((_) async => <PendingNotificationRequest>[]);
  });

  group('NotificationService Unit Tests', () {
    test('showInstantNotification calls plugin.show with high importance', () async {
      await service.showInstantNotification(
        id: 1234,
        title: 'Thông báo tức thì',
        body: 'Nội dung thông báo kiểm thử',
      );

      verify(() => mockPlugin.show(
            id: 1234,
            title: 'Thông báo tức thì',
            body: 'Nội dung thông báo kiểm thử',
            notificationDetails: any(named: 'notificationDetails'),
            payload: any(named: 'payload'),
          )).called(1);
    });

    test('scheduleRollingReminders schedules future slots with 15-min lead time', () async {
      // Giả lập thời điểm hiện tại: Thứ Hai, 8h00 sáng ngày 19/10/2026
      final mockNow = DateTime(2026, 10, 19, 8, 0);

      // Slot 1: Thứ Hai, 09:30 (570 phút) -> Nhắc lúc 09:15 (tương lai -> được lên lịch)
      final slotMonday = TimetableSlot(
        id: 'slot_mon',
        subjectId: 'sub_1',
        dayOfWeek: DateTime.monday,
        startMin: 570, // 09:30
        endMin: 660,
        room: 'H2.304',
        buildingId: 'H2',
        termStart: DateTime(2026, 9, 1),
        termEnd: DateTime(2026, 12, 31),
        source: 'system',
        updatedAt: DateTime(2026, 9, 1),
      );

      // Slot 2: Thứ Hai, 07:30 (450 phút) -> Nhắc lúc 07:15 (quá khứ -> bị bỏ qua)
      final slotPast = TimetableSlot(
        id: 'slot_past',
        subjectId: 'sub_1',
        dayOfWeek: DateTime.monday,
        startMin: 450, // 07:30
        endMin: 540,
        room: 'H2.101',
        termStart: DateTime(2026, 9, 1),
        termEnd: DateTime(2026, 12, 31),
        source: 'system',
        updatedAt: DateTime(2026, 9, 1),
      );

      final count = await service.scheduleRollingReminders(
        slots: [slotMonday, slotPast],
        subjectsMap: {'sub_1': sampleSubject},
        daysAhead: 7,
        leadMinutes: 15,
        currentTime: mockNow,
      );

      // Ít nhất 1 ca học trong tuần được lên lịch
      expect(count, greaterThanOrEqualTo(1));
      verify(() => mockPlugin.zonedSchedule(
            id: any(named: 'id'),
            title: any(named: 'title'),
            body: any(named: 'body'),
            scheduledDate: any(named: 'scheduledDate'),
            notificationDetails: any(named: 'notificationDetails'),
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            payload: any(named: 'payload'),
          )).called(greaterThanOrEqualTo(1));
    });

    test('scheduleRollingReminders ignores soft-deleted slots', () async {
      final mockNow = DateTime(2026, 10, 19, 8, 0);
      final deletedSlot = TimetableSlot(
        id: 'slot_deleted',
        subjectId: 'sub_1',
        dayOfWeek: DateTime.monday,
        startMin: 600,
        endMin: 690,
        room: 'H2.304',
        termStart: DateTime(2026, 9, 1),
        termEnd: DateTime(2026, 12, 31),
        source: 'system',
        updatedAt: DateTime(2026, 9, 1),
        deletedAt: DateTime(2026, 10, 1), // Xóa mềm
      );

      final count = await service.scheduleRollingReminders(
        slots: [deletedSlot],
        subjectsMap: {'sub_1': sampleSubject},
        daysAhead: 7,
        currentTime: mockNow,
      );

      expect(count, equals(0));
    });

    test('cancelReminder and cancelAllReminders call plugin methods correctly', () async {
      await service.cancelReminder(99);
      verify(() => mockPlugin.cancel(id: 99)).called(1);

      await service.cancelAllReminders();
      verify(() => mockPlugin.cancelAll()).called(1);
    });
  });
}
