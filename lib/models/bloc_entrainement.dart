import 'package:hive_flutter/hive_flutter.dart';

import 'chrono_athlete.dart';

part 'bloc_entrainement.g.dart';

@HiveType(typeId: 5)
class BlocEntrainement extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  String typeBloc;

  @HiveField(2)
  String? nomExercice;

  /// Distance de la course (ex: 200m). Null pour muscu/saut.
  @HiveField(3)
  String? distance;

  @HiveField(4)
  String tempsRecuperation;

  @HiveField(5)
  String notes;

  @HiveField(6)
  List<String> mediaPaths;

  /// Chronos par athlète (blocs Course uniquement).
  @HiveField(7)
  List<ChronoAthlete> chronos;

  BlocEntrainement({
    String? id,
    required this.typeBloc,
    this.nomExercice,
    this.distance,
    required this.tempsRecuperation,
    this.notes = '',
    List<String>? mediaPaths,
    List<ChronoAthlete>? chronos,
  })  : id = id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        mediaPaths = mediaPaths ?? [],
        chronos = chronos ?? [];

  static const types = ['Course', 'Musculation', 'Saut'];

  bool get isCourse => typeBloc == 'Course';

  String get titreAffiche {
    if (isCourse) {
      final dist = distance?.isNotEmpty == true ? distance! : '—';
      return 'Course · $dist · Récup $tempsRecuperation';
    }
    final exo = nomExercice?.isNotEmpty == true ? nomExercice! : typeBloc;
    return '$typeBloc · $exo · Récup $tempsRecuperation';
  }

  BlocEntrainement copy() => BlocEntrainement(
        id: id,
        typeBloc: typeBloc,
        nomExercice: nomExercice,
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
