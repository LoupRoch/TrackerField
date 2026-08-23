import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/exercice.dart';
import '../services/athlete_provider.dart';
import 'media_gallery_dialog.dart';

/// Liste d'exercices d'un bloc, avec chronos athlètes pour les courses.
class BlocExercicesDetails extends StatelessWidget {
  const BlocExercicesDetails({
    super.key,
    required this.exercices,
    this.dense = false,
    this.onExerciseTap,
  });

  final List<Exercice> exercices;
  final bool dense;
  final void Function(Exercice exercice)? onExerciseTap;

  @override
  Widget build(BuildContext context) {
    if (exercices.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Text(
          'Aucun exercice',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      );
    }

    final athletesById = {
      for (final a in context.watch<AthleteProvider>().athletes) a.id: a.nom,
    };

    return Column(
      children: [
        for (final exercice in exercices)
          _ExerciceChronoTile(
            exercice: exercice,
            athletesById: athletesById,
            dense: dense,
            onTap: onExerciseTap == null
                ? null
                : () => onExerciseTap!(exercice),
          ),
      ],
    );
  }
}

class _ExerciceChronoTile extends StatelessWidget {
  const _ExerciceChronoTile({
    required this.exercice,
    required this.athletesById,
    required this.dense,
    this.onTap,
  });

  final Exercice exercice;
  final Map<String, String> athletesById;
  final bool dense;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final filledChronos =
        exercice.chronos.where((c) => c.chrono.trim().isNotEmpty).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: Card(
        color: colorScheme.surfaceContainerHighest,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding:
                EdgeInsets.fromLTRB(12, dense ? 8 : 12, 4, dense ? 8 : 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            exercice.titreAffiche,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            [
                              exercice.type,
                              if (exercice.notes.isNotEmpty) exercice.notes,
                            ].join(' · '),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (exercice.mediaPaths.isNotEmpty)
                      IconButton(
                        tooltip: 'Médias',
                        icon: Badge(
                          label: Text('${exercice.mediaPaths.length}'),
                          child: const Icon(Icons.perm_media),
                        ),
                        onPressed: () => showMediaGalleryDialog(
                          context,
                          exercice.mediaPaths,
                        ),
                      ),
                  ],
                ),
                if (exercice.isCourse) ...[
                  const SizedBox(height: 8),
                  if (exercice.chronos.isEmpty)
                    Text(
                      'Aucun chrono saisi',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
                      ),
                    )
                  else ...[
                    Text(
                      'Chronos',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ...exercice.chronos.map((c) {
                      final name = athletesById[c.athleteId] ?? c.athleteId;
                      final value = c.chrono.trim();
                      final hasValue = value.isNotEmpty;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            Icon(
                              Icons.timer_outlined,
                              size: 18,
                              color: hasValue
                                  ? colorScheme.primary
                                  : colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                name,
                                style: theme.textTheme.bodyMedium,
                              ),
                            ),
                            Text(
                              hasValue ? value : '—',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                                color: hasValue
                                    ? colorScheme.onSurface
                                    : colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    if (filledChronos.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          'Aucun temps renseigné pour le moment',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
