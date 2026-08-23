import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/athlete.dart';
import '../models/seance.dart';
import '../models/test_performance.dart';
import '../services/athlete_photo_service.dart';
import '../services/athlete_provider.dart';
import '../services/database_service.dart';
import '../services/settings_provider.dart';
import '../widgets/resolved_media_image.dart';
import '../widgets/test_evolution_chart.dart';
import '../widgets/week_assiduite_heatmap.dart';
import 'seance_edit_view.dart';

class AthleteDetailView extends StatefulWidget {
  const AthleteDetailView({super.key, required this.athleteId});

  final String athleteId;

  @override
  State<AthleteDetailView> createState() => _AthleteDetailViewState();
}

class _AthleteDetailViewState extends State<AthleteDetailView> {
  List<TestPerformance> _tests = [];
  List<Seance> _seances = [];
  var _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    final db = context.read<DatabaseService>();
    await db.ensureReady();
    if (!mounted) return;
    setState(() {
      _tests = db.getTestsByAthleteId(widget.athleteId);
      _seances = db.getSeancesByAthleteId(widget.athleteId);
      _loading = false;
    });
  }

  Future<void> _openSeance(Seance seance) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SeanceEditView(seanceId: seance.id),
      ),
    );
    await _loadData();
  }

  int _ageOf(Athlete athlete) {
    final now = DateTime.now();
    var age = now.year - athlete.dateNaissance.year;
    final hadBirthday = now.month > athlete.dateNaissance.month ||
        (now.month == athlete.dateNaissance.month &&
            now.day >= athlete.dateNaissance.day);
    if (!hadBirthday) age--;
    return age;
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  Future<void> _showEditAthleteDialog(Athlete athlete) async {
    final result = await showDialog<Object?>(
      context: context,
      builder: (_) => _EditAthleteDialog(athlete: athlete),
    );
    if (!mounted) return;

    if (result == _EditAthleteResult.deleted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Athlète supprimé.')),
      );
      return;
    }

    if (result == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Athlète mis à jour.')),
      );
    }
  }

  Future<void> _showAddTestDialog() async {
    final result = await showDialog<_TestFormData>(
      context: context,
      builder: (_) => const _TestFormDialog(),
    );
    if (result == null || !mounted) return;

    await context.read<DatabaseService>().addTest(
          TestPerformance(
            athleteId: widget.athleteId,
            typeTest: result.typeTest,
            resultat: result.resultat,
            unite: TestPerformance.unitePour(result.typeTest),
            date: result.date,
          ),
        );

    await _loadData();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Test ajouté.')),
    );
  }

  Future<void> _showEditTestDialog(TestPerformance test) async {
    final result = await showDialog<_TestFormData>(
      context: context,
      builder: (_) => _TestFormDialog(initial: test),
    );
    if (result == null || !mounted) return;

    await context.read<DatabaseService>().updateTest(
          TestPerformance(
            id: test.id,
            athleteId: test.athleteId,
            typeTest: result.typeTest,
            resultat: result.resultat,
            unite: TestPerformance.unitePour(result.typeTest),
            date: result.date,
          ),
        );

    await _loadData();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Test mis à jour.')),
    );
  }

  double? _bestResult(String typeTest) {
    final matching = _tests.where((t) => t.typeTest == typeTest);
    if (matching.isEmpty) return null;
    return matching
        .map((t) => t.resultat)
        .reduce((a, b) => a > b ? a : b);
  }

  Map<DateTime, int> get _assiduiteDatasets {
    final map = <DateTime, int>{};
    for (final seance in _seances) {
      final key = DateTime(
        seance.date.year,
        seance.date.month,
        seance.date.day,
      );
      map[key] = (map[key] ?? 0) + 1;
    }
    return map;
  }

  Map<String, List<TestPerformance>> get _testsByType {
    final map = <String, List<TestPerformance>>{};
    for (final test in _tests) {
      map.putIfAbsent(test.typeTest, () => []).add(test);
    }
    return map;
  }

  Widget _kpiCard({
    required BuildContext context,
    required String title,
    required String value,
    required IconData icon,
    VoidCallback? onEdit,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: colorScheme.primary),
                const Spacer(),
                if (onEdit != null)
                  IconButton(
                    tooltip: 'Éditer',
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit, size: 20),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final athletes = context.watch<AthleteProvider>().athletes;
    final athlete = athletes.where((a) => a.id == widget.athleteId).firstOrNull ??
        context.read<DatabaseService>().getAthlete(widget.athleteId);

    if (athlete == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Athlète')),
        body: const Center(child: Text('Athlète introuvable.')),
      );
    }

    final bestVma = _bestResult('VMA');
    final bestDecabond = _bestResult('Décabond');
    final datasets = _assiduiteDatasets;
    final testsByType = _testsByType;

    return Scaffold(
      appBar: AppBar(
        title: Text(athlete.nom),
        actions: [
          IconButton(
            tooltip: 'Éditer',
            icon: const Icon(Icons.edit),
            onPressed: () => _showEditAthleteDialog(athlete),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_athlete_detail',
        onPressed: _showAddTestDialog,
        icon: const Icon(Icons.science),
        label: const Text('Ajouter un test'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    ResolvedCircleAvatar(
                      storedPath: athlete.photoPath,
                      radius: 40,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            athlete.nom,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Né le ${_formatDate(athlete.dateNaissance)} · Licence ${athlete.numeroLicence}',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // —— Section 1 : KPIs ——
                Text(
                  'Indicateurs clés',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 700;
                    final showGranolas =
                        context.watch<SettingsProvider>().showGranolas;
                    final cards = [
                      if (showGranolas)
                        _kpiCard(
                          context: context,
                          title: 'Dette de granolas',
                          value: '${athlete.detteGateau}',
                          icon: Icons.cake_outlined,
                          onEdit: () => _showEditAthleteDialog(athlete),
                        ),
                      _kpiCard(
                        context: context,
                        title: 'Total séances',
                        value: '${_seances.length}',
                        icon: Icons.fitness_center,
                      ),
                      _kpiCard(
                        context: context,
                        title: 'Records (PB)',
                        value: [
                          'VMA: ${bestVma == null ? '—' : '${bestVma.toStringAsFixed(1)} km/h'}',
                          'Décabond: ${bestDecabond == null ? '—' : '${bestDecabond.toStringAsFixed(2)} m'}',
                        ].join('\n'),
                        icon: Icons.emoji_events_outlined,
                      ),
                    ];

                    if (wide) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (var i = 0; i < cards.length; i++) ...[
                            if (i > 0) const SizedBox(width: 12),
                            Expanded(child: cards[i]),
                          ],
                        ],
                      );
                    }

                    return Column(
                      children: [
                        for (final card in cards) ...[
                          card,
                          const SizedBox(height: 8),
                        ],
                      ],
                    );
                  },
                ),
                const SizedBox(height: 28),

                // —— Section 2 : Heatmap ——
                Text(
                  'Assiduité',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Charge d\'entraînement',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (datasets.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: Text(
                              'Aucune séance enregistrée pour cet athlète.',
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          )
                        else
                          WeekAssiduiteHeatmap(
                            sessionsByDay: datasets,
                            weekCount: 52,
                            cellSize: 11,
                          ),
                        if (_seances.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Text(
                            'Séances',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ..._seances.take(8).map((seance) {
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.event),
                              title: Text(seance.titre),
                              subtitle: Text(
                                '${_formatDate(seance.date)} · ${seance.blocs.length} bloc(s)',
                              ),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => _openSeance(seance),
                            );
                          }),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                // —— Section 3 : Courbes + historique ——
                Text(
                  'Évolution des tests',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                if (_tests.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Aucun test enregistré.\nAjoute un test VMA, Pentabond, Décabond ou Souplesse.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  )
                else ...[
                  ...TestPerformance.types.map((type) {
                    final list = testsByType[type] ?? const [];
                    if (list.length < 2) return const SizedBox.shrink();
                    return TestEvolutionChart(typeTest: type, tests: list);
                  }),
                  const SizedBox(height: 8),
                  Text(
                    'Historique des tests',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ..._tests.map((test) {
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: colorScheme.primaryContainer,
                          child: Icon(
                            Icons.insights,
                            color: colorScheme.onPrimaryContainer,
                          ),
                        ),
                        title: Text(
                          '${test.typeTest} — ${test.resultat} ${test.unite}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(_formatDate(test.date)),
                        trailing: IconButton(
                          tooltip: 'Éditer le test',
                          icon: const Icon(Icons.edit),
                          onPressed: () => _showEditTestDialog(test),
                        ),
                      ),
                    );
                  }),
                ],
                const SizedBox(height: 80),
              ],
            ),
    );
  }
}

