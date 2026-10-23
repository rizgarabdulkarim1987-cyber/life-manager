import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/security/money_privacy.dart';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/money/money.dart';
import '../../../../core/money/money_format.dart';
import '../../../../core/theme/tokens.dart';
import '../ui_format.dart';
import 'chart_style.dart';

/// Closing balance per day as one line, with a crosshair tooltip.
class BalanceLineChart extends ConsumerWidget {
  const BalanceLineChart({super.key, required this.points, required this.currency});

  final List<(DateTime, int)> points;
  final String currency;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shown = moneyShownOf(ref);
    final k = context.tokens;
    final lang = langOf(context);
    final axis = axisStyle(context);
    final n = points.length;
    final (lo, hi) = axisBounds([for (final p in points) chartValue(p.$2, currency)]);
    return Directionality(
      textDirection: TextDirection.ltr,
      child: SizedBox(
        height: 220,
        child: LineChart(
          LineChartData(
            minY: lo,
            maxY: hi,
            borderData: FlBorderData(show: false),
            gridData: FlGridData(
              drawVerticalLine: false,
              getDrawingHorizontalLine: (v) =>
                  FlLine(color: v == 0 ? k.textMuted.withValues(alpha: 0.5) : k.border, strokeWidth: 1),
            ),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(),
              rightTitles: const AxisTitles(),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 44,
                  getTitlesWidget: (v, meta) =>
                      !shown || v == meta.max ? const SizedBox.shrink() : Text(axisLabel(v), style: axis),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  interval: 1,
                  getTitlesWidget: (v, _) {
                    final i = v.round();
                    if (v != i || i < 0 || i >= n || !showTick(i, n)) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text('${points[i].$1.day}/${points[i].$1.month}', style: axis),
                    );
                  },
                ),
              ),
            ),
            lineTouchData: LineTouchData(
              getTouchedSpotIndicator: (_, spots) => [
                for (final _ in spots)
                  TouchedSpotIndicatorData(
                    FlLine(color: k.textMuted, strokeWidth: 1),
                    FlDotData(
                      getDotPainter: (_, _, _, _) =>
                          FlDotCirclePainter(radius: 5, color: k.accent, strokeWidth: 2, strokeColor: k.surface),
                    ),
                  ),
              ],
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (_) => k.surfaceHigh,
                tooltipBorder: BorderSide(color: k.border),
                maxContentWidth: 180,
                getTooltipItems: (spots) => [
                  for (final s in spots)
                    LineTooltipItem(
                      '${formatDate(context, points[s.spotIndex].$1)}\n'
                      '${shown ? formatMoney(Money(points[s.spotIndex].$2, currency), localeCode: lang) : kMaskedMoney}',
                      TextStyle(color: k.text, fontSize: 12),
                    ),
                ],
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: [for (var i = 0; i < n; i++) FlSpot(i.toDouble(), chartValue(points[i].$2, currency))],
                color: k.accent,
                barWidth: 2,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(show: true, color: k.accent.withValues(alpha: 0.12)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
