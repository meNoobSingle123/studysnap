import 'package:equatable/equatable.dart';

enum DeadlinePriority { low, medium, high }

/// Thực thể Hạn nộp bài / Deadline môn học - Domain Layer.
class AssignmentDeadline extends Equatable {
  final String id;
  final String subjectId;
  final String title;
  final String? description;
  final DateTime dueDate;
  final bool isCompleted;
  final DeadlinePriority priority;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AssignmentDeadline({
    required this.id,
    required this.subjectId,
    required this.title,
    this.description,
    required this.dueDate,
    this.isCompleted = false,
    this.priority = DeadlinePriority.medium,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Kiểm tra xem bài tập đã quá hạn nộp chưa.
  bool get isOverdue => !isCompleted && dueDate.isBefore(DateTime.now());

  /// Số ngày còn lại đến hạn nộp bài.
  int get daysRemaining {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(dueDate.year, dueDate.month, dueDate.day);
    return target.difference(today).inDays;
  }

  AssignmentDeadline copyWith({
    String? id,
    String? subjectId,
    String? title,
    String? description,
    DateTime? dueDate,
    bool? isCompleted,
    DeadlinePriority? priority,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AssignmentDeadline(
      id: id ?? this.id,
      subjectId: subjectId ?? this.subjectId,
      title: title ?? this.title,
      description: description ?? this.description,
      dueDate: dueDate ?? this.dueDate,
      isCompleted: isCompleted ?? this.isCompleted,
      priority: priority ?? this.priority,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        subjectId,
        title,
        description,
        dueDate,
        isCompleted,
        priority,
        createdAt,
        updatedAt,
      ];
}

