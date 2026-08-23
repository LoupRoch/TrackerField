import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/athlete.dart';
import '../services/athlete_provider.dart';
import '../services/settings_provider.dart';
import 'resolved_media_image.dart';

class AthleteCard extends StatelessWidget {
  const AthleteCard({
    super.key,
    required this.athlete,
    this.onTap,
  });

  final Athlete athlete;
  final VoidCallback? onTap;

  int get _age {
    final now = DateTime.now();
    var age = now.year - athlete.dateNaissance.year;
    final hadBirthday = now.month > athlete.dateNaissance.month ||
        (now.month == athlete.dateNaissance.month &&
            now.day >= athlete.dateNaissance.day);
    if (!hadBirthday) age--;
    return age;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final provider = context.read<AthleteProvider>();
    final showGranolas = context.watch<SettingsProvider>().showGranolas;

    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxHeight < 260 ||
                constraints.maxWidth < 280;
            final avatarRadius = compact ? 24.0 : 32.0;
            final buttonHeight = compact ? 44.0 : 56.0;
            final pad = compact ? 12.0 : 20.0;
            final gap = compact ? 10.0 : 16.0;

            return Padding(
              padding: EdgeInsets.all(pad),
              child: Column(
                mainAxisSize:
                    showGranolas ? MainAxisSize.max : MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      ResolvedCircleAvatar(
                        storedPath: athlete.photoPath,
                        radius: avatarRadius,
                      ),
                      SizedBox(width: compact ? 12 : 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              athlete.nom,
                              style: (compact
                                      ? theme.textTheme.titleLarge
                                      : theme.textTheme.headlineSmall)
                                  ?.copyWith(fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$_age ans',
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            Text(
                              'Licence ${athlete.numeroLicence}',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (showGranolas) ...[
                    const Spacer(flex: 1),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: compact ? 12 : 16,
                        vertical: compact ? 8 : 12,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.tertiaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.cake_outlined,
                            size: compact ? 20 : 24,
                            color: colorScheme.onTertiaryContainer,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Granolas dûs',
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: colorScheme.onTertiaryContainer,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '${athlete.detteGateau}',
                            style: (compact
                                    ? theme.textTheme.titleLarge
                                    : theme.textTheme.headlineMedium)
                                ?.copyWith(
                              color: colorScheme.onTertiaryContainer,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: gap),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: athlete.detteGateau > 0
                                ? () =>
                                    provider.decrementDetteGateau(athlete.id)
                                : null,
                            style: OutlinedButton.styleFrom(
                              minimumSize: Size.fromHeight(buttonHeight),
                              padding: EdgeInsets.symmetric(
                                horizontal: compact ? 8 : 16,
                              ),
                              textStyle: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            child: const Text('-1 granola'),
                          ),
                        ),
                        SizedBox(width: compact ? 8 : 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: () =>
                                provider.incrementDetteGateau(athlete.id),
                            style: FilledButton.styleFrom(
                              minimumSize: Size.fromHeight(buttonHeight),
                              padding: EdgeInsets.symmetric(
                                horizontal: compact ? 8 : 16,
                              ),
                              textStyle: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            child: const Text('+1 granola'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
