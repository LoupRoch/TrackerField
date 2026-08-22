// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chrono_athlete.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ChronoAthleteAdapter extends TypeAdapter<ChronoAthlete> {
  @override
  final int typeId = 3;

  @override
  ChronoAthlete read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ChronoAthlete(
      athleteId: fields[0] as String,
      chrono: fields[1] as String,
    );
  }

  @override
  void write(BinaryWriter writer, ChronoAthlete obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.athleteId)
      ..writeByte(1)
      ..write(obj.chrono);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChronoAthleteAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
