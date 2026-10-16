import 'package:equatable/equatable.dart';

abstract class NotificationEvent extends Equatable {
  const NotificationEvent();

  @override
  List<Object?> get props => [];
}

/// Khởi tạo trạng thái quyền và nạp danh sách thông báo đang chờ.
class InitNotificationEvent extends NotificationEvent {
  const InitNotificationEvent();
}

/// Yêu cầu người dùng cấp quyền thông báo hệ thống.
class RequestNotificationPermissionEvent extends NotificationEvent {
  const RequestNotificationPermissionEvent();
}

/// Thực hiện lên lịch nhắc cuốn chiếu 7 ngày tới.
class ScheduleRollingRemindersEvent extends NotificationEvent {
  final int? leadMinutes;

  const ScheduleRollingRemindersEvent({this.leadMinutes});

  @override
  List<Object?> get props => [leadMinutes];
}

/// Kích hoạt một thông báo thử nghiệm ngay lập tức.
class TriggerTestNotificationEvent extends NotificationEvent {
  const TriggerTestNotificationEvent();
}

/// Hủy toàn bộ thông báo đang chờ phát.
class CancelAllRemindersEvent extends NotificationEvent {
  const CancelAllRemindersEvent();
}

/// Đổi thời gian nhắc trước giờ học (5, 10, 15, 30 phút).
class ChangeLeadMinutesEvent extends NotificationEvent {
  final int leadMinutes;

  const ChangeLeadMinutesEvent(this.leadMinutes);

  @override
  List<Object?> get props => [leadMinutes];
}
