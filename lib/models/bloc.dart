import 'package:hive_flutter/hive_flutter.dart';

import 'exercice.dart';

part 'bloc.g.dart';

@HiveType(typeId: 7)
class Bloc extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  String nom;

  @HiveField(2)
  String tempsRecuperation;

  @HiveField(3)
  List<Exercice> exercices;

  Bloc({
    String? id,
    required this.nom,
    this.tempsRecuperation = '',
    List<Exercice>? exercices,
  })  : id = id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        exercices = exercices ?? [];

  String get titreAffiche {
    final recup = tempsRecuperation.isNotEmpty
        ? ' · Récup $tempsRecuperation'
        : '';
    return '$nom$recup';
  }

  Bloc copy({bool asNew = false}) => Bloc(
        id: asNew ? null : id,
        nom: nom,
        tempsRecuperation: tempsRecuperation,
        exercices: exercices.map((e) => e.copy(asNew: asNew)).toList(),
      );
}
