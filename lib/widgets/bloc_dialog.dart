import 'package:flutter/material.dart';

import '../models/bloc.dart';
import '../models/exercice.dart';
import 'exercice_dialog.dart';
import 'media_gallery_dialog.dart';
import 'recovery_time_field.dart';

Future<Bloc?> showBlocDialog(
  BuildContext context, {
  Bloc? initial,
  bool templateMode = false,
  List<String> athleteIds = const [],
}) {
  return showDialog<Bloc>(
    context: context,
    builder: (_) => _BlocDialog(
      initial: initial,
      templateMode: templateMode,
      athleteIds: athleteIds,
    ),
  );
}

class _BlocDialog extends StatefulWidget {
  const _BlocDialog({
    this.initial,
    required this.templateMode,
    required this.athleteIds,
  });

  final Bloc? initial;
  final bool templateMode;
  final List<String> athleteIds;

  @override
  State<_BlocDialog> createState() => _BlocDialogState();
}

class _BlocDialogState extends State<_BlocDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nomController;
  final _recupKey = GlobalKey<RecoveryTimeFieldState>();
  late List<Exercice> _exercices;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _nomController = TextEditingController(text: initial?.nom ?? '');
    _exercices = initial?.exercices.map((e) => e.copy()).toList() ?? [];
  }

  @override
  void dispose() {
    _nomController.dispose();
    super.dispose();
  }

  Future<void> _addOrEditExercice({Exercice? existing, int? index}) async {
    final result = await showExerciceDialog(
      context,
      initial: existing,
      templateMode: widget.templateMode,
      athleteIds: widget.athleteIds,
    );
    if (result == null || !mounted) return;
    setState(() {
      if (index == null) {
        _exercices.add(result);
      } else {
        _exercices[index] = result;
      }
    });
  }

  void _duplicateExercice(int index) {
    setState(() {
      _exercices.insert(index + 1, _exercices[index].copy(asNew: true));
    });
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_exercices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ajoute au moins un exercice.')),
      );
      return;
    }

    Navigator.of(context).pop(
      Bloc(
        id: widget.initial?.id,
        nom: _nomController.text.trim(),
        tempsRecuperation: _recupKey.currentState?.value ?? '',
        exercices: _exercices.map((e) => e.copy()).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.initial != null;
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(isEdit ? 'Modifier le bloc' : 'Ajouter un bloc'),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _nomController,
                  decoration: const InputDecoration(
                    labelText: 'Nom du bloc',
                    hintText: 'ex: Travail Lactique',
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
                RecoveryTimeField(
                  key: _recupKey,
                  initialValue: widget.initial?.tempsRecuperation ?? '',
                ),
                const SizedBox(height: 16),
                FilledButton.tonalIcon(
                  onPressed: () => _addOrEditExercice(),
                  icon: const Icon(Icons.add),
                  label: const Text('Ajouter un exercice'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Exercices (${_exercices.length})',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                if (_exercices.isEmpty)
                  Text(
                    'Aucun exercice dans ce bloc.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  )
                else
                  ...List.generate(_exercices.length, (index) {
                    final exercice = _exercices[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 12, 8, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(child: Text('${index + 1}')),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        exercice.titreAffiche,
                                        style: theme.textTheme.titleSmall
                                            ?.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        exercice.type,
                                        style:
                                            theme.textTheme.bodySmall?.copyWith(
                                          color: theme
                                              .colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Align(
                              alignment: Alignment.centerRight,
                              child: Wrap(
                                spacing: 0,
                                runSpacing: 0,
                                children: [
                                  if (exercice.mediaPaths.isNotEmpty)
                                    IconButton(
                                      tooltip: 'Médias',
                                      icon: Badge(
                                        label: Text(
                                          '${exercice.mediaPaths.length}',
                                        ),
                                        child: const Icon(Icons.perm_media),
                                      ),
                                      onPressed: () => showMediaGalleryDialog(
                                        context,
                                        exercice.mediaPaths,
                                      ),
                                    ),
                                  IconButton(
                                    tooltip: 'Modifier',
                                    icon: const Icon(Icons.edit_outlined),
                                    onPressed: () => _addOrEditExercice(
                                      existing: exercice,
                                      index: index,
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Dupliquer à la suite',
                                    icon: const Icon(Icons.copy_outlined),
                                    onPressed: () =>
                                        _duplicateExercice(index),
                                  ),
                                  IconButton(
                                    tooltip: 'Supprimer',
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed: () {
                                      setState(
                                        () => _exercices.removeAt(index),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
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
