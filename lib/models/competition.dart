import 'package:hive_flutter/hive_flutter.dart';

part 'competition.g.dart';

@HiveType(typeId: 8)
class Competition extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  String titre;

  @HiveField(2)
  DateTime dateDebut;

  @HiveField(3)
  DateTime dateFin;

  @HiveField(4)
  String lieu;

  @HiveField(5)
  List<String> athleteIds;

  Competition({
    String? id,
    required this.titre,
    required this.dateDebut,
    required this.dateFin,
    this.lieu = '',
    List<String>? athleteIds,
  })  : id = id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        athleteIds = athleteIds ?? [];

  bool coversDay(DateTime day) {
    final key = DateTime(day.year, day.month, day.day);
    final start = DateTime(dateDebut.year, dateDebut.month, dateDebut.day);
    final end = DateTime(dateFin.year, dateFin.month, dateFin.day);
    return !key.isBefore(start) && !key.isAfter(end);
  }
}
