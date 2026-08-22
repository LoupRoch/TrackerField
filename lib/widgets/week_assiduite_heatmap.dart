import 'package:flutter/material.dart';

/// Heatmap compacte style GitHub : une case = une semaine.
class WeekAssiduiteHeatmap extends StatelessWidget {
  const WeekAssiduiteHeatmap({
    super.key,
    required this.sessionsByDay,
    this.weekCount = 52,
    this.cellSize = 12,
  });

  /// Séances agrégées par jour (clé = date sans heure).
  final Map<DateTime, int> sessionsByDay;

  /// Nombre de semaines affichées (comme GitHub ≈ 52).
  final int weekCount;

  final double cellSize;

  static const _moisCourts = [
    'janv.',
    'févr.',
    'mars',
    'avr.',
    'mai',
    'juin',
    'juil.',
    'août',
    'sept.',
    'oct.',
    'nov.',
    'déc.',
  ];

  static DateTime _mondayOf(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    return day.subtract(Duration(days: day.weekday - DateTime.monday));
  }

  Map<DateTime, int> get _sessionsByWeek {
    final map = <DateTime, int>{};
    for (final entry in sessionsByDay.entries) {
      final monday = _mondayOf(entry.key);
      map[monday] = (map[monday] ?? 0) + entry.value;
    }
    return map;
  }

  List<DateTime> get _weeks {
    final todayMonday = _mondayOf(DateTime.now());
    return List.generate(
      weekCount,
      (i) => todayMonday.subtract(Duration(days: 7 * (weekCount - 1 - i))),
    );
  }

  Color _colorFor(int count, ColorScheme scheme) {
    if (count <= 0) return scheme.surfaceContainerHighest;
    if (count == 1) return Colors.green.shade200;
    if (count == 2) return Colors.green.shade400;
    if (count == 3) return Colors.green.shade600;
    return Colors.green.shade800;
  }

  String _formatDay(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final byWeek = _sessionsByWeek;
    final weeks = _weeks;

    final monthLabels = <int, String>{};
    for (var i = 0; i < weeks.length; i++) {
      final week = weeks[i];
      if (i == 0 || week.month != weeks[i - 1].month) {
        monthLabels[i] = _moisCourts[week.month - 1];
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 16,
                child: Row(
                  children: [
                    for (var i = 0; i < weeks.length; i++)
                      SizedBox(
                        width: cellSize + 3,
                        child: monthLabels.containsKey(i)
                            ? Text(
                                monthLabels[i]!,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontSize: 9,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                                overflow: TextOverflow.visible,
                              )
                            : const SizedBox.shrink(),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  for (final week in weeks)
                    Padding(
                      padding: const EdgeInsets.only(right: 3),
                      child: Tooltip(
                        message: () {
                          final count = byWeek[week] ?? 0;
                          final end = week.add(const Duration(days: 6));
                          final range =
                              '${_formatDay(week)} – ${_formatDay(end)}';
                          return count == 0
                              ? '$range : aucune séance'
                              : '$range : $count séance${count > 1 ? 's' : ''}';
                        }(),
                        child: Container(
                          width: cellSize,
                          height: cellSize,
                          decoration: BoxDecoration(
                            color: _colorFor(byWeek[week] ?? 0, colorScheme),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Text(
              'Moins',
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 6),
            for (final level in [0, 1, 2, 3, 4])
              Padding(
                padding: const EdgeInsets.only(right: 3),
                child: Container(
                  width: cellSize,
                  height: cellSize,
                  decoration: BoxDecoration(
                    color: _colorFor(level, colorScheme),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            const SizedBox(width: 6),
            Text(
              'Plus',
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
