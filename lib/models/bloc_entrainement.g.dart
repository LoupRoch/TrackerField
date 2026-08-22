// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bloc_entrainement.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class BlocEntrainementAdapter extends TypeAdapter<BlocEntrainement> {
  @override
  final int typeId = 5;

  @override
  BlocEntrainement read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return BlocEntrainement(
      id: fields[0] as String?,
      typeBloc: fields[1] as String,
      nomExercice: fields[2] as String?,
      distance: fields[3] as String?,
      tempsRecuperation: fields[4] as String,
      notes: fields[5] as String,
      mediaPaths: (fields[6] as List?)?.cast<String>(),
      chronos: (fields[7] as List?)?.cast<ChronoAthlete>(),
    );
  }

  @override
  void write(BinaryWriter writer, BlocEntrainement obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.typeBloc)
      ..writeByte(2)
      ..write(obj.nomExercice)
      ..writeByte(3)
      ..write(obj.distance)
      ..writeByte(4)
      ..write(obj.tempsRecuperation)
      ..writeByte(5)
      ..write(obj.notes)
      ..writeByte(6)
      ..write(obj.mediaPaths)
      ..writeByte(7)
      ..write(obj.chronos);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BlocEntrainementAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
