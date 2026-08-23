import '../models/athlete.dart';
import '../models/bloc.dart';
import '../models/chrono_athlete.dart';
import '../models/competition.dart';
import '../models/exercice.dart';
import '../models/seance.dart';
import '../models/test_performance.dart';
import 'database_service.dart';

/// Jeu de données fictives pour démonstration et captures d'écran.
class DemoDataService {
  DemoDataService(this._db);

  final DatabaseService _db;

  /// Efface toutes les données puis charge le jeu de démonstration.
  Future<void> seed({bool replaceExisting = true}) async {
    await _db.ensureReady();
    if (replaceExisting) {
      await _db.clearAll();
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final athletes = await _seedAthletes();
    await _seedTests(athletes, now);
    await _seedSeances(athletes, now, today);
    await _seedTemplates(athletes);
    await _seedPlanifiees(athletes, today);
    await _seedCompetitions(athletes, today);
  }

  Future<List<Athlete>> _seedAthletes() async {
    final specs = [
      ('Léa Martin', 'FFA-284719', DateTime(2006, 4, 12), 2),
      ('Tom Dupont', 'FFA-193842', DateTime(2005, 9, 3), 0),
      ('Inès Bernard', 'FFA-551203', DateTime(2007, 1, 28), 1),
      ('Hugo Petit', 'FFA-772901', DateTime(2004, 11, 15), 3),
      ('Camille Rousseau', 'FFA-334567', DateTime(2008, 6, 7), 0),
      ('Noah Girard', 'FFA-889012', DateTime(2005, 2, 19), 1),
      ('Emma Laurent', 'FFA-445678', DateTime(2006, 8, 30), 2),
      ('Lucas Moreau', 'FFA-667890', DateTime(2007, 12, 5), 0),
    ];

    final athletes = <Athlete>[];
    for (final (nom, licence, naissance, dette) in specs) {
      final athlete = Athlete(
        nom: nom,
        numeroLicence: licence,
        dateNaissance: naissance,
        detteGateau: dette,
      );
      await _db.addAthlete(athlete);
      athletes.add(athlete);
    }
    return athletes;
  }

  Future<void> _seedTests(List<Athlete> athletes, DateTime now) async {
    final vmaProgression = [16.2, 16.8, 17.1, 17.4, 17.9, 18.2];
    for (var i = 0; i < vmaProgression.length; i++) {
      await _db.addTest(
        TestPerformance(
          athleteId: athletes[0].id,
          date: now.subtract(Duration(days: 30 * (5 - i))),
          typeTest: 'VMA',
          resultat: vmaProgression[i],
          unite: 'km/h',
        ),
      );
    }

    final pentabond = [9.8, 10.1, 10.4, 10.6];
    for (var i = 0; i < pentabond.length; i++) {
      await _db.addTest(
        TestPerformance(
          athleteId: athletes[2].id,
          date: now.subtract(Duration(days: 21 * (3 - i))),
          typeTest: 'Pentabond',
          resultat: pentabond[i],
          unite: 'm',
        ),
      );
    }

    for (final athlete in [athletes[1], athletes[4], athletes[6]]) {
      await _db.addTest(
        TestPerformance(
          athleteId: athlete.id,
          date: now.subtract(const Duration(days: 14)),
          typeTest: 'Souplesse',
          resultat: 42.0 + athletes.indexOf(athlete),
          unite: 'cm',
        ),
      );
    }
  }

  Future<void> _seedSeances(
    List<Athlete> athletes,
    DateTime now,
    DateTime today,
  ) async {
    final sprintGroup = athletes.take(4).map((a) => a.id).toList();
    final jumpGroup = [athletes[2].id, athletes[4].id, athletes[6].id];

    // Séance riche pour la présentation.
    await _db.addSeance(
      Seance(
        titre: 'Fractionné piste — spécifique 200 m',
        date: today.subtract(const Duration(days: 2)),
        athleteIds: sprintGroup,
        blocs: [
          Bloc(
            nom: 'Échauffement progressif',
            tempsRecuperation: '2:00',
            exercices: [
              Exercice(
                type: 'Course',
                distance: '400',
                tempsRecuperation: '1:30',
                notes: 'Allure progressive, focus technique',
              ),
              Exercice(
                type: 'Course',
                distance: '4 x 80',
                tempsRecuperation: '1:00',
                notes: 'Enchaînements souples',
              ),
            ],
          ),
          Bloc(
            nom: 'Travail lactique',
            tempsRecuperation: '3:00',
            exercices: [
              Exercice(
                type: 'Course',
                distance: '3 x 200',
                tempsRecuperation: '2:30',
                notes: '95 % VMA, récup complète entre séries',
                chronos: [
                  ChronoAthlete(
                    athleteId: athletes[0].id,
                    chrono: '24,12',
                  ),
                  ChronoAthlete(
                    athleteId: athletes[1].id,
                    chrono: '23,98',
                  ),
                  ChronoAthlete(
                    athleteId: athletes[0].id,
                    chrono: '24,45',
                  ),
                  ChronoAthlete(
                    athleteId: athletes[1].id,
                    chrono: '24,01',
                  ),
                ],
              ),
              Exercice(
                type: 'Course',
                distance: '200',
                tempsRecuperation: '3:00',
                notes: 'Dernier effort — objectif chronométré',
                chronos: [
                  ChronoAthlete(athleteId: athletes[0].id, chrono: '23,87'),
                  ChronoAthlete(athleteId: athletes[1].id, chrono: '23,65'),
                  ChronoAthlete(athleteId: athletes[3].id, chrono: '24,20'),
                ],
              ),
            ],
          ),
          Bloc(
            nom: 'Retour au calme',
            tempsRecuperation: '',
            exercices: [
              Exercice(
                type: 'Course',
                distance: '800',
                tempsRecuperation: '0:00',
                notes: 'Footing léger + étirements',
              ),
            ],
          ),
        ],
      ),
    );

    await _db.addSeance(
      Seance(
        titre: 'PPG + pliométrie',
        date: today.subtract(const Duration(days: 5)),
        athleteIds: jumpGroup,
        blocs: [
          Bloc(
            nom: 'Renforcement',
            exercices: [
              Exercice(
                type: 'Muscu',
                nom: 'Squat sauté',
                tempsRecuperation: '1:30',
                notes: '3 x 8, amplitude complète',
              ),
              Exercice(
                type: 'Muscu',
                nom: 'Fentes alternées',
                tempsRecuperation: '1:00',
              ),
              Exercice(
                type: 'Saut',
                nom: 'Triple saut en place',
                tempsRecuperation: '2:00',
                notes: 'Focus réactivité',
              ),
            ],
          ),
        ],
      ),
    );

    // Historique pour la heatmap d'assiduité (12 semaines).
    const titres = [
      'VMA terrain',
      'Endurance fondamentale',
      'Technique haies',
      'Force max salle',
      'Spécifique compétition',
    ];
    for (var week = 1; week <= 12; week++) {
      final date = today.subtract(Duration(days: week * 4));
      final group = week.isEven ? sprintGroup : jumpGroup;
      await _db.addSeance(
        Seance(
          titre: titres[week % titres.length],
          date: date,
          athleteIds: group,
          blocs: [
            Bloc(
              nom: 'Bloc principal',
              exercices: [
                Exercice(
                  type: 'Course',
                  distance: week.isEven ? '300' : '150',
                  tempsRecuperation: '2:00',
                ),
              ],
            ),
          ],
        ),
      );
      if (week % 3 == 0) {
        await _db.addSeance(
          Seance(
            titre: 'Renforcement complémentaire',
            date: date.subtract(const Duration(days: 2)),
            athleteIds: [group.first, group.last],
            blocs: [
              Bloc(
                nom: 'Circuit',
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
      }
    }
  }

  Future<void> _seedTemplates(List<Athlete> athletes) async {
    await _db.addSeance(
      Seance(
        titre: 'Modèle VMA + PPG',
        isTemplate: true,
        blocs: [
          Bloc(
            nom: 'VMA',
            tempsRecuperation: '2:00',
            exercices: [
              Exercice(
                type: 'Course',
                distance: '10 x 200',
                tempsRecuperation: '1:00',
                notes: 'Allure VMA, récup trot',
              ),
            ],
          ),
          Bloc(
            nom: 'PPG',
            exercices: [
              Exercice(
                type: 'Muscu',
                nom: 'Pompes',
                tempsRecuperation: '0:45',
              ),
              Exercice(
                type: 'Muscu',
                nom: 'Abdos',
                tempsRecuperation: '0:45',
              ),
            ],
          ),
        ],
      ),
    );

    await _db.addSeance(
      Seance(
        titre: 'Modèle Force max',
        isTemplate: true,
        blocs: [
          Bloc(
            nom: 'Salle',
            exercices: [
              Exercice(
                type: 'Muscu',
                nom: 'Squat',
                tempsRecuperation: '3:00',
                notes: '4 x 4, charge lourde',
              ),
              Exercice(
                type: 'Muscu',
                nom: 'Soulevé de terre',
                tempsRecuperation: '3:00',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _seedPlanifiees(List<Athlete> athletes, DateTime today) async {
    final sprintGroup = athletes.take(4).map((a) => a.id).toList();

    await _db.addSeance(
      Seance(
        titre: 'Séance VMA — préparation meeting',
        date: today,
        estPlanifiee: true,
        datePrevue: today,
        athleteIds: sprintGroup,
        blocs: [
          Bloc(
            nom: 'Échauffement',
            exercices: [
              Exercice(
                type: 'Course',
                distance: '15 min footing',
                tempsRecuperation: '0:00',
              ),
            ],
          ),
          Bloc(
            nom: 'VMA',
            tempsRecuperation: '2:00',
            exercices: [
              Exercice(
                type: 'Course',
                distance: '6 x 300',
                tempsRecuperation: '1:30',
                notes: 'Allure compétition',
              ),
            ],
          ),
        ],
      ),
    );

    await _db.addSeance(
      Seance(
        titre: 'PPG générale',
        date: today,
        estPlanifiee: true,
        datePrevue: today.add(const Duration(days: 3)),
        athleteIds: athletes.map((a) => a.id).toList(),
        blocs: [
          Bloc(
            nom: 'Circuit',
            exercices: [
              Exercice(
                type: 'Muscu',
                nom: 'Circuit complet',
                tempsRecuperation: '1:00',
              ),
            ],
          ),
        ],
      ),
    );

    await _db.addSeance(
      Seance(
        titre: 'Test VMA trimestriel',
        date: today,
        estPlanifiee: true,
        datePrevue: today.add(const Duration(days: 10)),
        athleteIds: [athletes[0].id, athletes[1].id],
        blocs: const [],
      ),
    );
  }

  Future<void> _seedCompetitions(List<Athlete> athletes, DateTime today) async {
    final sprintIds = athletes.take(5).map((a) => a.id).toList();

    await _db.addCompetition(
      Competition(
        titre: 'Meeting régional d\'été',
        dateDebut: today.add(const Duration(days: 7)),
        dateFin: today.add(const Duration(days: 7)),
        lieu: 'Stade Municipal — Lyon',
        athleteIds: sprintIds,
      ),
    );

    await _db.addCompetition(
      Competition(
        titre: 'Championnats départementaux',
        dateDebut: today.add(const Duration(days: 21)),
        dateFin: today.add(const Duration(days: 22)),
        lieu: 'Complexe Léo Lagrange — Grenoble',
        athleteIds: athletes.map((a) => a.id).toList(),
      ),
    );

    await _db.addCompetition(
      Competition(
        titre: 'Interclubs zone Sud',
        dateDebut: today.subtract(const Duration(days: 14)),
        dateFin: today.subtract(const Duration(days: 14)),
        lieu: 'Piste Guy Drut — Villeurbanne',
        athleteIds: sprintIds,
      ),
    );
  }
}
