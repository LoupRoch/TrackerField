import 'package:flutter/foundation.dart';

import '../models/athlete.dart';
import 'database_service.dart';

class AthleteProvider extends ChangeNotifier {
  AthleteProvider(this._databaseService) {
    _loadAthletes();
  }

  /// Constructeur de test : liste préchargée sans accès Hive.
  AthleteProvider.withAthletes(List<Athlete> athletes)
      : _databaseService = DatabaseService(),
        _athletes = List.of(athletes);

  final DatabaseService _databaseService;

  List<Athlete> _athletes = [];

  List<Athlete> get athletes => List.unmodifiable(_athletes);

  void _loadAthletes() {
    _athletes = _databaseService.getAthletes();
    notifyListeners();
  }

  Future<void> addAthlete({
    required String nom,
    required String numeroLicence,
    required DateTime dateNaissance,
    String? photoPath,
  }) async {
    final athlete = Athlete(
      nom: nom.trim(),
      numeroLicence: numeroLicence.trim(),
      dateNaissance: dateNaissance,
      photoPath: photoPath,
    );
    await _databaseService.addAthlete(athlete);
    _loadAthletes();
  }

  Future<void> updateAthlete({
    required String id,
    required String nom,
    required String numeroLicence,
    required DateTime dateNaissance,
    required int detteGateau,
    String? photoPath,
  }) async {
    final updated = Athlete(
      id: id,
      nom: nom.trim(),
      numeroLicence: numeroLicence.trim(),
      dateNaissance: dateNaissance,
      detteGateau: detteGateau,
      photoPath: photoPath,
    );
    await _databaseService.updateAthlete(updated);
    _loadAthletes();
  }

  Future<void> deleteAthlete(String id) async {
    await _databaseService.deleteAthlete(id);
    _loadAthletes();
  }

  Future<void> incrementDetteGateau(String id) async {
    final athlete = _databaseService.getAthlete(id);
    if (athlete == null) return;

    await _databaseService.updateDetteGateau(id, athlete.detteGateau + 1);
    _loadAthletes();
  }

  Future<void> decrementDetteGateau(String id) async {
    final athlete = _databaseService.getAthlete(id);
    if (athlete == null || athlete.detteGateau <= 0) return;

    await _databaseService.updateDetteGateau(id, athlete.detteGateau - 1);
    _loadAthletes();
  }
}
