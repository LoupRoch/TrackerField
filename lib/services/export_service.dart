import 'dart:io';

import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/athlete.dart';
import '../models/seance.dart';
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

    final athletesById = {
      for (final athlete in _databaseService.getAthletes()) athlete.id: athlete,
    };

    _writeAthletesSheet(excel['Athlètes'], athletesById.values);
    _writeSeancesSheet(excel['Séances'], athletesById);
    _writeCompetitionsSheet(excel['Compétitions'], athletesById);
    _writeTestsSheet(excel['Tests Performances'], athletesById);

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

  /// Génère le fichier Excel sans le partager (tests / vérification).
  Future<File> writeToFile(String path) async {
    await _databaseService.ensureReady();

    final excel = Excel.createExcel();
    final defaultSheet = excel.getDefaultSheet();
    if (defaultSheet != null) {
      excel.rename(defaultSheet, 'Athlètes');
    }

    final athletesById = {
      for (final athlete in _databaseService.getAthletes()) athlete.id: athlete,
    };

    _writeAthletesSheet(excel['Athlètes'], athletesById.values);
    _writeSeancesSheet(excel['Séances'], athletesById);
    _writeCompetitionsSheet(excel['Compétitions'], athletesById);
    _writeTestsSheet(excel['Tests Performances'], athletesById);

    final bytes = excel.encode();
    if (bytes == null) {
      throw StateError('Impossible de générer le fichier Excel.');
    }

    final file = File(path);
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  void _writeAthletesSheet(Sheet sheet, Iterable<Athlete> athletes) {
    sheet.appendRow([
      TextCellValue('Nom'),
      TextCellValue('Licence'),
      TextCellValue('Date naissance'),
      TextCellValue('Dette Gâteau'),
      TextCellValue('Photo'),
    ]);

    for (final athlete in athletes) {
      sheet.appendRow([
        TextCellValue(athlete.nom),
        TextCellValue(athlete.numeroLicence),
        TextCellValue(_formatDate(athlete.dateNaissance)),
        IntCellValue(athlete.detteGateau),
        TextCellValue(athlete.photoPath ?? ''),
      ]);
    }
  }

  void _writeSeancesSheet(
    Sheet sheet,
    Map<String, Athlete> athletesById,
  ) {
    sheet.appendRow([
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
      TextCellValue('Type Séance'),
      TextCellValue('Date prévue'),
    ]);

    final seances = <Seance>[
      ..._databaseService.getSeances(),
      ..._databaseService.getTemplates(),
      ..._databaseService.getPlanifiees(),
    ];

    for (final seance in seances) {
      final dateLabel = _formatDate(seance.date);
      final athleteNames = seance.athleteIds
          .map((id) => athletesById[id]?.nom ?? id)
          .join(', ');
      final typeSeance = _seanceTypeLabel(seance);
      final datePrevue = seance.datePrevue == null
          ? ''
          : _formatDate(seance.datePrevue!);

      if (seance.blocs.isEmpty) {
        sheet.appendRow([
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
          TextCellValue(typeSeance),
          TextCellValue(datePrevue),
        ]);
        continue;
      }

      for (final bloc in seance.blocs) {
        if (bloc.exercices.isEmpty) {
          sheet.appendRow([
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
            TextCellValue(typeSeance),
            TextCellValue(datePrevue),
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
          final mediasLabel = exercice.mediaPaths.join(';');

          sheet.appendRow([
            TextCellValue(seance.titre),
            TextCellValue(dateLabel),
            TextCellValue(bloc.nom),
            TextCellValue(bloc.tempsRecuperation),
            TextCellValue(exercice.type),
            TextCellValue(label),
            TextCellValue(exercice.tempsRecuperation),
            TextCellValue(exercice.notes),
            TextCellValue(mediasLabel),
            TextCellValue(chronosLabel),
            TextCellValue(athleteNames),
            TextCellValue(typeSeance),
            TextCellValue(datePrevue),
          ]);
        }
      }
    }
  }

  void _writeCompetitionsSheet(
    Sheet sheet,
    Map<String, Athlete> athletesById,
  ) {
    sheet.appendRow([
      TextCellValue('Titre'),
      TextCellValue('Date début'),
      TextCellValue('Date fin'),
      TextCellValue('Lieu'),
      TextCellValue('Athlètes'),
    ]);

    for (final competition in _databaseService.getCompetitions()) {
      final athleteNames = competition.athleteIds
          .map((id) => athletesById[id]?.nom ?? id)
          .join(', ');
      sheet.appendRow([
        TextCellValue(competition.titre),
        TextCellValue(_formatDate(competition.dateDebut)),
        TextCellValue(_formatDate(competition.dateFin)),
        TextCellValue(competition.lieu),
        TextCellValue(athleteNames),
      ]);
    }
  }

  void _writeTestsSheet(
    Sheet sheet,
    Map<String, Athlete> athletesById,
  ) {
    sheet.appendRow([
      TextCellValue('Nom de l\'athlète'),
      TextCellValue('Date'),
      TextCellValue('Type de Test'),
      TextCellValue('Résultat'),
      TextCellValue('Unité'),
    ]);

    for (final test in _databaseService.getAllTests()) {
      final athleteName = athletesById[test.athleteId]?.nom ?? test.athleteId;
      sheet.appendRow([
        TextCellValue(athleteName),
        TextCellValue(_formatDate(test.date)),
        TextCellValue(test.typeTest),
        DoubleCellValue(test.resultat),
        TextCellValue(test.unite),
      ]);
    }
  }

  String _seanceTypeLabel(Seance seance) {
    if (seance.isTemplate) return 'modèle';
    if (seance.estPlanifiee) return 'planifiée';
    return 'réalisée';
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }
}
