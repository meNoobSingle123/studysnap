import 'package:hive_ce/hive.dart';
import '../../domain/entities/campus_building.dart';

part 'building_model.g.dart';

@HiveType(typeId: 4)
class CampusBuildingModel extends CampusBuilding {
  const CampusBuildingModel({
    required super.id,
    required super.code,
    required super.name,
    required super.latitude,
    required super.longitude,
  });

  factory CampusBuildingModel.fromEntity(CampusBuilding entity) {
    return CampusBuildingModel(
      id: entity.id,
      code: entity.code,
      name: entity.name,
      latitude: entity.latitude,
      longitude: entity.longitude,
    );
  }

  factory CampusBuildingModel.fromJson(Map<String, dynamic> json) {
    return CampusBuildingModel(
      id: json['id'] as String,
      code: json['code'] as String,
      name: json['name'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'code': code,
        'name': name,
        'latitude': latitude,
        'longitude': longitude,
      };
}
