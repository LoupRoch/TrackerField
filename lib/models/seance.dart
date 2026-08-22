import 'package:hive_flutter/hive_flutter.dart';

import 'bloc_entrainement.dart';

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
  List<BlocEntrainement> blocs;

  Seance({
    String? id,
    required this.titre,
    DateTime? date,
    List<String>? athleteIds,
    List<BlocEntrainement>? blocs,
  })  : id = id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        date = date ?? DateTime.now(),
        athleteIds = athleteIds ?? [],
        blocs = blocs ?? [];
}
