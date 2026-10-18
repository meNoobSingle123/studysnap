import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../../../core/l10n/strings.dart';
import '../../../timetable/domain/entities/subject.dart';
import '../../../timetable/domain/entities/timetable_slot.dart';

/// Dịch vụ quản lý Thông báo và Nhắc giờ học tự động (Chủ đề 7).
///
/// Các tính năng cốt lõi:
/// 1. Cấu hình múi giờ chuẩn `Asia/Ho_Chi_Minh` bằng thư viện `timezone`.
/// 2. Lên lịch thông báo chính xác (`exactAllowWhileIdle`) đánh thức máy ở Doze mode.
/// 3. Thuật toán lên lịch cuốn chiếu trong 7 ngày tới, tự động lùi 15 phút trước ca học.
/// 4. Hạn ngạch tối đa 60 thông báo để tránh tràn quota của hệ điều hành Android.
/// 5. Phục hồi lịch báo sau khi khởi động lại máy nhờ `BOOT_COMPLETED` receiver.
class NotificationService {
  final FlutterLocalNotificationsPlugin localNotificationsPlugin;

  static const String channelId = 'studysnap_timetable_channel';
  static const String channelName = AppStrings.reminderChannelName;
  static const String channelDesc = AppStrings.reminderChannelDesc;

  bool _isInitialized = false;

  NotificationService({FlutterLocalNotificationsPlugin? plugin})
      : localNotificationsPlugin = plugin ?? FlutterLocalNotificationsPlugin();

