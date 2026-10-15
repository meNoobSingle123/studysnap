import 'package:hive_ce/hive.dart';
import '../../domain/entities/timetable_slot.dart';

part 'slot_model.g.dart';

@HiveType(typeId: 2)
class TimetableSlotModel extends TimetableSlot {
  const TimetableSlotModel({
    required super.id,
    required super.subjectId,
    required super.dayOfWeek,
    required super.startMin,
    required super.endMin,
    required super.room,
    super.buildingId,
    required super.termStart,
    required super.termEnd,
    required super.source,
    required super.updatedAt,
    super.deletedAt,
  });

  factory TimetableSlotModel.fromEntity(TimetableSlot entity) {
    return TimetableSlotModel(
      id: entity.id,
      subjectId: entity.subjectId,
      dayOfWeek: entity.dayOfWeek,
      startMin: entity.startMin,
      endMin: entity.endMin,
      room: entity.room,
      buildingId: entity.buildingId,
      termStart: entity.termStart,
      termEnd: entity.termEnd,
      source: entity.source,
      updatedAt: entity.updatedAt,
      deletedAt: entity.deletedAt,
    );
  }

  factory TimetableSlotModel.fromJson(Map<String, dynamic> json) {
    return TimetableSlotModel(
      id: json['id'] as String,
      subjectId: json['subjectId'] as String,
      dayOfWeek: json['dayOfWeek'] as int,
      startMin: json['startMin'] as int,
      endMin: json['endMin'] as int,
      room: json['room'] as String,
      buildingId: json['buildingId'] as String?,
      termStart: json['termStart'] != null
          ? DateTime.parse(json['termStart'] as String)
          : DateTime(2026, 10, 19),
      termEnd: json['termEnd'] != null
          ? DateTime.parse(json['termEnd'] as String)
          : DateTime(2027, 1, 10),
      source: json['source'] as String? ?? 'system',
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : DateTime.now(),
      deletedAt: json['deletedAt'] != null
          ? DateTime.parse(json['deletedAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'subjectId': subjectId,
        'dayOfWeek': dayOfWeek,
        'startMin': startMin,
        'endMin': endMin,
        'room': room,
        'buildingId': buildingId,
        'termStart': termStart.toIso8601String(),
        'termEnd': termEnd.toIso8601String(),
        'source': source,
        'updatedAt': updatedAt.toIso8601String(),
        'deletedAt': deletedAt?.toIso8601String(),
      };
}
