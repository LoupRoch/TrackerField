// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'seance.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SeanceAdapter extends TypeAdapter<Seance> {
  @override
  final int typeId = 2;

  @override
  Seance read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Seance(
      id: fields[0] as String?,
      titre: fields[1] as String,
      date: fields[2] as DateTime?,
      athleteIds: (fields[3] as List?)?.cast<String>(),
      blocs: (fields[4] as List?)?.cast<BlocEntrainement>(),
    );
  }

  @override
  void write(BinaryWriter writer, Seance obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.titre)
      ..writeByte(2)
      ..write(obj.date)
      ..writeByte(3)
      ..write(obj.athleteIds)
      ..writeByte(4)
      ..write(obj.blocs);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SeanceAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
