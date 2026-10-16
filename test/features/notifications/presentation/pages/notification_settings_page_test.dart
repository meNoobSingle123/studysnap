import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nhom_7/core/l10n/strings.dart';
import 'package:nhom_7/features/notifications/domain/services/notification_service.dart';
import 'package:nhom_7/features/notifications/presentation/bloc/notification_bloc.dart';
import 'package:nhom_7/features/notifications/presentation/pages/notification_settings_page.dart';
import 'package:nhom_7/features/timetable/domain/repositories/timetable_repository.dart';

class MockNotificationService extends Mock implements NotificationService {}
class MockTimetableRepository extends Mock implements TimetableRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockNotificationService mockService;
  late MockTimetableRepository mockRepo;

  setUp(() async {
    await GetIt.instance.reset();

    mockService = MockNotificationService();
    mockRepo = MockTimetableRepository();

    when(() => mockService.init(isTest: any(named: 'isTest'))).thenAnswer((_) async {});
    when(() => mockService.isNotificationPermissionGranted()).thenAnswer((_) async => true);
    when(() => mockService.isExactAlarmPermissionGranted()).thenAnswer((_) async => true);
    when(() => mockService.getPendingReminders()).thenAnswer(
      (_) async => [
        const PendingNotificationRequest(1, 'Lịch học', 'Phòng H2.304', null),
      ],
    );
    when(() => mockService.showInstantNotification(
          id: any(named: 'id'),
          title: any(named: 'title'),
          body: any(named: 'body'),
        )).thenAnswer((_) async {});

    GetIt.instance.registerFactory<NotificationBloc>(
      () => NotificationBloc(
        notificationService: mockService,
        timetableRepository: mockRepo,
      ),
    );
  });

  tearDown(() async {
    await GetIt.instance.reset();
  });

  testWidgets('NotificationSettingsPage renders permissions and action buttons', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: NotificationSettingsPage(),
      ),
    );

    // Initial pump
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Verify Title
    expect(find.text(AppStrings.notificationSettingsTitle), findsOneWidget);

    // Verify Permission Status
    expect(find.text(AppStrings.notificationPermissionGranted), findsOneWidget);

    // Verify Action Buttons
    expect(find.text(AppStrings.scheduleRollingReminders), findsOneWidget);
    expect(find.text(AppStrings.testNotificationTitle), findsOneWidget);

    // Verify Pending Count
    expect(find.text('1'), findsOneWidget);

    // Tap test notification button
    await tester.tap(find.text(AppStrings.testNotificationTitle));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    verify(() => mockService.showInstantNotification(
          id: any(named: 'id'),
          title: any(named: 'title'),
          body: any(named: 'body'),
        )).called(1);

    expect(find.text('Đã phát thông báo thử nghiệm thành công!'), findsOneWidget);
  });
}
