part of 'statsModel.dart';
class StatsModelAdapter extends TypeAdapter<StatsModel> {
  @override
  final int typeId = 1;
  @override
  StatsModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return StatsModel(
      bestScore: fields[0] as int,
      currentStreak: fields[1] as int,
      lastPracticeDate: fields[2] as DateTime,
      learnedSigns: (fields[3] as List).cast<String>(),
    );
  }
  @override
  void write(BinaryWriter writer, StatsModel obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.bestScore)
      ..writeByte(1)
      ..write(obj.currentStreak)
      ..writeByte(2)
      ..write(obj.lastPracticeDate)
      ..writeByte(3)
      ..write(obj.learnedSigns);
  }
  @override
  int get hashCode => typeId.hashCode;
  @override
  bool operator ==(Object other) => identical(this, other) || other is StatsModelAdapter && runtimeType == other.runtimeType && typeId == other.typeId;
}