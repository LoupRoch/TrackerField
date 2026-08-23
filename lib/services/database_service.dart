import 'package:hive_flutter/hive_flutter.dart';

import '../models/athlete.dart';
import '../models/bloc.dart';
import '../models/chrono_athlete.dart';
import '../models/competition.dart';
import '../models/exercice.dart';
import '../models/seance.dart';
import '../models/test_performance.dart';

class DatabaseService {
  static const String _athletesBoxName = 'athletesBox';
  static const String _seancesBoxName = 'seancesBox';
  static const String _testsBoxName = 'testsBox';
  static const String _competitionsBoxName = 'competitionsBox';

  Box<Athlete>? _athletesBox;
  Box<Seance>? _seancesBox;
  Box<TestPerformance>? _testsBox;
  Box<Competition>? _competitionsBox;

  /// [path] is intended for tests; production uses [Hive.initFlutter].
  Future<void> init({String? path}) async {
    if (path != null) {
      Hive.init(path);
    } else {
      await Hive.initFlutter();
    }

    _registerAdapters();
    await _openBoxes();
  }

  void _registerAdapters() {
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(AthleteAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(SeanceAdapter());
    }
    if (!Hive.isAdapterRegistered(3)) {
      Hive.registerAdapter(ChronoAthleteAdapter());
    }
    if (!Hive.isAdapterRegistered(4)) {
      Hive.registerAdapter(TestPerformanceAdapter());
    }
    if (!Hive.isAdapterRegistered(6)) {
      Hive.registerAdapter(ExerciceAdapter());
    }
    if (!Hive.isAdapterRegistered(7)) {
      Hive.registerAdapter(BlocAdapter());
    }
    if (!Hive.isAdapterRegistered(8)) {
      Hive.registerAdapter(CompetitionAdapter());
    }
  }

  Future<void> _openBoxes() async {
    _athletesBox = Hive.isBoxOpen(_athletesBoxName)
        ? Hive.box<Athlete>(_athletesBoxName)
        : await Hive.openBox<Athlete>(_athletesBoxName);

    try {
      _seancesBox = Hive.isBoxOpen(_seancesBoxName)
          ? Hive.box<Seance>(_seancesBoxName)
          : await Hive.openBox<Seance>(_seancesBoxName);
      for (final seance in _seancesBox!.values) {
        for (final bloc in seance.blocs) {
          bloc.exercices.length;
        }
      }
    } catch (_) {
      if (Hive.isBoxOpen(_seancesBoxName)) {
        await Hive.box(_seancesBoxName).close();
      }
      await Hive.deleteBoxFromDisk(_seancesBoxName);
      _seancesBox = await Hive.openBox<Seance>(_seancesBoxName);
    }

    _testsBox = Hive.isBoxOpen(_testsBoxName)
        ? Hive.box<TestPerformance>(_testsBoxName)
        : await Hive.openBox<TestPerformance>(_testsBoxName);

    _competitionsBox = Hive.isBoxOpen(_competitionsBoxName)
        ? Hive.box<Competition>(_competitionsBoxName)
        : await Hive.openBox<Competition>(_competitionsBoxName);
  }

  Future<void> ensureReady() async {
    _registerAdapters();
    if (_athletesBox == null ||
        _seancesBox == null ||
        _testsBox == null ||
        _competitionsBox == null) {
      await _openBoxes();
    }
  }

  Box<Athlete> get _athletes {
    final box = _athletesBox;
    if (box == null) {
      throw StateError('DatabaseService non initialisé (athletesBox).');
    }
    return box;
  }

  Box<Seance> get _seances {
    final box = _seancesBox;
    if (box == null) {
      throw StateError('DatabaseService non initialisé (seancesBox).');
    }
    return box;
  }

  Box<TestPerformance> get _tests {
    final box = _testsBox;
    if (box == null) {
      throw StateError('DatabaseService non initialisé (testsBox).');
    }
    return box;
  }

  Box<Competition> get _competitions {
    final box = _competitionsBox;
    if (box == null) {
      throw StateError('DatabaseService non initialisé (competitionsBox).');
    }
    return box;
  }

  /// Supprime toutes les données (athlètes, séances, tests, compétitions).
  Future<void> clearAll() async {
    await ensureReady();
    await _athletes.clear();
    await _seances.clear();
    await _tests.clear();
    await _competitions.clear();
  }

  bool get isEmpty {
    return (_athletesBox?.isEmpty ?? true) &&
        (_seancesBox?.isEmpty ?? true) &&
        (_testsBox?.isEmpty ?? true) &&
        (_competitionsBox?.isEmpty ?? true);
  }

  Future<void> addAthlete(Athlete athlete) async {
    await ensureReady();
    await _athletes.put(athlete.id, athlete);
  }

  Future<void> updateAthlete(Athlete athlete) async {
    await ensureReady();
    await _athletes.put(athlete.id, athlete);
  }

  List<Athlete> getAthletes() {
    return _athletesBox?.values.toList() ?? [];
  }

  Athlete? getAthlete(String id) {
    return _athletesBox?.get(id);
  }

