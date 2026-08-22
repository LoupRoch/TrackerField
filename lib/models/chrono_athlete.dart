import 'package:hive_flutter/hive_flutter.dart';

part 'chrono_athlete.g.dart';

@HiveType(typeId: 3)
class ChronoAthlete extends HiveObject {
  @HiveField(0)
  String athleteId;

  @HiveField(1)
  String chrono;

  ChronoAthlete({
    required this.athleteId,
    required this.chrono,
  });
}
