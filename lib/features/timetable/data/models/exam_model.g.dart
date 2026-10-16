part of 'exam_model.dart';

class ExamScheduleModelAdapter extends TypeAdapter<ExamScheduleModel> {
  @override
  final int typeId = 3;

  @override
  ExamScheduleModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ExamScheduleModel(
      id: fields[0] as String,
      subjectId: fields[1] as String,
      date: fields[2] as DateTime,
      startMin: (fields[3] as num).toInt(),
      durationMin: (fields[4] as num).toInt(),
      room: fields[5] as String,
      buildingId: fields[6] as String?,
      source: fields[7] as String,
    );
  }

  @override
  void write(BinaryWriter writer, ExamScheduleModel obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.subjectId)
      ..writeByte(2)
      ..write(obj.date)
      ..writeByte(3)
      ..write(obj.startMin)
      ..writeByte(4)
      ..write(obj.durationMin)
      ..writeByte(5)
      ..write(obj.room)
      ..writeByte(6)
      ..write(obj.buildingId)
      ..writeByte(7)
      ..write(obj.source);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExamScheduleModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