  Future<void> updateDetteGateau(String id, int detteGateau) async {
    await ensureReady();
    final athlete = _athletes.get(id);
    if (athlete == null) return;

    athlete.detteGateau = detteGateau;
    await athlete.save();
  }

  Future<void> deleteAthlete(String id) async {
    await ensureReady();
    await _athletes.delete(id);
  }

  Future<void> addSeance(Seance seance) async {
    await ensureReady();
    await _seances.put(seance.id, seance);
  }

  /// Séances réalisées (hors modèles et hors planifiées).
  List<Seance> getSeances() {
    final seances = _seancesBox?.values
            .where((seance) => !seance.isTemplate && !seance.estPlanifiee)
            .toList() ??
        [];
    seances.sort((a, b) => b.date.compareTo(a.date));
    return seances;
  }

  /// Modèles de séances prévues (templates).
  List<Seance> getTemplates() {
    final templates = _seancesBox?.values
            .where((seance) => seance.isTemplate)
            .toList() ??
        [];
    templates.sort(
      (a, b) => a.titre.toLowerCase().compareTo(b.titre.toLowerCase()),
    );
    return templates;
  }

  /// Séances planifiées sur le calendrier prévisionnel.
  List<Seance> getPlanifiees() {
    final planifiees = _seancesBox?.values
            .where((seance) => seance.estPlanifiee && !seance.isTemplate)
            .toList() ??
        [];
    planifiees.sort((a, b) {
      final da = a.datePrevue ?? a.date;
      final db = b.datePrevue ?? b.date;
      return da.compareTo(db);
    });
    return planifiees;
  }

  List<Seance> getPlanifieesForDay(DateTime day) {
    final key = DateTime(day.year, day.month, day.day);
    return getPlanifiees().where((seance) {
      final d = seance.datePrevue;
      if (d == null) return false;
      return d.year == key.year && d.month == key.month && d.day == key.day;
    }).toList();
  }

  List<Seance> getSeancesByAthleteId(String athleteId) {
    final seances = _seancesBox?.values
            .where(
              (seance) =>
                  !seance.isTemplate &&
                  !seance.estPlanifiee &&
                  seance.athleteIds.contains(athleteId),
            )
            .toList() ??
        [];
    seances.sort((a, b) => b.date.compareTo(a.date));
    return seances;
  }

  Seance? getSeance(String id) {
    return _seancesBox?.get(id);
  }

  Future<void> updateSeance(Seance seance) async {
    await ensureReady();
    await _seances.put(seance.id, seance);
  }

  Future<void> deleteSeance(String id) async {
    await ensureReady();
    await _seances.delete(id);
  }

  Future<void> addCompetition(Competition competition) async {
    await ensureReady();
    await _competitions.put(competition.id, competition);
  }

  Future<void> updateCompetition(Competition competition) async {
    await ensureReady();
    await _competitions.put(competition.id, competition);
  }

  Future<void> deleteCompetition(String id) async {
    await ensureReady();
    await _competitions.delete(id);
  }

  List<Competition> getCompetitions() {
    final list = _competitionsBox?.values.toList() ?? [];
    list.sort((a, b) => a.dateDebut.compareTo(b.dateDebut));
    return list;
  }

  List<Competition> getCompetitionsForDay(DateTime day) {
    return getCompetitions().where((c) => c.coversDay(day)).toList();
  }

  Future<void> addTest(TestPerformance test) async {
    await ensureReady();
    await _tests.put(test.id, test);
  }

  Future<void> updateTest(TestPerformance test) async {
    await ensureReady();
    await _tests.put(test.id, test);
  }

  List<TestPerformance> getTestsByAthleteId(String athleteId) {
    final tests = _testsBox?.values
            .where((test) => test.athleteId == athleteId)
            .toList() ??
        [];
    tests.sort((a, b) => b.date.compareTo(a.date));
    return tests;
  }

  List<TestPerformance> getAllTests() {
    final tests = _testsBox?.values.toList() ?? [];
    tests.sort((a, b) => b.date.compareTo(a.date));
    return tests;
  }

  /// Distances de course déjà saisies.
  List<String> getDistinctDistances() => _distinctExerciceValues(
        (exercice) => exercice.distance,
      );

  /// Noms d'exercices (Muscu / Saut).
  List<String> getDistinctNomExercices() => _distinctExerciceValues(
        (exercice) => exercice.nom,
      );

  /// Temps de récupération déjà saisis (exercices).
  List<String> getDistinctTempsRecuperation() => _distinctExerciceValues(
        (exercice) => exercice.tempsRecuperation,
      );

  List<String> _distinctExerciceValues(String? Function(Exercice) pick) {
    final values = <String>{};
    final all = _seancesBox?.values ?? const Iterable.empty();
    for (final seance in all) {
      for (final bloc in seance.blocs) {
        for (final exercice in bloc.exercices) {
          final raw = pick(exercice)?.trim();
          if (raw != null && raw.isNotEmpty) values.add(raw);
        }
      }
    }
    return values.toList()..sort();
  }
}
