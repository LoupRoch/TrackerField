import 'dart:io';

import 'package:excel/excel.dart';

import '../models/athlete.dart';
import '../models/bloc.dart';
import '../models/chrono_athlete.dart';
import '../models/competition.dart';
import '../models/exercice.dart';
import '../models/seance.dart';
import '../models/test_performance.dart';
import 'database_service.dart';
import 'media_storage_service.dart';

class ImportSummary {
  const ImportSummary({
    required this.athletesCreated,
    required this.athletesUpdated,
    required this.seancesImported,
    required this.competitionsImported,
    required this.testsImported,
    this.warnings = const [],
  });

  final int athletesCreated;
  final int athletesUpdated;
  final int seancesImported;
  final int competitionsImported;
  final int testsImported;
  final List<String> warnings;

  String get message {
    final parts = <String>[
      '$athletesCreated athlète(s) créé(s)',
      '$athletesUpdated athlète(s) mis à jour',
      '$seancesImported séance(s)',
      '$competitionsImported compétition(s)',
      '$testsImported test(s)',
    ];
    return 'Import terminé : ${parts.join(', ')}.';
  }
}

/// Importe un fichier Excel au format d'export TrackerField.
class ImportService {
  ImportService(this._databaseService);

  final DatabaseService _databaseService;

