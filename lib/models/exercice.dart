import 'package:hive_flutter/hive_flutter.dart';

import 'chrono_athlete.dart';

part 'exercice.g.dart';

@HiveType(typeId: 6)
class Exercice extends HiveObject {
  @HiveField(0)
  final String id;

  /// Course, Muscu ou Saut.
  @HiveField(1)
  String type;

  /// Nom de l'exercice (Muscu / Saut).
  @HiveField(2)
  String? nom;

  /// Distance de course (ex: 200m).
  @HiveField(3)
  String? distance;

  @HiveField(4)
  String tempsRecuperation;

  @HiveField(5)
  String notes;

  @HiveField(6)
  List<String> mediaPaths;

  /// Chronos par athlète (Course uniquement).
  @HiveField(7)
  List<ChronoAthlete> chronos;

  Exercice({
    String? id,
    required this.type,
    this.nom,
    this.distance,
    required this.tempsRecuperation,
    this.notes = '',
    List<String>? mediaPaths,
    List<ChronoAthlete>? chronos,
  })  : id = id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        mediaPaths = mediaPaths ?? [],
        chronos = chronos ?? [];

  static const types = ['Course', 'Muscu', 'Saut'];

  bool get isCourse => type == 'Course';

  String get titreAffiche {
    if (isCourse) {
      final dist = distance?.isNotEmpty == true ? distance! : '—';
      return 'Course · $dist · Récup $tempsRecuperation';
    }
    final exo = nom?.isNotEmpty == true ? nom! : type;
    return '$type · $exo · Récup $tempsRecuperation';
  }

  Exercice copy({bool asNew = false}) => Exercice(
        id: asNew ? null : id,
        type: type,
        nom: nom,
        distance: distance,
        tempsRecuperation: tempsRecuperation,
        notes: notes,
        mediaPaths: List<String>.from(mediaPaths),
        chronos: chronos
            .map(
              (c) => ChronoAthlete(
                athleteId: c.athleteId,
                chrono: c.chrono,
              ),
            )
            .toList(),
      );
}
