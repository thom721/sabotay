import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/async_state_views.dart';
import '../data/dashboard_repository.dart';
import '../domain/point_serie_temporelle.dart';

final _montantFormat = NumberFormat.compact(locale: 'fr');

const _periodes = [
  ('jour', 'Jour'),
  ('semaine', 'Semaine'),
  ('mois', 'Mois'),
  ('annee', 'Année'),
];

/// Graphique du tableau de bord : montants collectés/retirés et nouveaux
/// clients, avec un sélecteur de période (jour/semaine/mois/année) — voir
/// GET /dashboard/serie-temporelle.
class StatistiquesChartCard extends ConsumerStatefulWidget {
  const StatistiquesChartCard({super.key});

  @override
  ConsumerState<StatistiquesChartCard> createState() => _StatistiquesChartCardState();
}

class _StatistiquesChartCardState extends ConsumerState<StatistiquesChartCard> {
  String _periode = 'mois';

  @override
  Widget build(BuildContext context) {
    final pointsAsync = ref.watch(serieTemporelleProvider(_periode));

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: [
                Text('Statistiques', style: Theme.of(context).textTheme.titleMedium),
                _PeriodeTabs(
                  selected: _periode,
                  onChanged: (p) => setState(() => _periode = p),
                ),
              ],
            ),
            const SizedBox(height: 16),
            pointsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => ErrorState(
                message: 'Impossible de charger les statistiques',
                onRetry: () => ref.invalidate(serieTemporelleProvider(_periode)),
              ),
              data: (points) => _StatistiquesCharts(points: points),
            ),
          ],
        ),
      ),
    );
  }
}

class _PeriodeTabs extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;
  const _PeriodeTabs({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (value, label) in _periodes)
            InkWell(
              onTap: () => onChanged(value),
              borderRadius: BorderRadius.circular(6),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: selected == value ? colorScheme.surface : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: selected == value ? FontWeight.w600 : FontWeight.normal,
                    color: selected == value ? colorScheme.primary : colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatistiquesCharts extends StatelessWidget {
  final List<PointSerieTemporelle> points;
  const _StatistiquesCharts({required this.points});

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const EmptyState(message: 'Aucune donnée pour cette période');
    }

    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 16,
          children: [
            _Legende(color: colorScheme.secondary, label: 'Collecté'),
            _Legende(color: colorScheme.error, label: 'Retiré'),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 220,
          child: _MontantsLineChart(points: points),
        ),
        const SizedBox(height: 24),
        Text('Nouveaux clients', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 12),
        SizedBox(
          height: 140,
          child: _NouveauxClientsBarChart(points: points),
        ),
      ],
    );
  }
}

class _Legende extends StatelessWidget {
  final Color color;
  final String label;
  const _Legende({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

Widget _bottomLabel(List<PointSerieTemporelle> points, double value, TitleMeta meta) {
  final index = value.toInt();
  if (index < 0 || index >= points.length) return const SizedBox.shrink();
  // Sur "jour" (14 points), afficher un label sur deux évite le chevauchement.
  if (points.length > 10 && index.isOdd) return const SizedBox.shrink();
  return SideTitleWidget(
    axisSide: meta.axisSide,
    child: Text(points[index].label, style: const TextStyle(fontSize: 10)),
  );
}

class _MontantsLineChart extends StatelessWidget {
  final List<PointSerieTemporelle> points;
  const _MontantsLineChart({required this.points});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final maxY = points
        .expand((p) => [p.montantCollecte.toDouble(), p.montantRetrait.toDouble()])
        .fold<double>(0, (max, v) => v > max ? v : max);

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maxY <= 0 ? 10 : maxY * 1.2,
        gridData: FlGridData(
          drawVerticalLine: false,
          horizontalInterval: maxY <= 0 ? 2 : null,
          getDrawingHorizontalLine: (_) => FlLine(color: colorScheme.outline, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              getTitlesWidget: (value, meta) => Text(
                _montantFormat.format(value),
                style: const TextStyle(fontSize: 10),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) => _bottomLabel(points, value, meta),
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: [
              for (var i = 0; i < points.length; i++)
                FlSpot(i.toDouble(), points[i].montantCollecte.toDouble()),
            ],
            isCurved: true,
            color: colorScheme.secondary,
            barWidth: 2,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: true, color: colorScheme.secondary.withValues(alpha: 0.1)),
          ),
          LineChartBarData(
            spots: [
              for (var i = 0; i < points.length; i++)
                FlSpot(i.toDouble(), points[i].montantRetrait.toDouble()),
            ],
            isCurved: true,
            color: colorScheme.error,
            barWidth: 2,
            dotData: const FlDotData(show: false),
          ),
        ],
      ),
    );
  }
}

class _NouveauxClientsBarChart extends StatelessWidget {
  final List<PointSerieTemporelle> points;
  const _NouveauxClientsBarChart({required this.points});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final maxY = points.map((p) => p.nbNouveauxClients).fold<int>(0, (max, v) => v > max ? v : max);

    return BarChart(
      BarChartData(
        minY: 0,
        maxY: maxY <= 0 ? 5 : maxY * 1.2,
        gridData: FlGridData(
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(color: colorScheme.outline, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: 1,
              getTitlesWidget: (value, meta) =>
                  Text(value.toInt().toString(), style: const TextStyle(fontSize: 10)),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) => _bottomLabel(points, value, meta),
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < points.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: points[i].nbNouveauxClients.toDouble(),
                  color: colorScheme.primary,
                  width: 12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
