import 'dart:io';

import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/athlete.dart';
import 'database_service.dart';

class ExportService {
  ExportService(this._databaseService);

  final DatabaseService _databaseService;

  Future<void> exporterDonnees() async {
    await _databaseService.ensureReady();

    final excel = Excel.createExcel();
    final defaultSheet = excel.getDefaultSheet();
    if (defaultSheet != null) {
      excel.rename(defaultSheet, 'Athlètes');
    }

    final athletesSheet = excel['Athlètes'];
    athletesSheet.appendRow([
      TextCellValue('Nom'),
      TextCellValue('Licence'),
      TextCellValue('Age'),
      TextCellValue('Dette Gâteau'),
    ]);

    final athletesById = {
      for (final athlete in _databaseService.getAthletes()) athlete.id: athlete,
    };

    for (final athlete in athletesById.values) {
      athletesSheet.appendRow([
        TextCellValue(athlete.nom),
        TextCellValue(athlete.numeroLicence),
        IntCellValue(_ageOf(athlete)),
        IntCellValue(athlete.detteGateau),
      ]);
    }

    final seancesSheet = excel['Séances'];
    seancesSheet.appendRow([
      TextCellValue('Titre Séance'),
      TextCellValue('Date'),
      TextCellValue('Nom du Bloc'),
      TextCellValue('Récup Bloc'),
      TextCellValue('Type Exercice'),
      TextCellValue('Distance / Nom'),
      TextCellValue('Temps récupération'),
      TextCellValue('Notes'),
      TextCellValue('Médias'),
      TextCellValue('Chronos'),
      TextCellValue('Athlètes'),
    ]);

    for (final seance in _databaseService.getSeances()) {
      final dateLabel =
          '${seance.date.day.toString().padLeft(2, '0')}/'
          '${seance.date.month.toString().padLeft(2, '0')}/'
          '${seance.date.year}';
      final athleteNames = seance.athleteIds
          .map((id) => athletesById[id]?.nom ?? id)
          .join(', ');

      if (seance.blocs.isEmpty) {
        seancesSheet.appendRow([
          TextCellValue(seance.titre),
          TextCellValue(dateLabel),
          TextCellValue(''),
          TextCellValue(''),
          TextCellValue(''),
          TextCellValue(''),
          TextCellValue(''),
          TextCellValue(''),
          TextCellValue(''),
          TextCellValue(''),
          TextCellValue(athleteNames),
        ]);
        continue;
      }

      for (final bloc in seance.blocs) {
        if (bloc.exercices.isEmpty) {
          seancesSheet.appendRow([
            TextCellValue(seance.titre),
            TextCellValue(dateLabel),
            TextCellValue(bloc.nom),
            TextCellValue(bloc.tempsRecuperation),
            TextCellValue(''),
            TextCellValue(''),
            TextCellValue(''),
            TextCellValue(''),
            TextCellValue(''),
            TextCellValue(''),
            TextCellValue(athleteNames),
          ]);
          continue;
        }

        for (final exercice in bloc.exercices) {
          final label = exercice.isCourse
              ? (exercice.distance ?? '')
              : (exercice.nom ?? '');
          final chronosLabel = exercice.chronos
              .map((c) {
                final name = athletesById[c.athleteId]?.nom ?? c.athleteId;
                return '$name: ${c.chrono}';
              })
              .join(' | ');

          seancesSheet.appendRow([
            TextCellValue(seance.titre),
            TextCellValue(dateLabel),
            TextCellValue(bloc.nom),
            TextCellValue(bloc.tempsRecuperation),
            TextCellValue(exercice.type),
            TextCellValue(label),
            TextCellValue(exercice.tempsRecuperation),
            TextCellValue(exercice.notes),
            IntCellValue(exercice.mediaPaths.length),
            TextCellValue(chronosLabel),
            TextCellValue(athleteNames),
          ]);
        }
      }
    }

    final testsSheet = excel['Tests Performances'];
    testsSheet.appendRow([
      TextCellValue('Nom de l\'athlète'),
      TextCellValue('Date'),
      TextCellValue('Type de Test'),
      TextCellValue('Résultat'),
      TextCellValue('Unité'),
    ]);

    for (final test in _databaseService.getAllTests()) {
      final athleteName =
          athletesById[test.athleteId]?.nom ?? test.athleteId;
      final dateLabel =
          '${test.date.day.toString().padLeft(2, '0')}/'
          '${test.date.month.toString().padLeft(2, '0')}/'
          '${test.date.year}';

      testsSheet.appendRow([
        TextCellValue(athleteName),
        TextCellValue(dateLabel),
        TextCellValue(test.typeTest),
        DoubleCellValue(test.resultat),
        TextCellValue(test.unite),
      ]);
    }

    final bytes = excel.encode();
    if (bytes == null) {
      throw StateError('Impossible de générer le fichier Excel.');
    }

    final tempDir = await getTemporaryDirectory();
    final file = File(
      '${tempDir.path}/trackerfield_export_${DateTime.now().millisecondsSinceEpoch}.xlsx',
    );
    await file.writeAsBytes(bytes, flush: true);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        text: 'Export TrackerField',
        subject: 'Export TrackerField',
      ),
    );
  }

  int _ageOf(Athlete athlete) {
    final now = DateTime.now();
    var age = now.year - athlete.dateNaissance.year;
    final hadBirthday = now.month > athlete.dateNaissance.month ||
        (now.month == athlete.dateNaissance.month &&
            now.day >= athlete.dateNaissance.day);
    if (!hadBirthday) age--;
    return age;
  }
}
