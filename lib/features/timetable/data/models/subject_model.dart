import 'package:hive_ce/hive.dart';
import '../../domain/entities/subject.dart';

part 'subject_model.g.dart';

@HiveType(typeId: 1)
class SubjectModel extends Subject {
  const SubjectModel({
    required super.id,
    required super.code,
    required super.name,
    required super.credits,
    required super.colorArgb,
    required super.createdAt,
    required super.updatedAt,
    super.deletedAt,
  });

  factory SubjectModel.fromEntity(Subject entity) {
    return SubjectModel(
      id: entity.id,
      code: entity.code,
      name: entity.name,
      credits: entity.credits,
      colorArgb: entity.colorArgb,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
      deletedAt: entity.deletedAt,
    );
  }

  factory SubjectModel.fromJson(Map<String, dynamic> json) {
    return SubjectModel(
      id: json['id'] as String,
      code: json['code'] as String,
      name: json['name'] as String,
      credits: json['credits'] as int,
      colorArgb: json['colorArgb'] as int? ?? 0xFF1E56A0,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
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
        'code': code,
        'name': name,
        'credits': credits,
        'colorArgb': colorArgb,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'deletedAt': deletedAt?.toIso8601String(),
      };
}
