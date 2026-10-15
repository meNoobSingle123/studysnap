import 'package:equatable/equatable.dart';

/// Đại diện cho một lịch nhắc giờ học/thi đã được lên lịch thành công.
class ScheduledReminder extends Equatable {
  final int id;
  final String title;
  final String body;
  final DateTime scheduledTime;
  final String? payload;

  const ScheduledReminder({
    required this.id,
    required this.title,
    required this.body,
    required this.scheduledTime,
    this.payload,
  });

  @override
  List<Object?> get props => [id, title, body, scheduledTime, payload];
}
