import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/athlete_provider.dart';
import '../services/database_service.dart';
import '../services/import_service.dart';
import '../services/settings_provider.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  var _importing = false;

  Future<void> _importExcel() async {
    if (_importing) return;

    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['xlsx', 'xls'],
    );
    if (!mounted) return;
    if (file == null) return;

    final path = file.path;
    if (path == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible de lire le fichier sélectionné.'),
        ),
      );
      return;
    }

    setState(() => _importing = true);
    try {
      final db = context.read<DatabaseService>();
      final summary = await ImportService(db).importFromFile(path);
      if (!mounted) return;
      await context.read<AthleteProvider>().refresh();
      if (!mounted) return;

      final buffer = StringBuffer(summary.message);
      if (summary.warnings.isNotEmpty) {
        buffer.writeln();
        buffer.write(summary.warnings.take(3).join('\n'));
        if (summary.warnings.length > 3) {
          buffer.write('\n…');
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(buffer.toString()),
          duration: const Duration(seconds: 6),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Import impossible : $error')),
      );
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Paramètres'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Fonctionnalités',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: SwitchListTile(
              secondary: const Icon(Icons.cookie_outlined),
              title: const Text('Afficher les Granolas'),
              subtitle: const Text(
                'Masque la dette de granolas sur les cartes et fiches athlètes.',
              ),
              value: settings.showGranolas,
              onChanged: settings.setShowGranolas,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Apparence',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Palette de couleurs',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final palette in AppColorPalette.values)
                        _PaletteChip(
                          palette: palette,
                          selected: settings.palette == palette,
                          onTap: () => settings.setPalette(palette),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Données',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: _importing
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.upload_file),
              title: const Text('Importer depuis Excel'),
              subtitle: const Text(
                'Même format que l\'export (Athlètes, Séances, Compétitions, Tests).',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: _importing ? null : _importExcel,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'L\'import met à jour les athlètes existants (même nom / licence) '
            'et ajoute les séances, compétitions et tests trouvés dans le fichier. '
            'Les médias absents de l\'appareil ne sont pas importés.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _PaletteChip extends StatelessWidget {
  const _PaletteChip({
    required this.palette,
    required this.selected,
    required this.onTap,
  });

  final AppColorPalette palette;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      selected: selected,
      onSelected: (_) => onTap(),
      avatar: CircleAvatar(
        backgroundColor: palette.seedColor,
        radius: 10,
      ),
      label: Text(palette.label),
    );
  }
}
