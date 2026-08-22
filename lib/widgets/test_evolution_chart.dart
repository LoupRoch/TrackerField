import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/test_performance.dart';

class TestEvolutionChart extends StatelessWidget {
  const TestEvolutionChart({
    super.key,
    required this.typeTest,
    required this.tests,
  });

  final String typeTest;
  final List<TestPerformance> tests;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final sorted = List<TestPerformance>.from(tests)
      ..sort((a, b) => a.date.compareTo(b.date));

    if (sorted.length < 2) {
      return const SizedBox.shrink();
    }

    final unite = sorted.first.unite;
    final spots = <FlSpot>[
      for (var i = 0; i < sorted.length; i++)
        FlSpot(i.toDouble(), sorted[i].resultat),
    ];

    final minY = sorted.map((t) => t.resultat).reduce((a, b) => a < b ? a : b);
    final maxY = sorted.map((t) => t.resultat).reduce((a, b) => a > b ? a : b);
    final padding = ((maxY - minY).abs() < 0.001) ? 1.0 : (maxY - minY) * 0.15;

    final dateFormat = DateFormat('dd/MM');

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '$typeTest ($unite)',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 220,
              child: LineChart(
                LineChartData(
                  minX: 0,
                  maxX: (sorted.length - 1).toDouble(),
                  minY: minY - padding,
                  maxY: maxY + padding,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: padding == 0 ? 1 : null,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border.all(color: colorScheme.outlineVariant),
                  ),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 44,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toStringAsFixed(1),
                            style: theme.textTheme.labelSmall,
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        interval: 1,
                        getTitlesWidget: (value, meta) {
                          final index = value.round();
                          if (index < 0 || index >= sorted.length) {
                            return const SizedBox.shrink();
                          }
                          // Évite le chevauchement si beaucoup de points.
                          if (sorted.length > 6 &&
                              index != 0 &&
                              index != sorted.length - 1 &&
                              index % 2 != 0) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              dateFormat.format(sorted[index].date),
                              style: theme.textTheme.labelSmall,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((spot) {
                          final test = sorted[spot.x.round()];
                          return LineTooltipItem(
                            '${DateFormat('dd/MM/yyyy').format(test.date)}\n'
                            '${test.resultat} $unite',
                            TextStyle(
                              color: colorScheme.onInverseSurface,
                              fontWeight: FontWeight.w600,
                            ),
                          );
                        }).toList();
                      },
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      curveSmoothness: 0.25,
                      color: colorScheme.primary,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, bar, index) {
                          return FlDotCirclePainter(
                            radius: 4,
                            color: colorScheme.primary,
                            strokeWidth: 2,
                            strokeColor: colorScheme.surface,
                          );
                        },
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        color: colorScheme.primary.withValues(alpha: 0.12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
