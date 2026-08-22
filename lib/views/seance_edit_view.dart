import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/bloc_entrainement.dart';
import '../models/seance.dart';
import '../services/athlete_provider.dart';
import '../services/database_service.dart';
import '../widgets/bloc_entrainement_dialog.dart';
import '../widgets/media_gallery_dialog.dart';

class SeanceEditView extends StatefulWidget {
  const SeanceEditView({super.key, required this.seanceId});

  final String seanceId;

  @override
  State<SeanceEditView> createState() => _SeanceEditViewState();
}

class _SeanceEditViewState extends State<SeanceEditView> {
  Seance? _seance;
  var _loading = true;
  var _saving = false;

  late TextEditingController _titreController;
  late DateTime _date;
  late List<String> _athleteIds;
  late List<BlocEntrainement> _blocs;

  @override
  void initState() {
    super.initState();
    _titreController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _titreController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final db = context.read<DatabaseService>();
    await db.ensureReady();
    final seance = db.getSeance(widget.seanceId);
    if (!mounted) return;

    if (seance == null) {
      setState(() {
        _seance = null;
        _loading = false;
      });
      return;
    }

    setState(() {
      _seance = seance;
      _titreController.text = seance.titre;
      _date = seance.date;
      _athleteIds = List<String>.from(seance.athleteIds);
      _blocs = seance.blocs.map((b) => b.copy()).toList();
      _loading = false;
    });
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null || !mounted) return;
    setState(() => _date = picked);
  }

  Future<void> _editAthletes() async {
    final athletes = context.read<AthleteProvider>().athletes;
    final draft = Set<String>.from(_athleteIds);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Athlètes de la séance'),
              content: SizedBox(
                width: 420,
                height: 360,
                child: athletes.isEmpty
                    ? const Center(child: Text('Aucun athlète.'))
                    : ListView.builder(
                        itemCount: athletes.length,
                        itemBuilder: (context, index) {
                          final athlete = athletes[index];
                          return CheckboxListTile(
                            value: draft.contains(athlete.id),
                            title: Text(athlete.nom),
                            subtitle: Text('Licence ${athlete.numeroLicence}'),
                            onChanged: (value) {
                              setDialogState(() {
                                if (value ?? false) {
                                  draft.add(athlete.id);
                                } else {
                                  draft.remove(athlete.id);
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
      setState(() => _athleteIds = draft.toList());
    }
  }

  Future<void> _editBloc({BlocEntrainement? existing, int? index}) async {
    final result = await showBlocEntrainementDialog(
      context,
      initial: existing,
      athleteIds: _athleteIds,
    );
    if (result == null || !mounted) return;

    setState(() {
      if (index == null) {
        _blocs.add(result);
      } else {
        _blocs[index] = result;
      }
    });
  }

  void _deleteBloc(int index) {
    setState(() => _blocs.removeAt(index));
  }

  Future<void> _save() async {
    if (_saving || _seance == null) return;

    final titre = _titreController.text.trim();
    if (titre.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Le titre est requis.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final updated = Seance(
        id: _seance!.id,
        titre: titre,
        date: _date,
        athleteIds: List<String>.from(_athleteIds),
        blocs: _blocs.map((b) => b.copy()).toList(),
      );

      await context.read<DatabaseService>().updateSeance(updated);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Séance sauvegardée.')),
      );
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : $error')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteSeance() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer la séance ?'),
        content: const Text('Cette action est définitive.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    await context.read<DatabaseService>().deleteSeance(widget.seanceId);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final allAthletes = context.watch<AthleteProvider>().athletes;

    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_seance == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Séance')),
        body: const Center(child: Text('Séance introuvable.')),
      );
    }

    final selectedAthletes =
        allAthletes.where((a) => _athleteIds.contains(a.id)).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Modifier la séance'),
        actions: [
          IconButton(
            tooltip: 'Supprimer',
            onPressed: _deleteSeance,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          TextField(
            controller: _titreController,
            decoration: const InputDecoration(
              labelText: 'Titre',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _pickDate,
            icon: const Icon(Icons.calendar_today),
            label: Text('Date : ${_formatDate(_date)}'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              alignment: Alignment.centerLeft,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Athlètes',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              FilledButton.tonalIcon(
                onPressed: _editAthletes,
                icon: const Icon(Icons.group),
                label: const Text('Modifier'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (selectedAthletes.isEmpty)
            Text(
              'Aucun athlète sélectionné',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: selectedAthletes
                  .map(
                    (a) => InputChip(
                      label: Text(a.nom),
                      onDeleted: () {
                        setState(() => _athleteIds.remove(a.id));
                      },
                    ),
                  )
                  .toList(),
            ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Blocs (${_blocs.length})',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              FilledButton.tonalIcon(
                onPressed: () => _editBloc(),
                icon: const Icon(Icons.add),
                label: const Text('Ajouter'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_blocs.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'Aucun bloc',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else
            ...List.generate(_blocs.length, (index) {
              final bloc = _blocs[index];
              final chronosLabel = bloc.chronos
                  .map((c) {
                    final nom = allAthletes
                            .where((a) => a.id == c.athleteId)
                            .map((a) => a.nom)
                            .firstOrNull ??
                        c.athleteId;
                    return '$nom: ${c.chrono}';
                  })
                  .join(' · ');
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(child: Text('${index + 1}')),
                  title: Text(bloc.titreAffiche),
                  subtitle: Text(
                    [
                      bloc.typeBloc,
                      if (chronosLabel.isNotEmpty) chronosLabel,
                      if (bloc.notes.isNotEmpty) bloc.notes,
                    ].join('\n'),
                  ),
                  isThreeLine:
                      chronosLabel.isNotEmpty || bloc.notes.isNotEmpty,
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
                        tooltip: 'Modifier',
                        icon: const Icon(Icons.edit),
                        onPressed: () =>
                            _editBloc(existing: bloc, index: index),
                      ),
                      IconButton(
                        tooltip: 'Supprimer',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _deleteBloc(index),
                      ),
                    ],
                  ),
                ),
              );
            }),
          const SizedBox(height: 100),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save),
            label: Text(
              _saving ? 'Sauvegarde…' : 'Enregistrer les modifications',
            ),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
            ),
          ),
        ),
      ),
    );
  }
}