enum _EditAthleteResult { deleted }

class _EditAthleteDialog extends StatefulWidget {
  const _EditAthleteDialog({required this.athlete});

  final Athlete athlete;

  @override
  State<_EditAthleteDialog> createState() => _EditAthleteDialogState();
}

class _EditAthleteDialogState extends State<_EditAthleteDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nomController;
  late final TextEditingController _licenceController;
  late final TextEditingController _detteController;
  late DateTime _dateNaissance;
  String? _photoPath;

  @override
  void initState() {
    super.initState();
    _nomController = TextEditingController(text: widget.athlete.nom);
    _licenceController =
        TextEditingController(text: widget.athlete.numeroLicence);
    _detteController =
        TextEditingController(text: '${widget.athlete.detteGateau}');
    _dateNaissance = widget.athlete.dateNaissance;
    _photoPath = widget.athlete.photoPath;
  }

  @override
  void dispose() {
    _nomController.dispose();
    _licenceController.dispose();
    _detteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateNaissance,
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
      helpText: 'Date de naissance',
      initialDatePickerMode: DatePickerMode.year,
    );
    if (picked == null || !mounted) return;
    setState(() => _dateNaissance = picked);
  }

  Future<void> _pickPhoto() async {
    final saved = await pickAndPersistAthletePhoto(context);
    if (saved == null || !mounted) return;
    setState(() => _photoPath = saved);
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmation'),
        content: const Text('Êtes-vous sûr ?'),
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

    await context.read<AthleteProvider>().deleteAthlete(widget.athlete.id);
    if (mounted) Navigator.of(context).pop(_EditAthleteResult.deleted);
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final showGranolas = context.read<SettingsProvider>().showGranolas;
    final dette = showGranolas
        ? int.tryParse(_detteController.text.trim())
        : widget.athlete.detteGateau;
    if (dette == null || dette < 0) return;

    await context.read<AthleteProvider>().updateAthlete(
          id: widget.athlete.id,
          nom: _nomController.text,
          numeroLicence: _licenceController.text,
          dateNaissance: _dateNaissance,
          detteGateau: dette,
          photoPath: _photoPath,
        );

    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final showGranolas = context.watch<SettingsProvider>().showGranolas;
    final dateLabel =
        '${_dateNaissance.day.toString().padLeft(2, '0')}/'
        '${_dateNaissance.month.toString().padLeft(2, '0')}/'
        '${_dateNaissance.year}';

    return AlertDialog(
      title: const Text('Modifier l\'athlète'),
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
                const SizedBox(height: 16),
                if (showGranolas)
                  TextFormField(
                    controller: _detteController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Dette de granolas',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'La dette est requise';
                      }
                      final parsed = int.tryParse(value.trim());
                      if (parsed == null || parsed < 0) {
                        return 'Valeur invalide';
                      }
                      return null;
                    },
                  ),
                if (showGranolas) const SizedBox(height: 24),
                if (!showGranolas) const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: _confirmDelete,
                  icon: Icon(Icons.delete_outline, color: colorScheme.error),
                  label: Text(
                    'Supprimer l\'athlète',
                    style: TextStyle(color: colorScheme.error),
                  ),
                  style: TextButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Enregistrer'),
        ),
      ],
    );
  }
}

