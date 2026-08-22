import 'package:hive_flutter/hive_flutter.dart';

import '../models/athlete.dart';
import '../models/bloc_entrainement.dart';
import '../models/chrono_athlete.dart';
import '../models/seance.dart';
import '../models/test_performance.dart';

class DatabaseService {
  static const String _athletesBoxName = 'athletesBox';
  static const String _seancesBoxName = 'seancesBox';
  static const String _testsBoxName = 'testsBox';

  Box<Athlete>? _athletesBox;
  Box<Seance>? _seancesBox;
  Box<TestPerformance>? _testsBox;

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
    if (!Hive.isAdapterRegistered(5)) {
      Hive.registerAdapter(BlocEntrainementAdapter());
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
      // Valide le schéma (ancien BlocCourse sinon).
      _seancesBox!.values.toList();
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
  }

  Future<void> ensureReady() async {
    _registerAdapters();
    if (_athletesBox == null || _seancesBox == null || _testsBox == null) {
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

  List<Seance> getSeances() {
    final seances = _seancesBox?.values.toList() ?? [];
    seances.sort((a, b) => b.date.compareTo(a.date));
    return seances;
  }

  List<Seance> getSeancesByAthleteId(String athleteId) {
    final seances = _seancesBox?.values
            .where((seance) => seance.athleteIds.contains(athleteId))
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

  /// Distances déjà saisies (blocs Course).
  List<String> getDistinctDistances() => _distinctBlocValues(
        (bloc) => bloc.isCourse ? bloc.distance : null,
      );

  /// Noms d'exercices déjà saisis (Musculation / Saut).
  List<String> getDistinctNomExercices() => _distinctBlocValues(
        (bloc) => !bloc.isCourse ? bloc.nomExercice : null,
      );

  /// Temps de récupération déjà saisis.
  List<String> getDistinctTempsRecuperation() => _distinctBlocValues(
        (bloc) => bloc.tempsRecuperation,
      );

  List<String> _distinctBlocValues(String? Function(BlocEntrainement) pick) {
    final values = <String>{};
    for (final seance in getSeances()) {
      for (final bloc in seance.blocs) {
        final raw = pick(bloc)?.trim();
        if (raw != null && raw.isNotEmpty) values.add(raw);
      }
    }
    return values.toList()..sort();
  }
}
