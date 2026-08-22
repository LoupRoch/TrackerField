import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/athlete.dart';
import '../services/athlete_provider.dart';
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

    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  ResolvedCircleAvatar(
                    storedPath: athlete.photoPath,
                    radius: 32,
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
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$_age ans',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          'Licence ${athlete.numeroLicence}',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: colorScheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.cake_outlined,
                      color: colorScheme.onTertiaryContainer,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Granolas dûs',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: colorScheme.onTertiaryContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      '${athlete.detteGateau}',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: colorScheme.onTertiaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: athlete.detteGateau > 0
                          ? () => provider.decrementDetteGateau(athlete.id)
                          : null,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(56),
                        textStyle: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      child: const Text('-1 cookie'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () =>
                          provider.incrementDetteGateau(athlete.id),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(56),
                        textStyle: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      child: const Text('+1 cookie'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
