import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../models/athlete.dart';
import '../models/bloc_entrainement.dart';
import '../models/chrono_athlete.dart';
import '../services/athlete_provider.dart';
import '../services/database_service.dart';
import '../services/media_storage_service.dart';
import 'session_autocomplete_field.dart';

Future<BlocEntrainement?> showBlocEntrainementDialog(
  BuildContext context, {
  BlocEntrainement? initial,
  required List<String> athleteIds,
}) {
  final db = context.read<DatabaseService>();
  return showDialog<BlocEntrainement>(
    context: context,
    builder: (_) => _BlocEntrainementDialog(
      initial: initial,
      athleteIds: athleteIds,
      distanceSuggestions: db.getDistinctDistances(),
      exerciceSuggestions: db.getDistinctNomExercices(),
      recupSuggestions: db.getDistinctTempsRecuperation(),
    ),
  );
}

class _BlocEntrainementDialog extends StatefulWidget {
  const _BlocEntrainementDialog({
    this.initial,
    required this.athleteIds,
    required this.distanceSuggestions,
    required this.exerciceSuggestions,
    required this.recupSuggestions,
  });

  final BlocEntrainement? initial;
  final List<String> athleteIds;
  final List<String> distanceSuggestions;
  final List<String> exerciceSuggestions;
  final List<String> recupSuggestions;

  @override
  State<_BlocEntrainementDialog> createState() =>
      _BlocEntrainementDialogState();
}

class _BlocEntrainementDialogState extends State<_BlocEntrainementDialog> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();
  final _distanceKey = GlobalKey<SessionAutocompleteFieldState>();
  final _exerciceKey = GlobalKey<SessionAutocompleteFieldState>();
  final _recupKey = GlobalKey<SessionAutocompleteFieldState>();

  late String _typeBloc;
  late final TextEditingController _notesController;
  late final Map<String, TextEditingController> _chronoControllers;
  late List<String> _mediaPaths;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _typeBloc = initial?.typeBloc ?? BlocEntrainement.types.first;
    _notesController = TextEditingController(text: initial?.notes ?? '');
    _mediaPaths = List<String>.from(initial?.mediaPaths ?? const []);

    final chronosById = {
      for (final c in initial?.chronos ?? <ChronoAthlete>[])
        c.athleteId: c.chrono,
    };
    _chronoControllers = {
      for (final id in widget.athleteIds)
        id: TextEditingController(text: chronosById[id] ?? ''),
    };
  }

  @override
  void dispose() {
    _notesController.dispose();
    for (final controller in _chronoControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  bool get _isCourse => _typeBloc == 'Course';

  List<Athlete> _athletesForChronos(List<Athlete> all) {
    return all.where((a) => widget.athleteIds.contains(a.id)).toList();
  }

  Future<String?> _persistMedia(String sourcePath) async {
    try {
      return await MediaStorageService.persist(sourcePath);
    } catch (_) {
      return null;
    }
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

    final persisted = await _persistMedia(file.path);
    if (!mounted) return;
    if (persisted == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible d\'enregistrer le média.')),
      );
      return;
    }

    setState(() => _mediaPaths.add(persisted));
  }

  void _submit(List<Athlete> selectedAthletes) {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final recup = _recupKey.currentState?.value ?? '';
    if (recup.isEmpty) return;

    if (_isCourse) {
      if (selectedAthletes.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Sélectionne des athlètes pour saisir leurs chronos.',
            ),
          ),
        );
        return;
      }

      final distance = _distanceKey.currentState?.value ?? '';
      if (distance.isEmpty) return;

      final chronos = <ChronoAthlete>[];
      for (final athlete in selectedAthletes) {
        final chrono = _chronoControllers[athlete.id]?.text.trim() ?? '';
        if (chrono.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Indique le chrono de ${athlete.nom}.')),
          );
          return;
        }
        chronos.add(ChronoAthlete(athleteId: athlete.id, chrono: chrono));
      }

      Navigator.of(context).pop(
        BlocEntrainement(
          id: widget.initial?.id,
          typeBloc: _typeBloc,
          distance: distance,
          nomExercice: null,
          tempsRecuperation: recup,
          notes: _notesController.text.trim(),
          mediaPaths: List<String>.from(_mediaPaths),
          chronos: chronos,
        ),
      );
      return;
    }

    final exo = _exerciceKey.currentState?.value ?? '';
    if (exo.isEmpty) return;
    Navigator.of(context).pop(
      BlocEntrainement(
        id: widget.initial?.id,
        typeBloc: _typeBloc,
        nomExercice: exo,
        distance: null,
        tempsRecuperation: recup,
        notes: _notesController.text.trim(),
        mediaPaths: List<String>.from(_mediaPaths),
        chronos: const [],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.initial != null;
    final allAthletes = context.watch<AthleteProvider>().athletes;
    final selectedAthletes = _athletesForChronos(allAthletes);
    final initial = widget.initial;

    return AlertDialog(
      title: Text(isEdit ? 'Modifier le bloc' : 'Ajouter un bloc'),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Type de bloc',
                    border: OutlineInputBorder(),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _typeBloc,
                      items: BlocEntrainement.types
                          .map(
                            (type) => DropdownMenuItem(
                              value: type,
                              child: Text(type),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _typeBloc = value);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (_isCourse) ...[
                  SessionAutocompleteField(
                    key: _distanceKey,
                    labelText: 'Distance',
                    hintText: 'ex: 200m',
                    suggestions: widget.distanceSuggestions,
                    initialValue: initial?.distance ?? '',
                    validator: (value) {
                      if (!_isCourse) return null;
                      if (value == null || value.trim().isEmpty) {
                        return 'Requis pour une course';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Temps d\'effort par athlète',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 8),
                  if (selectedAthletes.isEmpty)
                    Text(
                      'Aucun athlète sélectionné pour cette séance.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    )
                  else
                    ...selectedAthletes.map((athlete) {
                      final controller = _chronoControllers[athlete.id]!;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: TextFormField(
                          controller: controller,
                          decoration: InputDecoration(
                            labelText: athlete.nom,
                            hintText: 'ex: 24.8',
                            prefixIcon: const Icon(Icons.timer_outlined),
                            border: const OutlineInputBorder(),
                            isDense: true,
                          ),
                          validator: (value) {
                            if (!_isCourse) return null;
                            if (value == null || value.trim().isEmpty) {
                              return 'Chrono requis';
                            }
                            return null;
                          },
                        ),
                      );
                    }),
                ] else
                  SessionAutocompleteField(
                    key: _exerciceKey,
                    labelText: 'Nom de l\'exercice',
                    hintText: 'ex: 3x cloche pied',
                    suggestions: widget.exerciceSuggestions,
                    initialValue: initial?.nomExercice ?? '',
                    validator: (value) {
                      if (_isCourse) return null;
                      if (value == null || value.trim().isEmpty) {
                        return 'Requis pour ce type';
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
                  suffixText: ' min/sec',
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Requis';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notesController,
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
                            : '${_mediaPaths.length} média(s) attaché(s)',
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
          onPressed: () => _submit(selectedAthletes),
          child: const Text('Valider'),
        ),
      ],
    );
  }
}
