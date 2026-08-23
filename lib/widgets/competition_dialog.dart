import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/competition.dart';
import '../services/athlete_provider.dart';

Future<Competition?> showCompetitionDialog(
  BuildContext context, {
  Competition? initial,
  DateTime? defaultDay,
}) {
  return showDialog<Competition>(
    context: context,
    builder: (_) => _CompetitionDialog(
      initial: initial,
      defaultDay: defaultDay,
    ),
  );
}

class _CompetitionDialog extends StatefulWidget {
  const _CompetitionDialog({
    this.initial,
    this.defaultDay,
  });

  final Competition? initial;
  final DateTime? defaultDay;

  @override
  State<_CompetitionDialog> createState() => _CompetitionDialogState();
}

class _CompetitionDialogState extends State<_CompetitionDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titreController;
  late final TextEditingController _lieuController;
  late DateTime _dateDebut;
  late DateTime _dateFin;
  late Set<String> _athleteIds;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    final fallback = widget.defaultDay ?? DateTime.now();
    final day = DateTime(fallback.year, fallback.month, fallback.day);
    _titreController = TextEditingController(text: initial?.titre ?? '');
    _lieuController = TextEditingController(text: initial?.lieu ?? '');
    _dateDebut = initial != null
        ? DateTime(
            initial.dateDebut.year,
            initial.dateDebut.month,
            initial.dateDebut.day,
          )
        : day;
    _dateFin = initial != null
        ? DateTime(
            initial.dateFin.year,
            initial.dateFin.month,
            initial.dateFin.day,
          )
        : day;
    _athleteIds = Set<String>.from(initial?.athleteIds ?? const []);
  }

  @override
  void dispose() {
    _titreController.dispose();
    _lieuController.dispose();
    super.dispose();
  }

  String _formatDay(DateTime d) => DateFormat('dd/MM/yyyy').format(d);

  Future<void> _pickDate({required bool isStart}) async {
    final initial = isStart ? _dateDebut : _dateFin;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      locale: const Locale('fr', 'FR'),
    );
    if (picked == null || !mounted) return;
    setState(() {
      final day = DateTime(picked.year, picked.month, picked.day);
      if (isStart) {
        _dateDebut = day;
        if (_dateFin.isBefore(_dateDebut)) _dateFin = _dateDebut;
      } else {
        _dateFin = day;
        if (_dateFin.isBefore(_dateDebut)) _dateDebut = _dateFin;
      }
    });
  }

  Future<void> _pickAthletes() async {
    final athletes = context.read<AthleteProvider>().athletes;
    final draft = Set<String>.from(_athleteIds);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            return AlertDialog(
              title: const Text('Athlètes concernés'),
              content: SizedBox(
                width: 420,
                height: 360,
                child: athletes.isEmpty
                    ? const Center(child: Text('Aucun athlète.'))
                    : ListView.builder(
                        itemCount: athletes.length,
                        itemBuilder: (context, index) {
                          final athlete = athletes[index];
                          final selected = draft.contains(athlete.id);
                          return CheckboxListTile(
                            value: selected,
                            title: Text(athlete.nom),
                            onChanged: (value) {
                              setLocal(() {
                                if (value == true) {
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
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Annuler'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Valider'),
                ),
              ],
            );
          },
        );
      },
    );
    if (confirmed == true && mounted) {
      setState(() => _athleteIds = draft);
    }
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(
      Competition(
        id: widget.initial?.id,
        titre: _titreController.text.trim(),
        dateDebut: _dateDebut,
        dateFin: _dateFin,
        lieu: _lieuController.text.trim(),
        athleteIds: _athleteIds.toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.initial != null;
    final athletes = context.watch<AthleteProvider>().athletes;
    final names = athletes
        .where((a) => _athleteIds.contains(a.id))
        .map((a) => a.nom)
        .join(', ');

    return AlertDialog(
      title: Text(isEdit ? 'Modifier la compétition' : 'Nouvelle compétition'),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _titreController,
                  decoration: const InputDecoration(
                    labelText: 'Titre',
                    hintText: 'ex: Championnats régionaux',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Requis';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _lieuController,
                  decoration: const InputDecoration(
                    labelText: 'Lieu',
                    hintText: 'ex: Stade Jean Bouin',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => _pickDate(isStart: true),
                  icon: const Icon(Icons.event),
                  label: Text('Début : ${_formatDay(_dateDebut)}'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    alignment: Alignment.centerLeft,
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => _pickDate(isStart: false),
                  icon: const Icon(Icons.event_available),
                  label: Text('Fin : ${_formatDay(_dateFin)}'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    alignment: Alignment.centerLeft,
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _pickAthletes,
                  icon: const Icon(Icons.people_outline),
                  label: Text(
                    _athleteIds.isEmpty
                        ? 'Sélectionner des athlètes'
                        : '${_athleteIds.length} athlète(s)',
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    alignment: Alignment.centerLeft,
                  ),
                ),
                if (names.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    names,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Valider'),
        ),
      ],
    );
  }
}
