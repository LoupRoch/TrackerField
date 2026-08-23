import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../models/athlete.dart';
import '../models/chrono_athlete.dart';
import '../models/exercice.dart';
import '../services/athlete_provider.dart';
import '../services/database_service.dart';
import '../services/media_storage_service.dart';
import '../utils/dictation_input_mode.dart';
import '../utils/exercise_input_formatters.dart';
import 'dictatable_text_form_field.dart';
import 'dictation_form_scope.dart';
import 'session_autocomplete_field.dart';

Future<Exercice?> showExerciceDialog(
  BuildContext context, {
  Exercice? initial,
  bool templateMode = false,
  List<String> athleteIds = const [],
}) {
  final db = context.read<DatabaseService>();
  final athletes = context.read<AthleteProvider>().athletes;
  return showDialog<Exercice>(
    context: context,
    builder: (_) => _ExerciceDialog(
      initial: initial,
      templateMode: templateMode,
      athleteIds: athleteIds,
      athletes: athletes,
      distanceSuggestions: db.getDistinctDistances(),
      nomSuggestions: db.getDistinctNomExercices(),
      recupSuggestions: db.getDistinctTempsRecuperation(),
    ),
  );
}

class _ExerciceDialog extends StatefulWidget {
  const _ExerciceDialog({
    this.initial,
    required this.templateMode,
    required this.athleteIds,
    required this.athletes,
    required this.distanceSuggestions,
    required this.nomSuggestions,
    required this.recupSuggestions,
  });

  final Exercice? initial;
  final bool templateMode;
  final List<String> athleteIds;
  final List<Athlete> athletes;
  final List<String> distanceSuggestions;
  final List<String> nomSuggestions;
  final List<String> recupSuggestions;

  @override
  State<_ExerciceDialog> createState() => _ExerciceDialogState();
}

