import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/bloc.dart';
import '../models/seance.dart';
import '../services/database_service.dart';
import '../widgets/bloc_dialog.dart';

class ModelesSeanceView extends StatefulWidget {
  const ModelesSeanceView({super.key});

  @override
  State<ModelesSeanceView> createState() => ModelesSeanceViewState();
}

class ModelesSeanceViewState extends State<ModelesSeanceView> {
  List<Seance> _templates = [];
  var _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => reload());
  }

  Future<void> reload() async {
    final db = context.read<DatabaseService>();
    await db.ensureReady();
    if (!mounted) return;
    setState(() {
      _templates = db.getTemplates();
      _loading = false;
    });
  }

  Future<void> _createOrEdit({Seance? existing}) async {
    final result = await showDialog<_TemplateFormResult>(
      context: context,
      builder: (_) => _TemplateEditorDialog(initial: existing),
    );
    if (result == null || !mounted) return;

    final seance = Seance(
      id: existing?.id,
      titre: result.titre,
      date: existing?.date ?? DateTime.now(),
      athleteIds: const [],
      blocs: result.blocs,
      isTemplate: true,
    );

    final db = context.read<DatabaseService>();
    if (existing == null) {
      await db.addSeance(seance);
    } else {
      await db.updateSeance(seance);
    }
    await reload();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          existing == null ? 'Modèle créé.' : 'Modèle mis à jour.',
        ),
      ),
    );
  }

  Future<void> _delete(Seance template) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer le modèle'),
        content: Text('Supprimer « ${template.titre} » ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await context.read<DatabaseService>().deleteSeance(template.id);
    await reload();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Séances prévues'),
        actions: [
          IconButton(
            tooltip: 'Actualiser',
            onPressed: reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_modeles',
        onPressed: () => _createOrEdit(),
        icon: const Icon(Icons.add),
        label: const Text('Nouveau modèle'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _templates.isEmpty
              ? Center(
                  child: Text(
                    'Aucun modèle pour le moment.\nPrépare une séance avec des blocs et exercices.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                  itemCount: _templates.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final template = _templates[index];
                    final exerciceCount = template.blocs.fold<int>(
                      0,
                      (sum, bloc) => sum + bloc.exercices.length,
                    );
                    return Card(
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        leading: CircleAvatar(
                          backgroundColor: colorScheme.secondaryContainer,
                          child: Icon(
                            Icons.event_note,
                            color: colorScheme.onSecondaryContainer,
                          ),
                        ),
                        title: Text(
                          template.titre,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          '${template.blocs.length} bloc(s) · $exerciceCount exercice(s)',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Modifier',
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: () =>
                                  _createOrEdit(existing: template),
                            ),
                            IconButton(
                              tooltip: 'Supprimer',
                              icon: Icon(
                                Icons.delete_outline,
                                color: colorScheme.error,
                              ),
                              onPressed: () => _delete(template),
                            ),
                          ],
                        ),
                        onTap: () => _createOrEdit(existing: template),
                      ),
                    );
                  },
                ),
    );
  }
}

class _TemplateFormResult {
  const _TemplateFormResult({
    required this.titre,
    required this.blocs,
  });

  final String titre;
  final List<Bloc> blocs;
}

class _TemplateEditorDialog extends StatefulWidget {
  const _TemplateEditorDialog({this.initial});

  final Seance? initial;

  @override
  State<_TemplateEditorDialog> createState() => _TemplateEditorDialogState();
}

class _TemplateEditorDialogState extends State<_TemplateEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titreController;
  late List<Bloc> _blocs;

  @override
  void initState() {
    super.initState();
    _titreController = TextEditingController(text: widget.initial?.titre ?? '');
    _blocs = widget.initial?.blocs.map((b) => b.copy()).toList() ?? [];
  }

  @override
  void dispose() {
    _titreController.dispose();
    super.dispose();
  }

  Future<void> _addOrEditBloc({Bloc? existing, int? index}) async {
    final bloc = await showBlocDialog(
      context,
      initial: existing,
      templateMode: true,
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

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_blocs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ajoute au moins un bloc.')),
      );
      return;
    }
    Navigator.of(context).pop(
      _TemplateFormResult(
        titre: _titreController.text.trim(),
        blocs: _blocs.map((b) => b.copy()).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.initial != null;

    return AlertDialog(
      title: Text(isEdit ? 'Modifier le modèle' : 'Nouveau modèle'),
      content: SizedBox(
        width: 560,
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
                    labelText: 'Titre de la séance prévue',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Le titre est requis';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                FilledButton.tonalIcon(
                  onPressed: () => _addOrEditBloc(),
                  icon: const Icon(Icons.add),
                  label: const Text('Ajouter un bloc'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Blocs (${_blocs.length})',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 8),
                if (_blocs.isEmpty)
                  Text(
                    'Aucun bloc — chaque bloc contient des exercices.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  )
                else
                  ...List.generate(_blocs.length, (index) {
                    final bloc = _blocs[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ExpansionTile(
                        leading: CircleAvatar(child: Text('${index + 1}')),
                        title: Text(bloc.nom),
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
                                  onPressed: () {
                                    setState(() => _blocs.removeAt(index));
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                        children: [
                          for (final exercice in bloc.exercices)
                            ListTile(
                              dense: true,
                              title: Text(exercice.titreAffiche),
                              subtitle: Text(exercice.type),
                            ),
                        ],
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
          child: const Text('Enregistrer'),
        ),
      ],
    );
  }
}
