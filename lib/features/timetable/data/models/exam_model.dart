import 'package:hive_ce/hive.dart';
import '../../domain/entities/exam_schedule.dart';

part 'exam_model.g.dart';

@HiveType(typeId: 3)
class ExamScheduleModel extends ExamSchedule {
  const ExamScheduleModel({
    required super.id,
    required super.subjectId,
    required super.date,
    required super.startMin,
    required super.durationMin,
    required super.room,
    super.buildingId,
    required super.source,
  });

  factory ExamScheduleModel.fromEntity(ExamSchedule entity) {
    return ExamScheduleModel(
      id: entity.id,
      subjectId: entity.subjectId,
      date: entity.date,
      startMin: entity.startMin,
      durationMin: entity.durationMin,
      room: entity.room,
      buildingId: entity.buildingId,
      source: entity.source,
    );
  }

  factory ExamScheduleModel.fromJson(Map<String, dynamic> json) {
    return ExamScheduleModel(
      id: json['id'] as String,
      subjectId: json['subjectId'] as String,
      date: DateTime.parse(json['date'] as String),
      startMin: json['startMin'] as int,
      durationMin: json['durationMin'] as int,
      room: json['room'] as String,
      buildingId: json['buildingId'] as String?,
      source: json['source'] as String? ?? 'system',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'subjectId': subjectId,
        'date': date.toIso8601String(),
        'startMin': startMin,
        'durationMin': durationMin,
        'room': room,
        'buildingId': buildingId,
        'source': source,
      };
}