class _TestFormData {
  const _TestFormData({
    required this.typeTest,
    required this.resultat,
    required this.date,
  });

  final String typeTest;
  final double resultat;
  final DateTime date;
}

class _TestFormDialog extends StatefulWidget {
  const _TestFormDialog({this.initial});

  final TestPerformance? initial;

  @override
  State<_TestFormDialog> createState() => _TestFormDialogState();
}

class _TestFormDialogState extends State<_TestFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _resultatController;
  late String _typeTest;
  late DateTime _date;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _typeTest = initial?.typeTest ?? TestPerformance.types.first;
    _date = initial?.date ?? DateTime.now();
    _resultatController = TextEditingController(
      text: initial == null ? '' : '${initial.resultat}',
    );
  }

  @override
  void dispose() {
    _resultatController.dispose();
    super.dispose();
  }

  String get _unite => TestPerformance.unitePour(_typeTest);

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: 'Date du test',
    );
    if (picked == null || !mounted) return;
    setState(() => _date = picked);
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final parsed = double.tryParse(
      _resultatController.text.trim().replaceAll(',', '.'),
    );
    if (parsed == null) return;

    Navigator.of(context).pop(
      _TestFormData(typeTest: _typeTest, resultat: parsed, date: _date),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.initial != null;
    final dateLabel =
        '${_date.day.toString().padLeft(2, '0')}/'
        '${_date.month.toString().padLeft(2, '0')}/'
        '${_date.year}';

    return AlertDialog(
      title: Text(isEdit ? 'Modifier le test' : 'Ajouter un test'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Type de test',
                    border: OutlineInputBorder(),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _typeTest,
                      items: TestPerformance.types
                          .map(
                            (type) => DropdownMenuItem(
                              value: type,
                              child: Text(type),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _typeTest = value);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _resultatController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ],
                  decoration: InputDecoration(
                    labelText: 'Résultat',
                    suffixText: _unite,
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Le résultat est requis';
                    }
                    if (double.tryParse(value.trim().replaceAll(',', '.')) ==
                        null) {
                      return 'Nombre invalide';
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
                const SizedBox(height: 8),
                Text(
                  'Unité automatique : $_unite',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
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
          child: const Text('Enregistrer'),
        ),
      ],
    );
  }
}