  Future<ImportSummary> importFromFile(String path) async {
    await _databaseService.ensureReady();

    final bytes = await File(path).readAsBytes();
    final excel = Excel.decodeBytes(bytes);
    final warnings = <String>[];

    var athletesCreated = 0;
    var athletesUpdated = 0;
    var seancesImported = 0;
    var competitionsImported = 0;
    var testsImported = 0;

    final athleteIdByKey = <String, String>{};
    for (final athlete in _databaseService.getAthletes()) {
      athleteIdByKey[_athleteKey(athlete.nom, athlete.numeroLicence)] =
          athlete.id;
      athleteIdByKey[_nameKey(athlete.nom)] = athlete.id;
    }

    final athletesSheet = excel.tables['Athlètes'];
    if (athletesSheet != null && athletesSheet.maxRows > 1) {
      for (var rowIndex = 1; rowIndex < athletesSheet.maxRows; rowIndex++) {
        final row = athletesSheet.row(rowIndex);
        final nom = _cellText(row, 0);
        final licence = _cellText(row, 1);
        if (nom.isEmpty) continue;

        final dateNaissance = _parseAthleteBirthDate(row);
        final dette = _cellInt(row, 3) ?? 0;
        final photoPath = await _existingMediaPath(_cellText(row, 4));

        final key = _athleteKey(nom, licence);
        final existingId = athleteIdByKey[key] ?? athleteIdByKey[_nameKey(nom)];
        if (existingId != null) {
          final existing = _databaseService.getAthlete(existingId);
          if (existing != null) {
            existing.nom = nom;
            if (licence.isNotEmpty) existing.numeroLicence = licence;
            existing.detteGateau = dette;
            if (dateNaissance != null) existing.dateNaissance = dateNaissance;
            if (photoPath != null) existing.photoPath = photoPath;
            await _databaseService.updateAthlete(existing);
            athletesUpdated++;
            athleteIdByKey[key] = existing.id;
            athleteIdByKey[_nameKey(nom)] = existing.id;
          }
        } else {
          final athlete = Athlete(
            nom: nom,
            numeroLicence: licence.isEmpty ? '—' : licence,
            dateNaissance: dateNaissance ?? DateTime(2000, 1, 1),
            detteGateau: dette,
            photoPath: photoPath,
          );
          await _databaseService.addAthlete(athlete);
          athletesCreated++;
          athleteIdByKey[key] = athlete.id;
          athleteIdByKey[_nameKey(nom)] = athlete.id;
        }
      }
    } else {
      warnings.add('Feuille « Athlètes » absente ou vide.');
    }

    // Refresh map after athletes import.
    for (final athlete in _databaseService.getAthletes()) {
      athleteIdByKey[_athleteKey(athlete.nom, athlete.numeroLicence)] =
          athlete.id;
      athleteIdByKey[_nameKey(athlete.nom)] = athlete.id;
    }

    final seancesSheet = excel.tables['Séances'];
    if (seancesSheet != null && seancesSheet.maxRows > 1) {
      final grouped = <String, _SeanceDraft>{};

      for (var rowIndex = 1; rowIndex < seancesSheet.maxRows; rowIndex++) {
        final row = seancesSheet.row(rowIndex);
        final titre = _cellText(row, 0);
        final date = _parseDate(_cellText(row, 1));
        if (titre.isEmpty || date == null) continue;

        final athleteNames = _cellText(row, 10);
        final typeSeance = _cellText(row, 11);
        final datePrevue = _parseDate(_cellText(row, 12));
        final flags = _parseSeanceFlags(typeSeance);

        final groupKey = [
          titre,
          '${date.year}-${date.month}-${date.day}',
          athleteNames,
          typeSeance,
          datePrevue == null
              ? ''
              : '${datePrevue.year}-${datePrevue.month}-${datePrevue.day}',
        ].join('|');

        final draft = grouped.putIfAbsent(
          groupKey,
          () => _SeanceDraft(
            titre: titre,
            date: date,
            athleteIds: _resolveAthleteIds(athleteNames, athleteIdByKey),
            isTemplate: flags.isTemplate,
            estPlanifiee: flags.estPlanifiee,
            datePrevue: datePrevue,
          ),
        );

        final blocNom = _cellText(row, 2);
        if (blocNom.isEmpty) continue;

        final bloc = draft.blocs.putIfAbsent(
          blocNom,
          () => Bloc(
            nom: blocNom,
            tempsRecuperation: _cellText(row, 3),
            exercices: [],
          ),
        );

        final type = _cellText(row, 4);
        if (type.isEmpty) continue;

        final label = _cellText(row, 5);
        final isCourse = type == 'Course';
        final chronos = _parseChronos(_cellText(row, 9), athleteIdByKey);
        final mediaPaths = await _parseMediaPaths(_cellText(row, 8));

        bloc.exercices.add(
          Exercice(
            type: type,
            nom: isCourse ? null : (label.isEmpty ? type : label),
            distance: isCourse ? (label.isEmpty ? null : label) : null,
            tempsRecuperation: _cellText(row, 6).isEmpty
                ? '0:00'
                : _cellText(row, 6),
            notes: _cellText(row, 7),
            mediaPaths: mediaPaths,
            chronos: chronos,
          ),
        );
      }

      for (final draft in grouped.values) {
        final seance = Seance(
          titre: draft.titre,
          date: draft.date,
          athleteIds: draft.athleteIds,
          blocs: draft.blocs.values.toList(),
          isTemplate: draft.isTemplate,
          estPlanifiee: draft.estPlanifiee,
          datePrevue: draft.datePrevue,
        );
        await _databaseService.addSeance(seance);
        seancesImported++;
      }
    } else {
      warnings.add('Feuille « Séances » absente ou vide.');
    }

    final competitionsSheet = excel.tables['Compétitions'];
    if (competitionsSheet != null && competitionsSheet.maxRows > 1) {
      for (var rowIndex = 1; rowIndex < competitionsSheet.maxRows; rowIndex++) {
        final row = competitionsSheet.row(rowIndex);
        final titre = _cellText(row, 0);
        final dateDebut = _parseDate(_cellText(row, 1));
        final dateFin = _parseDate(_cellText(row, 2)) ?? dateDebut;
        if (titre.isEmpty || dateDebut == null || dateFin == null) continue;

        final competition = Competition(
          titre: titre,
          dateDebut: dateDebut,
          dateFin: dateFin,
          lieu: _cellText(row, 3),
          athleteIds: _resolveAthleteIds(_cellText(row, 4), athleteIdByKey),
        );
        await _databaseService.addCompetition(competition);
        competitionsImported++;
      }
    } else if (competitionsSheet == null) {
      warnings.add('Feuille « Compétitions » absente (ancien export).');
    }

    final testsSheet = excel.tables['Tests Performances'];
    if (testsSheet != null && testsSheet.maxRows > 1) {
      for (var rowIndex = 1; rowIndex < testsSheet.maxRows; rowIndex++) {
        final row = testsSheet.row(rowIndex);
        final athleteName = _cellText(row, 0);
        final date = _parseDate(_cellText(row, 1));
        final type = _cellText(row, 2);
        final resultat = _cellDouble(row, 3);
        final unite = _cellText(row, 4);
        if (athleteName.isEmpty ||
            date == null ||
            type.isEmpty ||
            resultat == null) {
          continue;
        }

        final athleteId = athleteIdByKey[_nameKey(athleteName)];
        if (athleteId == null) {
          warnings.add('Test ignoré : athlète inconnu « $athleteName ».');
          continue;
        }

        await _databaseService.addTest(
          TestPerformance(
            athleteId: athleteId,
            date: date,
            typeTest: type,
            resultat: resultat,
            unite: unite.isEmpty ? TestPerformance.unitePour(type) : unite,
          ),
        );
        testsImported++;
      }
    } else {
      warnings.add('Feuille « Tests Performances » absente ou vide.');
    }

    return ImportSummary(
      athletesCreated: athletesCreated,
      athletesUpdated: athletesUpdated,
      seancesImported: seancesImported,
      competitionsImported: competitionsImported,
      testsImported: testsImported,
      warnings: warnings,
    );
  }

  String _athleteKey(String nom, String licence) =>
      '${_nameKey(nom)}|${licence.trim().toLowerCase()}';

  String _nameKey(String nom) => nom.trim().toLowerCase();

  String _cellText(List<Data?> row, int index) {
    if (index >= row.length) return '';
    final value = row[index]?.value;
    if (value == null) return '';
    if (value is DateTimeCellValue) {
      return _formatDate(DateTime(value.year, value.month, value.day));
    }
    return value.toString().trim();
  }

