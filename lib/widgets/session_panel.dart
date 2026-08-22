import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/bloc_entrainement.dart';
import '../models/seance.dart';
import '../services/athlete_provider.dart';
import '../services/database_service.dart';
import 'bloc_entrainement_dialog.dart';
import 'media_gallery_dialog.dart';

class SessionPanel extends StatefulWidget {
  const SessionPanel({super.key, this.panelLabel});

  final String? panelLabel;

  @override
  State<SessionPanel> createState() => _SessionPanelState();
}

class _SessionPanelState extends State<SessionPanel> {
  final _titreController = TextEditingController();

  final List<BlocEntrainement> _blocs = [];
  final Set<String> _selectedAthleteIds = {};

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

  Future<void> _addBloc() async {
    if (_selectedAthleteIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Sélectionne d\'abord les athlètes (requis pour les courses).',
          ),
        ),
      );
      return;
    }
    final bloc = await showBlocEntrainementDialog(
      context,
      athleteIds: _selectedAthleteIds.toList(),
    );
    if (bloc == null || !mounted) return;
    setState(() => _blocs.add(bloc));
  }

  Future<void> _editBloc(int index) async {
    final bloc = await showBlocEntrainementDialog(
      context,
      initial: _blocs[index],
      athleteIds: _selectedAthleteIds.toList(),
    );
    if (bloc == null || !mounted) return;
    setState(() => _blocs[index] = bloc);
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

  Future<void> _showBlocActions(int index) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Modifier le bloc'),
              onTap: () => Navigator.pop(context, 'edit'),
            ),
            ListTile(
              leading: Icon(
                Icons.delete_outline,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(
                'Supprimer le bloc',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'edit') {
      await _editBloc(index);
    } else if (action == 'delete') {
      await _deleteBloc(index);
    }
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
      final seance = Seance(
        titre: titre,
        date: DateTime.now(),
        athleteIds: _selectedAthleteIds.toList(),
        blocs: _blocs.map((bloc) => bloc.copy()).toList(),
      );

      await context.read<DatabaseService>().addSeance(seance);

      if (!mounted) return;

      setState(() {
        _titreController.clear();
        _blocs.clear();
        _selectedAthleteIds.clear();
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
                    onPressed: _addBloc,
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
                      final athletes = context.read<AthleteProvider>().athletes;
                      final chronosLabel = bloc.chronos
                          .map((c) {
                            final nom = athletes
                                    .where((a) => a.id == c.athleteId)
                                    .map((a) => a.nom)
                                    .firstOrNull ??
                                c.athleteId;
                            return '$nom: ${c.chrono}';
                          })
                          .join(' · ');
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              child: Text('${index + 1}'),
                            ),
                            title: Text(bloc.titreAffiche),
                            subtitle: Text(
                              [
                                bloc.typeBloc,
                                if (chronosLabel.isNotEmpty) chronosLabel,
                                if (bloc.notes.isNotEmpty) bloc.notes,
                              ].join('\n'),
                            ),
                            isThreeLine: chronosLabel.isNotEmpty ||
                                bloc.notes.isNotEmpty,
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (bloc.mediaPaths.isNotEmpty)
                                  IconButton(
                                    tooltip: 'Voir les médias',
                                    icon: Badge(
                                      label: Text('${bloc.mediaPaths.length}'),
                                      child: const Icon(Icons.perm_media),
                                    ),
                                    onPressed: () => showMediaGalleryDialog(
                                      context,
                                      bloc.mediaPaths,
                                    ),
                                  ),
                                IconButton(
                                  tooltip: 'Modifier ou supprimer',
                                  icon: const Icon(Icons.edit_outlined),
                                  onPressed: () => _showBlocActions(index),
                                ),
                              ],
                            ),
                          ),
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
