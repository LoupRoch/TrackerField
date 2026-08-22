import 'package:hive_flutter/hive_flutter.dart';

part 'athlete.g.dart';

@HiveType(typeId: 0)
class Athlete extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  String nom;

  @HiveField(2)
  String numeroLicence;

  @HiveField(3)
  DateTime dateNaissance;

  @HiveField(4)
  int detteGateau;

  @HiveField(5)
  String? photoPath;

  Athlete({
    String? id,
    required this.nom,
    required this.numeroLicence,
    required this.dateNaissance,
    this.detteGateau = 0,
    this.photoPath,
  }) : id = id ?? DateTime.now().microsecondsSinceEpoch.toString();
}
