import 'package:equatable/equatable.dart';

abstract class NotificationState extends Equatable {
  const NotificationState();

  @override
  List<Object?> get props => [];
}

class NotificationInitial extends NotificationState {
  const NotificationInitial();
}

class NotificationLoading extends NotificationState {
  const NotificationLoading();
}

class NotificationLoaded extends NotificationState {
  final bool isNotificationGranted;
  final bool isExactAlarmGranted;
  final int leadMinutes;
  final int pendingCount;
  final String? feedbackMessage;

  const NotificationLoaded({
    required this.isNotificationGranted,
    required this.isExactAlarmGranted,
    this.leadMinutes = 15,
    this.pendingCount = 0,
    this.feedbackMessage,
  });

  NotificationLoaded copyWith({
    bool? isNotificationGranted,
    bool? isExactAlarmGranted,
    int? leadMinutes,
    int? pendingCount,
    String? feedbackMessage,
    bool clearFeedback = false,
  }) {
    return NotificationLoaded(
      isNotificationGranted: isNotificationGranted ?? this.isNotificationGranted,
      isExactAlarmGranted: isExactAlarmGranted ?? this.isExactAlarmGranted,
      leadMinutes: leadMinutes ?? this.leadMinutes,
      pendingCount: pendingCount ?? this.pendingCount,
      feedbackMessage: clearFeedback ? null : (feedbackMessage ?? this.feedbackMessage),
    );
  }

  @override
  List<Object?> get props => [
        isNotificationGranted,
        isExactAlarmGranted,
        leadMinutes,
        pendingCount,
        feedbackMessage,
      ];
}

class NotificationError extends NotificationState {
  final String message;

  const NotificationError(this.message);

  @override
  List<Object?> get props => [message];
}
