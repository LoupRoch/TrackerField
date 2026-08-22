import 'package:hive_flutter/hive_flutter.dart';

part 'test_performance.g.dart';

@HiveType(typeId: 4)
class TestPerformance extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  String athleteId;

  @HiveField(2)
  DateTime date;

  @HiveField(3)
  String typeTest;

  @HiveField(4)
  double resultat;

  @HiveField(5)
  String unite;

  TestPerformance({
    String? id,
    required this.athleteId,
    DateTime? date,
    required this.typeTest,
    required this.resultat,
    required this.unite,
  })  : id = id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        date = date ?? DateTime.now();

  static const types = ['VMA', 'Pentabond', 'Décabond', 'Souplesse'];

  static String unitePour(String typeTest) {
    switch (typeTest) {
      case 'VMA':
        return 'km/h';
      case 'Pentabond':
      case 'Décabond':
        return 'm';
      case 'Souplesse':
        return 'cm';
      default:
        return '';
    }
  }
}
