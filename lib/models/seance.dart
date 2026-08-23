import 'package:hive_flutter/hive_flutter.dart';

import 'bloc.dart';

part 'seance.g.dart';

@HiveType(typeId: 2)
class Seance extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  String titre;

  @HiveField(2)
  DateTime date;

  @HiveField(3)
  List<String> athleteIds;

  @HiveField(4)
  List<Bloc> blocs;

  @HiveField(5, defaultValue: false)
  bool isTemplate;

  @HiveField(6, defaultValue: false)
  bool estPlanifiee;

  @HiveField(7)
  DateTime? datePrevue;

  Seance({
    String? id,
    required this.titre,
    DateTime? date,
    List<String>? athleteIds,
    List<Bloc>? blocs,
    this.isTemplate = false,
    this.estPlanifiee = false,
    this.datePrevue,
  })  : id = id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        date = date ?? DateTime.now(),
        athleteIds = athleteIds ?? [],
        blocs = blocs ?? [];
}
