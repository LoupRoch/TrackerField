// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'athlete.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AthleteAdapter extends TypeAdapter<Athlete> {
  @override
  final int typeId = 0;

  @override
  Athlete read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Athlete(
      id: fields[0] as String?,
      nom: fields[1] as String,
      numeroLicence: fields[2] as String,
      dateNaissance: fields[3] as DateTime,
      detteGateau: fields[4] as int,
      photoPath: fields[5] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Athlete obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.nom)
      ..writeByte(2)
      ..write(obj.numeroLicence)
      ..writeByte(3)
      ..write(obj.dateNaissance)
      ..writeByte(4)
      ..write(obj.detteGateau)
      ..writeByte(5)
      ..write(obj.photoPath);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AthleteAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
