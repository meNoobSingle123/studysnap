import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/l10n/strings.dart';
import '../../../timetable/domain/repositories/timetable_repository.dart';

import '../../domain/services/notification_service.dart';
import 'notification_event.dart';
import 'notification_state.dart';

class NotificationBloc extends Bloc<NotificationEvent, NotificationState> {
  final NotificationService notificationService;
  final TimetableRepository timetableRepository;

  NotificationBloc({
    required this.notificationService,
    required this.timetableRepository,
  }) : super(const NotificationInitial()) {
    on<InitNotificationEvent>(_onInit);
    on<RequestNotificationPermissionEvent>(_onRequestPermission);
    on<ScheduleRollingRemindersEvent>(_onScheduleRolling);
    on<TriggerTestNotificationEvent>(_onTriggerTest);
    on<CancelAllRemindersEvent>(_onCancelAll);
    on<ChangeLeadMinutesEvent>(_onChangeLeadMinutes);
  }

  Future<void> _onInit(
    InitNotificationEvent event,
    Emitter<NotificationState> emit,
  ) async {
    emit(const NotificationLoading());
    try {
      await notificationService.init();
      final isNotificationGranted = await notificationService.isNotificationPermissionGranted();
      final isExactAlarmGranted = await notificationService.isExactAlarmPermissionGranted();
      final pending = await notificationService.getPendingReminders();

      emit(NotificationLoaded(
        isNotificationGranted: isNotificationGranted,
        isExactAlarmGranted: isExactAlarmGranted,
        pendingCount: pending.length,
      ));
    } catch (e) {
      emit(NotificationError('Lỗi khởi tạo thông báo: ${e.toString()}'));
    }
  }

  Future<void> _onRequestPermission(
    RequestNotificationPermissionEvent event,
    Emitter<NotificationState> emit,
  ) async {
    final current = state;
    if (current is! NotificationLoaded) return;

    try {
      final granted = await notificationService.requestNotificationPermissions();
      final isExactAlarmGranted = await notificationService.isExactAlarmPermissionGranted();

      emit(current.copyWith(
        isNotificationGranted: granted,
        isExactAlarmGranted: isExactAlarmGranted,
        feedbackMessage: granted
            ? AppStrings.notificationPermissionGranted
            : AppStrings.notificationPermissionDenied,
      ));
    } catch (e) {
      emit(current.copyWith(feedbackMessage: 'Lỗi xin quyền: $e'));
    }
  }

  Future<void> _onScheduleRolling(
    ScheduleRollingRemindersEvent event,
    Emitter<NotificationState> emit,
  ) async {
    final current = state;
    if (current is! NotificationLoaded) return;

    emit(const NotificationLoading());
    try {
      final slots = await timetableRepository.watchAllSlots().first;
      final subjects = await timetableRepository.getSubjects();
      final subjectsMap = {for (var s in subjects) s.id: s};

      final lead = event.leadMinutes ?? current.leadMinutes;
      final count = await notificationService.scheduleRollingReminders(
        slots: slots,
        subjectsMap: subjectsMap,
        leadMinutes: lead,
      );

      final pending = await notificationService.getPendingReminders();

      emit(NotificationLoaded(
        isNotificationGranted: current.isNotificationGranted,
        isExactAlarmGranted: current.isExactAlarmGranted,
        leadMinutes: lead,
        pendingCount: pending.length,
        feedbackMessage: 'Đã lên lịch thành công $count ca học trong 7 ngày tới (nhắc trước $lead phút).',
      ));
    } catch (e) {
      emit(NotificationError('Lỗi lên lịch nhắc giờ: ${e.toString()}'));
    }
  }

  Future<void> _onTriggerTest(
    TriggerTestNotificationEvent event,
    Emitter<NotificationState> emit,
  ) async {
    final current = state;
    if (current is! NotificationLoaded) return;

    try {
      await notificationService.showInstantNotification(
        id: 7777,
        title: AppStrings.testNotificationTitle,
        body: AppStrings.testNotificationBody,
      );
      emit(current.copyWith(
        feedbackMessage: 'Đã phát thông báo thử nghiệm thành công!',
      ));
    } catch (e) {
      emit(current.copyWith(feedbackMessage: 'Lỗi phát thông báo: $e'));
    }
  }

  Future<void> _onCancelAll(
    CancelAllRemindersEvent event,
    Emitter<NotificationState> emit,
  ) async {
    final current = state;
    if (current is! NotificationLoaded) return;

    try {
      await notificationService.cancelAllReminders();
      emit(current.copyWith(
        pendingCount: 0,
        feedbackMessage: 'Đã hủy toàn bộ lịch nhắc giờ ca học.',
      ));
    } catch (e) {
      emit(current.copyWith(feedbackMessage: 'Lỗi hủy lịch: $e'));
    }
  }

  void _onChangeLeadMinutes(
    ChangeLeadMinutesEvent event,
    Emitter<NotificationState> emit,
  ) {
    final current = state;
    if (current is! NotificationLoaded) return;

    emit(current.copyWith(
      leadMinutes: event.leadMinutes,
      clearFeedback: true,
    ));
  }
}