  int? _cellInt(List<Data?> row, int index) {
    final raw = _cellText(row, index);
    if (raw.isEmpty) return null;
    return int.tryParse(raw.split('.').first);
  }

  double? _cellDouble(List<Data?> row, int index) {
    final raw = _cellText(row, index).replaceAll(',', '.');
    if (raw.isEmpty) return null;
    return double.tryParse(raw);
  }

  DateTime? _parseAthleteBirthDate(List<Data?> row) {
    final raw = _cellText(row, 2);
    if (raw.isEmpty) return null;

    final asDate = _parseDate(raw);
    if (asDate != null) return asDate;

    // Ancien format : âge en années.
    final age = int.tryParse(raw.split('.').first);
    if (age == null || age < 0 || age > 120) return null;
    return DateTime(DateTime.now().year - age, 1, 1);
  }

  DateTime? _parseDate(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return null;
    final parts = text.split(RegExp(r'[/-]'));
    if (parts.length == 3) {
      // JJ/MM/AAAA ou AAAA-MM-JJ
      if (parts[0].length == 4) {
        final y = int.tryParse(parts[0]);
        final m = int.tryParse(parts[1]);
        final d = int.tryParse(parts[2]);
        if (d != null && m != null && y != null) {
          return DateTime(y, m, d);
        }
      } else {
        final d = int.tryParse(parts[0]);
        final m = int.tryParse(parts[1]);
        final y = int.tryParse(parts[2]);
        if (d != null && m != null && y != null) {
          return DateTime(y, m, d);
        }
      }
    }
    return DateTime.tryParse(text);
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  ({bool isTemplate, bool estPlanifiee}) _parseSeanceFlags(String raw) {
    final value = raw.trim().toLowerCase();
    if (value.contains('modèle') || value.contains('modele') || value == 'template') {
      return (isTemplate: true, estPlanifiee: false);
    }
    if (value.contains('planif')) {
      return (isTemplate: false, estPlanifiee: true);
    }
    return (isTemplate: false, estPlanifiee: false);
  }

  List<String> _resolveAthleteIds(
    String namesCsv,
    Map<String, String> athleteIdByKey,
  ) {
    if (namesCsv.trim().isEmpty) return [];
    final ids = <String>[];
    for (final part in namesCsv.split(',')) {
      final name = part.trim();
      if (name.isEmpty) continue;
      final id = athleteIdByKey[_nameKey(name)];
      if (id != null) ids.add(id);
    }
    return ids;
  }

  List<ChronoAthlete> _parseChronos(
    String raw,
    Map<String, String> athleteIdByKey,
  ) {
    if (raw.trim().isEmpty) return [];
    final chronos = <ChronoAthlete>[];
    for (final part in raw.split('|')) {
      final chunk = part.trim();
      if (chunk.isEmpty) continue;
      final sep = chunk.indexOf(':');
      if (sep <= 0) continue;
      final name = chunk.substring(0, sep).trim();
      final chrono = chunk.substring(sep + 1).trim();
      final id = athleteIdByKey[_nameKey(name)];
      if (id == null) continue;
      chronos.add(ChronoAthlete(athleteId: id, chrono: chrono));
    }
    return chronos;
  }

  /// Conserve uniquement les chemins dont le fichier existe encore.
  /// Les anciens exports (compteur numérique) sont ignorés.
  Future<List<String>> _parseMediaPaths(String raw) async {
    final text = raw.trim();
    if (text.isEmpty) return [];
    if (int.tryParse(text) != null) return [];

    final paths = <String>[];
    for (final part in text.split(RegExp(r'[;|]'))) {
      final candidate = part.trim();
      if (candidate.isEmpty) continue;
      final existing = await _existingMediaPath(candidate);
      if (existing != null) paths.add(existing);
    }
    return paths;
  }

  Future<String?> _existingMediaPath(String storedPath) async {
    final trimmed = storedPath.trim();
    if (trimmed.isEmpty) return null;
    try {
      final file = await MediaStorageService.resolveFile(trimmed);
      if (file == null) return null;
      // Conserve le chemin relatif d'origine si possible.
      if (!trimmed.startsWith('/') && !trimmed.contains(':')) {
        return trimmed;
      }
      final basename = trimmed.split(Platform.pathSeparator).last;
      if (basename.isEmpty) return null;
      return '${MediaStorageService.relativeDir}/$basename';
    } catch (_) {
      // Fichier inaccessible / plugin indisponible → média non importé.
      return null;
    }
  }
}

class _SeanceDraft {
  _SeanceDraft({
    required this.titre,
    required this.date,
    required this.athleteIds,
    this.isTemplate = false,
    this.estPlanifiee = false,
    this.datePrevue,
  });

  final String titre;
  final DateTime date;
  final List<String> athleteIds;
  final bool isTemplate;
  final bool estPlanifiee;
  final DateTime? datePrevue;
  final Map<String, Bloc> blocs = {};
}
