import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path/path.dart' as p;
import 'package:trackerfield/models/athlete.dart';
import 'package:trackerfield/models/bloc.dart';
import 'package:trackerfield/models/chrono_athlete.dart';
import 'package:trackerfield/models/competition.dart';
import 'package:trackerfield/models/exercice.dart';
import 'package:trackerfield/models/seance.dart';
import 'package:trackerfield/models/test_performance.dart';
import 'package:trackerfield/services/database_service.dart';
import 'package:trackerfield/services/export_service.dart';
import 'package:trackerfield/services/import_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late DatabaseService exportDb;
  late DatabaseService importDb;
  late String exportPath;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('trackerfield_excel_');
    exportPath = p.join(tempDir.path, 'export.xlsx');

    final exportHiveDir = Directory(p.join(tempDir.path, 'export_hive'));
    await exportHiveDir.create();
    exportDb = DatabaseService();
    await exportDb.init(path: exportHiveDir.path);

    final athlete = Athlete(
      nom: 'Alice Sprint',
      numeroLicence: 'LIC-001',
      dateNaissance: DateTime(2005, 3, 15),
      detteGateau: 2,
    );
    await exportDb.addAthlete(athlete);

    await exportDb.addSeance(
      Seance(
        titre: 'Fractionné 200',
        date: DateTime(2026, 8, 20),
        athleteIds: [athlete.id],
        blocs: [
          Bloc(
            nom: 'Bloc A',
            tempsRecuperation: '3:00',
            exercices: [
              Exercice(
                type: 'Course',
                distance: '200',
                tempsRecuperation: '1:30',
                notes: 'Vent de face',
                mediaPaths: const ['medias/absent.jpg'],
                chronos: [
                  ChronoAthlete(athleteId: athlete.id, chrono: '24,85'),
                ],
              ),
            ],
          ),
        ],
      ),
    );

    await exportDb.addSeance(
      Seance(
        titre: 'Modèle VMA',
        date: DateTime(2026, 1, 1),
        isTemplate: true,
        blocs: [
          Bloc(
            nom: 'Échauffement',
            exercices: [
              Exercice(
                type: 'Muscu',
                nom: 'Gainage',
                tempsRecuperation: '0:45',
              ),
            ],
          ),
        ],
      ),
    );

    await exportDb.addSeance(
      Seance(
        titre: 'Séance planifiée',
        date: DateTime(2026, 8, 21),
        estPlanifiee: true,
        datePrevue: DateTime(2026, 8, 25),
        athleteIds: [athlete.id],
        blocs: const [],
      ),
    );

    await exportDb.addCompetition(
      Competition(
        titre: 'Meeting régional',
        dateDebut: DateTime(2026, 9, 1),
        dateFin: DateTime(2026, 9, 2),
        lieu: 'Stade municipal',
        athleteIds: [athlete.id],
      ),
    );

    await exportDb.addTest(
      TestPerformance(
        athleteId: athlete.id,
        date: DateTime(2026, 7, 10),
        typeTest: 'CMJ',
        resultat: 42.5,
        unite: 'cm',
      ),
    );

    await ExportService(exportDb).writeToFile(exportPath);
    await Hive.close();

    final importHiveDir = Directory(p.join(tempDir.path, 'import_hive'));
    await importHiveDir.create();
    importDb = DatabaseService();
    await importDb.init(path: importHiveDir.path);
  });

  tearDown(() async {
    await Hive.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('export puis import conserve toutes les données structurées', () async {
    final summary = await ImportService(importDb).importFromFile(exportPath);

    expect(summary.athletesCreated, 1);
    expect(summary.seancesImported, 3);
    expect(summary.competitionsImported, 1);
    expect(summary.testsImported, 1);

    final athletes = importDb.getAthletes();
    expect(athletes, hasLength(1));
    expect(athletes.first.nom, 'Alice Sprint');
    expect(athletes.first.numeroLicence, 'LIC-001');
    expect(athletes.first.detteGateau, 2);
    expect(athletes.first.dateNaissance, DateTime(2005, 3, 15));
    expect(athletes.first.photoPath, isNull);

    final seances = importDb.getSeances();
    expect(seances, hasLength(1));
    expect(seances.first.titre, 'Fractionné 200');
    expect(seances.first.blocs, hasLength(1));
    final exercice = seances.first.blocs.first.exercices.single;
    expect(exercice.distance, '200');
    expect(exercice.tempsRecuperation, '1:30');
    expect(exercice.notes, 'Vent de face');
    expect(exercice.chronos.single.chrono, '24,85');
    // Média absent du disque → non importé.
    expect(exercice.mediaPaths, isEmpty);

    final templates = importDb.getTemplates();
    expect(templates, hasLength(1));
    expect(templates.first.titre, 'Modèle VMA');
    expect(templates.first.blocs.first.exercices.single.nom, 'Gainage');

    final planifiees = importDb.getPlanifiees();
    expect(planifiees, hasLength(1));
    expect(planifiees.first.titre, 'Séance planifiée');
    expect(planifiees.first.datePrevue, DateTime(2026, 8, 25));

    final competitions = importDb.getCompetitions();
    expect(competitions, hasLength(1));
    expect(competitions.first.titre, 'Meeting régional');
    expect(competitions.first.lieu, 'Stade municipal');
    expect(competitions.first.dateDebut, DateTime(2026, 9, 1));
    expect(competitions.first.dateFin, DateTime(2026, 9, 2));
    expect(competitions.first.athleteIds, [athletes.first.id]);

    final tests = importDb.getAllTests();
    expect(tests, hasLength(1));
    expect(tests.first.typeTest, 'CMJ');
    expect(tests.first.resultat, 42.5);
    expect(tests.first.unite, 'cm');
  });
}
