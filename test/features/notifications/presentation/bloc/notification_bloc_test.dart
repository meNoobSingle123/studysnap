import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nhom_7/features/notifications/domain/services/notification_service.dart';
import 'package:nhom_7/features/notifications/presentation/bloc/notification_bloc.dart';
import 'package:nhom_7/features/notifications/presentation/bloc/notification_event.dart';
import 'package:nhom_7/features/notifications/presentation/bloc/notification_state.dart';
import 'package:nhom_7/features/timetable/domain/entities/subject.dart';
import 'package:nhom_7/features/timetable/domain/entities/timetable_slot.dart';
import 'package:nhom_7/features/timetable/domain/repositories/timetable_repository.dart';

class MockNotificationService extends Mock implements NotificationService {}
class MockTimetableRepository extends Mock implements TimetableRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockNotificationService mockService;
  late MockTimetableRepository mockRepo;

  final sampleSubject = Subject(
    id: 'sub_1',
    code: 'CSC10006',
    name: 'Mạng máy tính',
    credits: 4,
    colorArgb: 0xFF1976D2,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  final sampleSlot = TimetableSlot(
    id: 'slot_1',
    subjectId: 'sub_1',
    dayOfWeek: 2,
    startMin: 450,
    endMin: 540,
    room: 'H2.304',
    termStart: DateTime(2026, 9, 1),
    termEnd: DateTime(2026, 12, 31),
    source: 'system',
    updatedAt: DateTime(2026, 9, 1),
  );

  setUp(() {
    mockService = MockNotificationService();
    mockRepo = MockTimetableRepository();

    when(() => mockService.init(isTest: any(named: 'isTest'))).thenAnswer((_) async {});
    when(() => mockService.isNotificationPermissionGranted()).thenAnswer((_) async => true);
    when(() => mockService.isExactAlarmPermissionGranted()).thenAnswer((_) async => true);
    when(() => mockService.getPendingReminders()).thenAnswer(
      (_) async => [
        const PendingNotificationRequest(1, 'Title', 'Body', null),
      ],
    );

    when(() => mockRepo.watchAllSlots()).thenAnswer((_) => Stream.value([sampleSlot]));
    when(() => mockRepo.getSubjects()).thenAnswer((_) async => [sampleSubject]);

    when(() => mockService.scheduleRollingReminders(
          slots: any(named: 'slots'),
          subjectsMap: any(named: 'subjectsMap'),
          leadMinutes: any(named: 'leadMinutes'),
        )).thenAnswer((_) async => 3);

    when(() => mockService.showInstantNotification(
          id: any(named: 'id'),
          title: any(named: 'title'),
          body: any(named: 'body'),
        )).thenAnswer((_) async {});

    when(() => mockService.cancelAllReminders()).thenAnswer((_) async {});
  });

  NotificationBloc buildBloc() => NotificationBloc(
        notificationService: mockService,
        timetableRepository: mockRepo,
      );

  group('NotificationBloc Tests', () {
    test('initial state is NotificationInitial', () {
      final bloc = buildBloc();
      expect(bloc.state, equals(const NotificationInitial()));
    });

    blocTest<NotificationBloc, NotificationState>(
      'emits [NotificationLoading, NotificationLoaded] when InitNotificationEvent is added',
      build: buildBloc,
      act: (bloc) => bloc.add(const InitNotificationEvent()),
      expect: () => [
        const NotificationLoading(),
        const NotificationLoaded(
          isNotificationGranted: true,
          isExactAlarmGranted: true,
          pendingCount: 1,
        ),
      ],
      verify: (_) {
        verify(() => mockService.init()).called(1);
        verify(() => mockService.isNotificationPermissionGranted()).called(1);
        verify(() => mockService.getPendingReminders()).called(1);
      },
    );

    blocTest<NotificationBloc, NotificationState>(
      'schedules rolling reminders and updates state with feedback message',
      build: buildBloc,
      seed: () => const NotificationLoaded(
        isNotificationGranted: true,
        isExactAlarmGranted: true,
        leadMinutes: 15,
        pendingCount: 0,
      ),
      act: (bloc) => bloc.add(const ScheduleRollingRemindersEvent(leadMinutes: 15)),
      expect: () => [
        const NotificationLoading(),
        isA<NotificationLoaded>()
            .having((s) => s.leadMinutes, 'leadMinutes', 15)
            .having((s) => s.pendingCount, 'pendingCount', 1)
            .having((s) => s.feedbackMessage, 'feedbackMessage', contains('Đã lên lịch thành công 3 ca học')),
      ],
      verify: (_) {
        verify(() => mockService.scheduleRollingReminders(
              slots: any(named: 'slots'),
              subjectsMap: any(named: 'subjectsMap'),
              leadMinutes: 15,
            )).called(1);
      },
    );

    blocTest<NotificationBloc, NotificationState>(
      'triggers test notification and emits feedback message',
      build: buildBloc,
      seed: () => const NotificationLoaded(
        isNotificationGranted: true,
        isExactAlarmGranted: true,
        pendingCount: 2,
      ),
      act: (bloc) => bloc.add(const TriggerTestNotificationEvent()),
      expect: () => [
        const NotificationLoaded(
          isNotificationGranted: true,
          isExactAlarmGranted: true,
          pendingCount: 2,
          feedbackMessage: 'Đã phát thông báo thử nghiệm thành công!',
        ),
      ],
      verify: (_) {
        verify(() => mockService.showInstantNotification(
              id: any(named: 'id'),
              title: any(named: 'title'),
              body: any(named: 'body'),
            )).called(1);
      },
    );

    blocTest<NotificationBloc, NotificationState>(
      'cancels all reminders and resets pendingCount to 0',
      build: buildBloc,
      seed: () => const NotificationLoaded(
        isNotificationGranted: true,
        isExactAlarmGranted: true,
        pendingCount: 5,
      ),
      act: (bloc) => bloc.add(const CancelAllRemindersEvent()),
      expect: () => [
        const NotificationLoaded(
          isNotificationGranted: true,
          isExactAlarmGranted: true,
          pendingCount: 0,
          feedbackMessage: 'Đã hủy toàn bộ lịch nhắc giờ ca học.',
        ),
      ],
      verify: (_) {
        verify(() => mockService.cancelAllReminders()).called(1);
      },
    );
  });
}
