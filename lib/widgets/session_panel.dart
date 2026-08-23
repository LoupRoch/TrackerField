import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/bloc.dart';
import '../models/seance.dart';
import '../services/athlete_provider.dart';
import '../services/database_service.dart';
import 'bloc_dialog.dart';
import 'bloc_exercices_details.dart';

class SessionPanel extends StatefulWidget {
  const SessionPanel({super.key, this.panelLabel});

  final String? panelLabel;

  @override
  State<SessionPanel> createState() => _SessionPanelState();
}

class _SessionPanelState extends State<SessionPanel> {
  final _titreController = TextEditingController();

  final List<Bloc> _blocs = [];
  final Set<String> _selectedAthleteIds = {};

  /// Si non null, la sauvegarde met à jour cette séance planifiée.
  String? _loadedPlanifieeId;

  Timer? _timer;
  Duration _elapsed = Duration.zero;
  var _isRunning = false;
  var _isSaving = false;

  @override
  void dispose() {
    _timer?.cancel();
    _titreController.dispose();
    super.dispose();
  }

  String get _chronoLabel {
    final hours = _elapsed.inHours.toString().padLeft(2, '0');
    final minutes = (_elapsed.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (_elapsed.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  void _startChrono() {
    if (_isRunning) return;
    setState(() => _isRunning = true);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _elapsed += const Duration(seconds: 1));
    });
  }

  void _pauseChrono() {
    _timer?.cancel();
    _timer = null;
    setState(() => _isRunning = false);
  }

  void _resetChrono() {
    _timer?.cancel();
    _timer = null;
    setState(() {
      _isRunning = false;
      _elapsed = Duration.zero;
    });
  }

  Future<void> _addOrEditBloc({Bloc? existing, int? index}) async {
    final bloc = await showBlocDialog(
      context,
      initial: existing,
      athleteIds: _selectedAthleteIds.toList(),
    );
    if (bloc == null || !mounted) return;
    setState(() {
      if (index == null) {
        _blocs.add(bloc);
      } else {
        _blocs[index] = bloc;
      }
    });
  }

  void _duplicateBloc(int index) {
    setState(() {
      _blocs.insert(index + 1, _blocs[index].copy(asNew: true));
    });
  }

  Future<void> _deleteBloc(int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer le bloc'),
        content: const Text('Supprimer ce bloc de la séance en cours ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _blocs.removeAt(index));
  }

  Future<void> _showSelectAthletesDialog() async {
    final athletes = context.read<AthleteProvider>().athletes;
    final draftSelection = Set<String>.from(_selectedAthleteIds);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Sélectionner les athlètes'),
              content: SizedBox(
                width: 420,
                height: 360,
                child: athletes.isEmpty
                    ? const Center(
                        child: Text('Aucun athlète enregistré.'),
                      )
                    : ListView.builder(
                        itemCount: athletes.length,
                        itemBuilder: (context, index) {
                          final athlete = athletes[index];
                          final selected =
                              draftSelection.contains(athlete.id);
                          return CheckboxListTile(
                            value: selected,
                            title: Text(athlete.nom),
                            subtitle: Text('Licence ${athlete.numeroLicence}'),
                            onChanged: (value) {
                              setDialogState(() {
                                if (value ?? false) {
                                  draftSelection.add(athlete.id);
                                } else {
                                  draftSelection.remove(athlete.id);
                                }
                              });
                            },
                          );
                        },
                      ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Annuler'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('Valider'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed == true && mounted) {
      setState(() {
        _selectedAthleteIds
          ..clear()
          ..addAll(draftSelection);
      });
    }
  }

  Future<void> _loadSeance() async {
    final db = context.read<DatabaseService>();
    await db.ensureReady();
    if (!mounted) return;

    final todayPlanifiees = db.getPlanifieesForDay(DateTime.now());
    final templates = db.getTemplates();

    if (todayPlanifiees.isEmpty && templates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Aucune séance planifiée aujourd\'hui ni modèle disponible.',
          ),
        ),
      );
      return;
    }

