part of 'slot_model.dart';

class TimetableSlotModelAdapter extends TypeAdapter<TimetableSlotModel> {
  @override
  final int typeId = 2;

  @override
  TimetableSlotModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TimetableSlotModel(
      id: fields[0] as String,
      subjectId: fields[1] as String,
      dayOfWeek: (fields[2] as num).toInt(),
      startMin: (fields[3] as num).toInt(),
      endMin: (fields[4] as num).toInt(),
      room: fields[5] as String,
      buildingId: fields[6] as String?,
      termStart: fields[7] as DateTime,
      termEnd: fields[8] as DateTime,
      source: fields[9] as String,
      updatedAt: fields[10] as DateTime,
      deletedAt: fields[11] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, TimetableSlotModel obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.subjectId)
      ..writeByte(2)
      ..write(obj.dayOfWeek)
      ..writeByte(3)
      ..write(obj.startMin)
      ..writeByte(4)
      ..write(obj.endMin)
      ..writeByte(5)
      ..write(obj.room)
      ..writeByte(6)
      ..write(obj.buildingId)
      ..writeByte(7)
      ..write(obj.termStart)
      ..writeByte(8)
      ..write(obj.termEnd)
      ..writeByte(9)
      ..write(obj.source)
      ..writeByte(10)
      ..write(obj.updatedAt)
      ..writeByte(11)
      ..write(obj.deletedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TimetableSlotModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
