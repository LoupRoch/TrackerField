import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/athlete_photo_service.dart';
import '../services/athlete_provider.dart';
import '../widgets/athlete_card.dart';
import '../widgets/resolved_media_image.dart';
import 'athlete_detail_view.dart';

class AthletesView extends StatelessWidget {
  const AthletesView({super.key});

  Future<void> _showAddAthleteDialog(BuildContext context) async {
    final result = await showDialog<_NewAthleteData>(
      context: context,
      builder: (_) => const _AddAthleteDialog(),
    );

    if (result == null || !context.mounted) return;

    await context.read<AthleteProvider>().addAthlete(
          nom: result.nom,
          numeroLicence: result.numeroLicence,
          dateNaissance: result.dateNaissance,
          photoPath: result.photoPath,
        );
  }

  @override
  Widget build(BuildContext context) {
    final athletes = context.watch<AthleteProvider>().athletes;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Athlètes'),
      ),
      body: athletes.isEmpty
          ? Center(
              child: Text(
                'Aucun athlète pour le moment.\nAppuie sur + pour en ajouter.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final crossAxisCount = width >= 1200
                    ? 4
                    : width >= 800
                        ? 3
                        : width >= 560
                            ? 2
                            : 1;
                // Hauteur fixe : évite le bottom overflow en portrait téléphone.
                final mainAxisExtent = crossAxisCount == 1
                    ? 220.0
                    : width >= 800
                        ? 280.0
                        : 250.0;

                return GridView.builder(
                  padding: EdgeInsets.all(crossAxisCount == 1 ? 16 : 24),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: crossAxisCount == 1 ? 12 : 20,
                    mainAxisSpacing: crossAxisCount == 1 ? 12 : 20,
                    mainAxisExtent: mainAxisExtent,
                  ),
                  itemCount: athletes.length,
                  itemBuilder: (context, index) {
                    final athlete = athletes[index];
                    return AthleteCard(
                      athlete: athlete,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => AthleteDetailView(
                              athleteId: athlete.id,
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddAthleteDialog(context),
        icon: const Icon(Icons.person_add),
        label: const Text('Ajouter'),
      ),
    );
  }
}

class _NewAthleteData {
  const _NewAthleteData({
    required this.nom,
    required this.numeroLicence,
    required this.dateNaissance,
    this.photoPath,
  });

  final String nom;
  final String numeroLicence;
  final DateTime dateNaissance;
  final String? photoPath;
}

class _AddAthleteDialog extends StatefulWidget {
  const _AddAthleteDialog();

  @override
  State<_AddAthleteDialog> createState() => _AddAthleteDialogState();
}

class _AddAthleteDialogState extends State<_AddAthleteDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nomController = TextEditingController();
  final _licenceController = TextEditingController();

  DateTime? _dateNaissance;
  String? _photoPath;
  var _showDateError = false;

  @override
  void dispose() {
    _nomController.dispose();
    _licenceController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateNaissance ?? DateTime(now.year - 16),
      firstDate: DateTime(1950),
      lastDate: now,
      helpText: 'Date de naissance',
      initialDatePickerMode: DatePickerMode.year,
    );
    if (picked == null || !mounted) return;

    setState(() {
      _dateNaissance = picked;
      _showDateError = false;
    });
  }

  Future<void> _pickPhoto() async {
    final saved = await pickAndPersistAthletePhoto(context);
    if (saved == null || !mounted) return;
    setState(() => _photoPath = saved);
  }

  void _submit() {
    final isFormValid = _formKey.currentState?.validate() ?? false;
    if (_dateNaissance == null) {
      setState(() => _showDateError = true);
    }
    if (!isFormValid || _dateNaissance == null) return;

    Navigator.of(context).pop(
      _NewAthleteData(
        nom: _nomController.text,
        numeroLicence: _licenceController.text,
        dateNaissance: _dateNaissance!,
        photoPath: _photoPath,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final dateLabel = _dateNaissance == null
        ? 'Choisir la date de naissance'
        : '${_dateNaissance!.day.toString().padLeft(2, '0')}/'
            '${_dateNaissance!.month.toString().padLeft(2, '0')}/'
            '${_dateNaissance!.year}';

    return AlertDialog(
      title: const Text('Nouvel athlète'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Column(
                    children: [
                      ResolvedCircleAvatar(
                        storedPath: _photoPath,
                        radius: 48,
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _pickPhoto,
                        icon: const Icon(Icons.camera_alt),
                        label: Text(
                          _photoPath == null
                              ? 'Ajouter une photo'
                              : 'Changer la photo',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nomController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Nom',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Le nom est requis';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _licenceController,
                  decoration: const InputDecoration(
                    labelText: 'Numéro de licence',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Le numéro de licence est requis';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_today),
                  label: Text(dateLabel),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    alignment: Alignment.centerLeft,
                  ),
                ),
                if (_showDateError)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'La date de naissance est requise',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.error,
                      ),
                    ),
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
          onPressed: _submit,
          child: const Text('Ajouter'),
        ),
      ],
    );
  }
}
