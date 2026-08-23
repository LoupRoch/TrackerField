# Captures TrackerField

Images générées pour présenter l'application (tablette paysage 1280×800).

## Regénérer les captures

```bash
flutter test test/presentation_screenshots_test.dart
```

Les PNG sont écrits dans ce dossier. Le test charge un jeu de données fictives en mémoire (voir `lib/services/demo_data_service.dart`).

## Contenu du jeu utilisé pour les captures

- 8 athlètes avec licences, âges et dettes granolas
- Séances passées (heatmap sur 12 semaines), dont un fractionné 200 m détaillé
- Séances planifiées (dont une aujourd'hui)
- 2 modèles de séance
- 3 compétitions (passée et à venir)
- Tests VMA, Pentabond, Souplesse avec historique

## Fichiers

| Fichier | Écran |
|---------|--------|
| `01_liste_athletes.png` | Liste athlètes |
| `02_fiche_athlete.png` | Fiche athlète (stats, heatmap) |
| `03_seance_live.png` | Séance en direct |
| `04_calendrier.png` | Calendrier |
| `05_detail_seance.png` | Détail séance fractionné |
| `06_modeles_seance.png` | Modèles de séance |
| `07_dashboard_navigation.png` | Navigation principale |