  /// Khởi tạo plugin thông báo và cấu hình múi giờ.
  Future<void> init({bool isTest = false}) async {
    if (_isInitialized) return;

    try {
      tz_data.initializeTimeZones();
      try {
        tz.setLocalLocation(tz.getLocation('Asia/Ho_Chi_Minh'));
      } catch (_) {
        // Fallback sang múi giờ hệ thống nếu không tìm thấy chuỗi
      }
    } catch (_) {
      // Bỏ qua lỗi timezone trong môi trường test thuần
    }

    if (!isTest) {
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwinSettings = DarwinInitializationSettings();
      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
      );

      await localNotificationsPlugin.initialize(settings: initSettings);

      final androidPlugin = localNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        const androidChannel = AndroidNotificationChannel(
          channelId,
          channelName,
          description: channelDesc,
          importance: Importance.high,
        );
        await androidPlugin.createNotificationChannel(androidChannel);
      }
    }

    _isInitialized = true;
  }

  /// Xin quyền hiển thị thông báo (`POST_NOTIFICATIONS` trên Android 13+).
  Future<bool> requestNotificationPermissions() async {
    if (kIsWeb) return true;
    try {
      final status = await Permission.notification.request();
      return status.isGranted;
    } catch (_) {
      return true;
    }
  }

  /// Kiểm tra trạng thái cấp quyền thông báo.
  Future<bool> isNotificationPermissionGranted() async {
    if (kIsWeb) return true;
    try {
      return await Permission.notification.status.isGranted;
    } catch (_) {
      return true;
    }
  }

  /// Kiểm tra quyền đặt báo thức chính xác (`SCHEDULE_EXACT_ALARM` trên Android 12+).
  Future<bool> isExactAlarmPermissionGranted() async {
    if (kIsWeb) return true;
    try {
      return await Permission.scheduleExactAlarm.status.isGranted;
    } catch (_) {
      return true;
    }
  }

  /// Phát thông báo thử nghiệm ngay lập tức.
  Future<void> showInstantNotification({
    int id = 9999,
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDesc,
      importance: Importance.high,
      priority: Priority.high,
    );
    const notificationDetails = NotificationDetails(android: androidDetails);

    try {
      await localNotificationsPlugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: notificationDetails,
        payload: payload,
      );
    } catch (_) {}

  }

  /// Thuật toán Lên lịch nhắc giờ cuốn chiếu trong 7 ngày tới.
  ///
  /// - Tự động lùi [leadMinutes] (mặc định 15 phút) trước giờ bắt đầu của ca học.
  /// - Giới hạn tối đa 60 thông báo để không vượt hạn ngạch của hệ thống.
  /// - Sử dụng cờ `AndroidScheduleMode.exactAllowWhileIdle` để nhắc đúng giờ kể cả khi máy đang ngủ sâu.
  Future<int> scheduleRollingReminders({
    required List<TimetableSlot> slots,
    required Map<String, Subject> subjectsMap,
    int daysAhead = 7,
    int leadMinutes = 15,
    DateTime? currentTime,
  }) async {
    final now = currentTime ?? DateTime.now();
    int scheduledCount = 0;
    const maxRemindersQuota = 60;

    for (int dayOffset = 0; dayOffset < daysAhead; dayOffset++) {
      if (scheduledCount >= maxRemindersQuota) break;

      final targetDate = DateTime(now.year, now.month, now.day).add(Duration(days: dayOffset));
      final dayOfWeek = targetDate.weekday; // 1 = T2 ... 7 = CN

      for (final slot in slots) {
        if (slot.isDeleted) continue;
        if (slot.dayOfWeek != dayOfWeek) continue;

        // Kiểm tra ca học có nằm trong kỳ học không
        if (targetDate.isBefore(slot.termStart) || targetDate.isAfter(slot.termEnd)) {
          continue;
        }

        final slotStartHour = slot.startMin ~/ 60;
        final slotStartMinute = slot.startMin % 60;
        final slotStartDateTime = DateTime(
          targetDate.year,
          targetDate.month,
          targetDate.day,
          slotStartHour,
          slotStartMinute,
        );

        final notificationTime = slotStartDateTime.subtract(Duration(minutes: leadMinutes));
        if (notificationTime.isAfter(now)) {
          final reminderId = ((targetDate.month * 100 + targetDate.day) * 1000 + slot.startMin) & 0x7FFFFFFF;
          final subject = subjectsMap[slot.subjectId];
          final subjectName = subject?.name ?? 'Môn học (${slot.subjectId})';

          final tzScheduledTime = tz.TZDateTime.from(notificationTime, tz.local);

          const androidDetails = AndroidNotificationDetails(
            channelId,
            channelName,
            channelDescription: channelDesc,
            importance: Importance.high,
            priority: Priority.high,
          );
          const notificationDetails = NotificationDetails(android: androidDetails);

          if (!kIsWeb) {
            try {
              await localNotificationsPlugin.zonedSchedule(
                id: reminderId,
                title: 'Sắp đến ca học: $subjectName',
                body: 'Bắt đầu lúc ${slot.startTimeFormatted} tại Phòng ${slot.room}${slot.buildingId != null ? ' (Tòa ${slot.buildingId})' : ''}',
                scheduledDate: tzScheduledTime,
                notificationDetails: notificationDetails,
                androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
                payload: 'studysnap://slot?id=${slot.id}',
              );
            } catch (_) {}
          }

          scheduledCount++;
          if (scheduledCount >= maxRemindersQuota) break;
        }
      }
    }

    return scheduledCount;
  }

  /// Hủy một thông báo nhắc giờ theo ID.
  Future<void> cancelReminder(int id) async {
    try {
      await localNotificationsPlugin.cancel(id: id);
    } catch (_) {}
  }

  /// Hủy toàn bộ các thông báo đã lên lịch.
  Future<void> cancelAllReminders() async {
    try {
      await localNotificationsPlugin.cancelAll();
    } catch (_) {}
  }

  /// Lấy danh sách các thông báo đang chờ phát.
  Future<List<PendingNotificationRequest>> getPendingReminders() async {
    try {
      return await localNotificationsPlugin.pendingNotificationRequests();
    } catch (_) {
      return [];
    }
  }
}