class _ExerciceDialogState extends State<_ExerciceDialog> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();
  final _distanceKey = GlobalKey<SessionAutocompleteFieldState>();
  final _nomKey = GlobalKey<SessionAutocompleteFieldState>();
  final _recupKey = GlobalKey<SessionAutocompleteFieldState>();
  late final TextEditingController _notesController;
  final Map<String, TextEditingController> _chronoControllers = {};

  late String _type;
  late List<String> _mediaPaths;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _type = initial?.type ?? Exercice.types.first;
    _notesController = TextEditingController(text: initial?.notes ?? '');
    _mediaPaths = List<String>.from(initial?.mediaPaths ?? const []);

    final existingChronos = {
      for (final c in initial?.chronos ?? const <ChronoAthlete>[])
        c.athleteId: c.chrono,
    };
    for (final id in widget.athleteIds) {
      _chronoControllers[id] = TextEditingController(
        text: existingChronos[id] ?? '',
      );
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    for (final c in _chronoControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickMedia() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo),
              title: const Text('Photo'),
              onTap: () => Navigator.pop(context, 'image'),
            ),
            ListTile(
              leading: const Icon(Icons.videocam),
              title: const Text('Vidéo'),
              onTap: () => Navigator.pop(context, 'video'),
            ),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;

    final XFile? file = choice == 'video'
        ? await _picker.pickVideo(source: ImageSource.gallery)
        : await _picker.pickImage(
            source: ImageSource.gallery,
            imageQuality: 90,
            requestFullMetadata: false,
          );
    if (file == null || !mounted) return;

    try {
      final persisted = await MediaStorageService.persist(file.path);
      if (!mounted) return;
      setState(() => _mediaPaths.add(persisted));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible d\'enregistrer le média.')),
      );
    }
  }

  String _athleteName(String id) {
    for (final a in widget.athletes) {
      if (a.id == id) return a.nom;
    }
    return id;
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final recup = _recupKey.currentState?.value ?? '';
    if (recup.isEmpty) return;

    final isCourse = _type == 'Course';
    final distance = isCourse ? (_distanceKey.currentState?.value ?? '') : null;
    final nom = isCourse ? null : (_nomKey.currentState?.value ?? '');

    if (isCourse && (distance == null || distance.isEmpty)) return;
    if (!isCourse && (nom == null || nom.isEmpty)) return;

    final chronos = <ChronoAthlete>[];
    if (isCourse && !widget.templateMode) {
      for (final entry in _chronoControllers.entries) {
        chronos.add(
          ChronoAthlete(
            athleteId: entry.key,
            chrono: entry.value.text.trim(),
          ),
        );
      }
    }

    Navigator.of(context).pop(
      Exercice(
        id: widget.initial?.id,
        type: _type,
        nom: isCourse ? null : nom,
        distance: isCourse ? distance : null,
        tempsRecuperation: recup,
        notes: widget.templateMode ? '' : _notesController.text.trim(),
        mediaPaths:
            widget.templateMode ? const [] : List<String>.from(_mediaPaths),
        chronos: chronos,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.initial != null;
    final initial = widget.initial;
    final isCourse = _type == 'Course';
    final showChronos =
        isCourse && !widget.templateMode && widget.athleteIds.isNotEmpty;

    return AlertDialog(
      title: Text(isEdit ? 'Modifier l\'exercice' : 'Ajouter un exercice'),
      content: SizedBox(
        width: 480,
        child: DictationFormScope(
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Type',
                    border: OutlineInputBorder(),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _type,
                      items: Exercice.types
                          .map(
                            (type) => DropdownMenuItem(
                              value: type,
                              child: Text(type),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _type = value);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (isCourse)
                  SessionAutocompleteField(
                    key: _distanceKey,
                    labelText: 'Distance',
                    hintText: 'ex: 200 ou 12,5',
                    suggestions: widget.distanceSuggestions,
                    initialValue: initial?.distance ?? '',
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: ExerciseInputFormatters.numericComma,
                    dictationMode: DictationInputMode.numericComma,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Requis';
                      }
                      return null;
                    },
                  )
                else
                  SessionAutocompleteField(
                    key: _nomKey,
                    labelText: 'Nom de l\'exercice',
                    hintText: 'ex: Squat ou Triple saut',
                    suggestions: widget.nomSuggestions,
                    initialValue: initial?.nom ?? '',
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Requis';
                      }
                      return null;
                    },
                  ),
                const SizedBox(height: 12),
                SessionAutocompleteField(
                  key: _recupKey,
                  labelText: 'Temps de récupération',
                  hintText: 'ex: 1:00',
                  suggestions: widget.recupSuggestions,
                  initialValue: initial?.tempsRecuperation ?? '',
                  suffixText: 'min:sec',
                  keyboardType: TextInputType.datetime,
                  inputFormatters: ExerciseInputFormatters.timeColon,
                  dictationMode: DictationInputMode.timeColon,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Requis';
                    }
                    return null;
                  },
                ),
                if (!widget.templateMode) ...[
                  const SizedBox(height: 12),
                  DictatableTextFormField(
                    controller: _notesController,
                    mode: DictationInputMode.freeText,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Notes',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      IconButton.filledTonal(
                        tooltip: 'Ajouter photo ou vidéo',
                        onPressed: _pickMedia,
                        icon: const Icon(Icons.photo_camera),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _mediaPaths.isEmpty
                              ? 'Aucun média'
                              : '${_mediaPaths.length} média(s)',
                        ),
                      ),
                    ],
                  ),
                  if (_mediaPaths.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      children: List.generate(_mediaPaths.length, (index) {
                        return InputChip(
                          label: Text('Média ${index + 1}'),
                          onDeleted: () {
                            setState(() => _mediaPaths.removeAt(index));
                          },
                        );
                      }),
                    ),
                ],
                if (showChronos) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Chronos par athlète',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 8),
                  for (final id in widget.athleteIds) ...[
                    DictatableTextFormField(
                      controller: _chronoControllers[id]!,
                      mode: DictationInputMode.numericComma,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: ExerciseInputFormatters.numericComma,
                      decoration: InputDecoration(
                        labelText: _athleteName(id),
                        hintText: 'ex: 24,85',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
              ],
            ),
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
