// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'test_performance.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TestPerformanceAdapter extends TypeAdapter<TestPerformance> {
  @override
  final int typeId = 4;

  @override
  TestPerformance read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TestPerformance(
      id: fields[0] as String?,
      athleteId: fields[1] as String,
      date: fields[2] as DateTime?,
      typeTest: fields[3] as String,
      resultat: fields[4] as double,
      unite: fields[5] as String,
    );
  }

  @override
  void write(BinaryWriter writer, TestPerformance obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.athleteId)
      ..writeByte(2)
      ..write(obj.date)
      ..writeByte(3)
      ..write(obj.typeTest)
      ..writeByte(4)
      ..write(obj.resultat)
      ..writeByte(5)
      ..write(obj.unite);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TestPerformanceAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
