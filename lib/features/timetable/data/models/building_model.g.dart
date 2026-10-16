part of 'building_model.dart';

class CampusBuildingModelAdapter extends TypeAdapter<CampusBuildingModel> {
  @override
  final int typeId = 4;

  @override
  CampusBuildingModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CampusBuildingModel(
      id: fields[0] as String,
      code: fields[1] as String,
      name: fields[2] as String,
      latitude: (fields[3] as num).toDouble(),
      longitude: (fields[4] as num).toDouble(),
    );
  }

  @override
  void write(BinaryWriter writer, CampusBuildingModel obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.code)
      ..writeByte(2)
      ..write(obj.name)
      ..writeByte(3)
      ..write(obj.latitude)
      ..writeByte(4)
      ..write(obj.longitude);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CampusBuildingModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
