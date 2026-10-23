import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/money/money.dart';
import '../../../../core/money/money_format.dart';
import '../../../../core/theme/tokens.dart';
import '../ui_format.dart';
import 'chart_style.dart';

/// Two bars per slot (income and expense, money in and out) on one axis, with
/// the difference as a line over them. Used for periods and for workspaces.
class PairBarChart extends StatelessWidget {
  const PairBarChart({
    super.key,
    required this.labels,
    required this.first,
    required this.second,
    required this.currency,
    required this.firstName,
    required this.secondName,
    this.net,
    this.netName,
  });

  final List<String> labels;
  final List<int> first;
  final List<int> second;
  final List<int>? net;
  final String currency;
  final String firstName;
  final String secondName;
  final String? netName;

  static const _bottom = 28.0;
  static const _left = 44.0;

  @override
  Widget build(BuildContext context) {
    final k = context.tokens;
    final lang = langOf(context);
    final n = labels.length;
    final (lo, hi) = axisBounds([
      for (final v in [...first, ...second, ...?net]) chartValue(v, currency),
    ]);
    final axis = axisStyle(context);

    Widget bottom(double v, TitleMeta _) {
      final i = v.round();
      if (v != i || i < 0 || i >= n || !showTick(i, n)) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(labels[i], style: axis, maxLines: 1, overflow: TextOverflow.clip),
      );
    }

    Widget left(double v, TitleMeta meta) =>
        v == meta.max || (v == meta.min && v != 0) ? const SizedBox.shrink() : Text(axisLabel(v), style: axis);

    FlTitlesData titles({required bool visible}) => FlTitlesData(
      topTitles: const AxisTitles(),
      rightTitles: const AxisTitles(),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: _bottom,
          getTitlesWidget: visible ? bottom : (_, _) => const SizedBox.shrink(),
        ),
      ),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: _left,
          getTitlesWidget: visible ? left : (_, _) => const SizedBox.shrink(),
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ChartLegend([
          (k.success, firstName, false),
          (k.danger, secondName, false),
          if (net != null) (k.text, netName ?? '', true),
        ]),
        const SizedBox(height: 12),
        Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(
            height: 220,
            child: LayoutBuilder(
              builder: (context, box) {
                final rod = ((box.maxWidth - _left) / (n == 0 ? 1 : n) / 3).clamp(3.0, 16.0);
                return Stack(
                  children: [
                    BarChart(
                      BarChartData(
                        minY: lo,
                        maxY: hi,
                        alignment: BarChartAlignment.spaceAround,
                        titlesData: titles(visible: true),
                        borderData: FlBorderData(show: false),
                        gridData: FlGridData(
                          drawVerticalLine: false,
                          getDrawingHorizontalLine: (v) =>
                              FlLine(color: v == 0 ? k.textMuted.withValues(alpha: 0.5) : k.border, strokeWidth: 1),
                        ),
                        barTouchData: BarTouchData(
                          touchTooltipData: BarTouchTooltipData(
                            getTooltipColor: (_) => k.surfaceHigh,
                            tooltipBorder: BorderSide(color: k.border),
                            maxContentWidth: 180,
                            getTooltipItem: (group, gi, rod, ri) => BarTooltipItem(
                              '${labels[gi]}\n${ri == 0 ? firstName : secondName}: '
                              '${formatMoney(Money(ri == 0 ? first[gi] : second[gi], currency), localeCode: lang)}',
                              TextStyle(color: k.text, fontSize: 12),
                            ),
                          ),
                        ),
                        barGroups: [
                          for (var i = 0; i < n; i++)
                            BarChartGroupData(
                              x: i,
                              barsSpace: 2,
                              barRods: [
                                _rod(chartValue(first[i], currency), k.success, rod),
                                _rod(chartValue(second[i], currency), k.danger, rod),
                              ],
                            ),
                        ],
                      ),
                    ),
                    if (net != null && n > 0)
                      IgnorePointer(
                        child: LineChart(
                          LineChartData(
                            minX: -0.5,
                            maxX: n - 0.5,
                            minY: lo,
                            maxY: hi,
                            titlesData: titles(visible: false),
                            borderData: FlBorderData(show: false),
                            gridData: const FlGridData(show: false),
                            lineTouchData: const LineTouchData(enabled: false),
                            lineBarsData: [
                              LineChartBarData(
                                spots: [
                                  for (var i = 0; i < n; i++) FlSpot(i.toDouble(), chartValue(net![i], currency)),
                                ],
                                color: k.text,
                                barWidth: 2,
                                dotData: FlDotData(
                                  getDotPainter: (_, _, _, _) => FlDotCirclePainter(
                                    radius: 4,
                                    color: k.text,
                                    strokeWidth: 2,
                                    strokeColor: k.surface,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  BarChartRodData _rod(double v, Color color, double width) => BarChartRodData(
    toY: v,
    color: color,
    width: width,
    borderRadius: v >= 0
        ? const BorderRadius.vertical(top: Radius.circular(4))
        : const BorderRadius.vertical(bottom: Radius.circular(4)),
  );
}