    final selected = await showDialog<_LoadSeanceChoice>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Charger une séance'),
          content: SizedBox(
            width: 440,
            height: 420,
            child: ListView(
              children: [
                if (todayPlanifiees.isNotEmpty) ...[
                  Text(
                    'Planifiées aujourd\'hui',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  ...todayPlanifiees.map(
                    (seance) => ListTile(
                      leading: const Icon(Icons.schedule),
                      title: Text(seance.titre),
                      subtitle: Text('${seance.blocs.length} bloc(s)'),
                      onTap: () => Navigator.pop(
                        context,
                        _LoadSeanceChoice.planifiee(seance),
                      ),
                    ),
                  ),
                  if (templates.isNotEmpty) const Divider(height: 24),
                ],
                if (templates.isNotEmpty) ...[
                  Text(
                    'Modèles',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  ...templates.map(
                    (template) => ListTile(
                      leading: const Icon(Icons.event_note),
                      title: Text(template.titre),
                      subtitle: Text('${template.blocs.length} bloc(s)'),
                      onTap: () => Navigator.pop(
                        context,
                        _LoadSeanceChoice.template(template),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
          ],
        );
      },
    );
    if (selected == null || !mounted) return;

    setState(() {
      _titreController.text = selected.seance.titre;
      _blocs
        ..clear()
        ..addAll(selected.seance.blocs.map((bloc) => bloc.copy(asNew: true)));
      _loadedPlanifieeId =
          selected.isPlanifiee ? selected.seance.id : null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          selected.isPlanifiee
              ? 'Séance planifiée « ${selected.seance.titre} » chargée.'
              : 'Modèle « ${selected.seance.titre} » chargé.',
        ),
      ),
    );
  }

  Future<void> _saveSeance() async {
    if (_isSaving) return;

    final titre = _titreController.text.trim();
    if (titre.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Indique un titre de séance.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    _pauseChrono();

    try {
      final db = context.read<DatabaseService>();
      final now = DateTime.now();
      final planifieeId = _loadedPlanifieeId;

      if (planifieeId != null) {
        final existing = db.getSeance(planifieeId);
        final updated = Seance(
          id: planifieeId,
          titre: titre,
          date: now,
          athleteIds: _selectedAthleteIds.toList(),
          blocs: _blocs.map((bloc) => bloc.copy()).toList(),
          isTemplate: false,
          estPlanifiee: false,
          datePrevue: existing?.datePrevue,
        );
        await db.updateSeance(updated);
      } else {
        final seance = Seance(
          titre: titre,
          date: now,
          athleteIds: _selectedAthleteIds.toList(),
          blocs: _blocs.map((bloc) => bloc.copy()).toList(),
          isTemplate: false,
          estPlanifiee: false,
        );
        await db.addSeance(seance);
      }

      if (!mounted) return;

      setState(() {
        _titreController.clear();
        _blocs.clear();
        _selectedAthleteIds.clear();
        _loadedPlanifieeId = null;
        _elapsed = Duration.zero;
        _isRunning = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Séance sauvegardée.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sauvegarde impossible : $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final selectedAthletes = context
        .watch<AthleteProvider>()
        .athletes
        .where((a) => _selectedAthleteIds.contains(a.id))
        .toList();

    return ColoredBox(
      color: colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.panelLabel != null) ...[
                    Text(
                      widget.panelLabel!,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  FilledButton.tonalIcon(
                    onPressed: _loadSeance,
                    icon: const Icon(Icons.event_note),
                    label: const Text('Charger une séance'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _titreController,
                    decoration: const InputDecoration(
                      labelText: 'Titre de la séance',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _showSelectAthletesDialog,
                    icon: const Icon(Icons.group_add),
                    label: const Text('Sélectionner les athlètes'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (selectedAthletes.isEmpty)
                    Text(
                      'Aucun athlète sélectionné',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: selectedAthletes
                          .map(
                            (athlete) => Chip(
                              avatar: const Icon(Icons.person, size: 18),
                              label: Text(athlete.nom),
                            ),
                          )
                          .toList(),
                    ),
                  const SizedBox(height: 16),
                  Card(
                    color: colorScheme.primaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 20,
                      ),
                      child: Column(
                        children: [
                          Text(
                            'Récupération',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: colorScheme.onPrimaryContainer,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _chronoLabel,
                            style: theme.textTheme.displayMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                              color: colorScheme.onPrimaryContainer,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton.filled(
                                onPressed: _isRunning ? null : _startChrono,
                                icon: const Icon(Icons.play_arrow),
                                iconSize: 32,
                                tooltip: 'Start',
                              ),
                              const SizedBox(width: 12),
                              IconButton.filledTonal(
                                onPressed: _isRunning ? _pauseChrono : null,
                                icon: const Icon(Icons.pause),
                                iconSize: 32,
                                tooltip: 'Pause',
                              ),
                              const SizedBox(width: 12),
                              IconButton.outlined(
                                onPressed: _resetChrono,
                                icon: const Icon(Icons.replay),
                                iconSize: 32,
                                tooltip: 'Reset',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.tonalIcon(
                    onPressed: () => _addOrEditBloc(),
                    icon: const Icon(Icons.add),
                    label: const Text('Ajouter un bloc'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Blocs (${_blocs.length})',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_blocs.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Text(
                        'Aucun bloc pour l\'instant',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  else
                    ...List.generate(_blocs.length, (index) {
                      final bloc = _blocs[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 2,
                        child: ExpansionTile(
                          leading: CircleAvatar(child: Text('${index + 1}')),
                          title: Text(
                            bloc.nom,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                [
                                  '${bloc.exercices.length} exercice(s)',
                                  if (bloc.tempsRecuperation.isNotEmpty)
                                    'Récup ${bloc.tempsRecuperation}',
                                ].join(' · '),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  IconButton(
                                    tooltip: 'Modifier',
                                    visualDensity: VisualDensity.compact,
                                    icon: const Icon(Icons.edit_outlined),
                                    onPressed: () => _addOrEditBloc(
                                      existing: bloc,
                                      index: index,
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Dupliquer à la suite',
                                    visualDensity: VisualDensity.compact,
                                    icon: const Icon(Icons.copy_outlined),
                                    onPressed: () => _duplicateBloc(index),
                                  ),
                                  IconButton(
                                    tooltip: 'Supprimer',
                                    visualDensity: VisualDensity.compact,
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed: () => _deleteBloc(index),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          children: [
                            BlocExercicesDetails(
                              exercices: bloc.exercices,
                              dense: true,
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
          ),
          Material(
            elevation: 2,
            color: colorScheme.surface,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: FilledButton.icon(
                onPressed: _isSaving ? null : _saveSeance,
                icon: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: Text(
                  _isSaving
                      ? 'Sauvegarde…'
                      : 'Terminer et Sauvegarder la séance',
                ),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                  textStyle: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadSeanceChoice {
  const _LoadSeanceChoice._(this.seance, this.isPlanifiee);

  factory _LoadSeanceChoice.planifiee(Seance seance) =>
      _LoadSeanceChoice._(seance, true);

  factory _LoadSeanceChoice.template(Seance seance) =>
      _LoadSeanceChoice._(seance, false);

  final Seance seance;
  final bool isPlanifiee;
}
