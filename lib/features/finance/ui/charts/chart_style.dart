import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show NumberFormat;

import '../../../../core/money/currency.dart';
import '../../../../core/theme/tokens.dart';

/// The only place an amount becomes a double: chart geometry. Figures shown as
/// text are always formatted from the integer minor units.
double chartValue(int minor, String currency) => minor / pow10(currencyExponent(currency)).toDouble();

final _compact = NumberFormat.compact(locale: 'en');

String axisLabel(double v) => _compact.format(v);

/// (min, max) for a value axis that always includes zero, with headroom.
(double, double) axisBounds(Iterable<double> values) {
  var lo = 0.0, hi = 0.0;
  for (final v in values) {
    lo = math.min(lo, v);
    hi = math.max(hi, v);
  }
  if (lo == 0 && hi == 0) return (0, 1);
  return (lo * 1.1, hi * 1.1);
}

/// Labels every n-th point so at most about six fit along the bottom.
bool showTick(int i, int count) => count <= 7 || i % (count / 6).ceil() == 0;

TextStyle axisStyle(BuildContext context) =>
    Theme.of(context).textTheme.labelSmall!.copyWith(color: context.tokens.textMuted);

/// Colour swatches with names above a chart, so identity is never colour alone.
class ChartLegend extends StatelessWidget {
  const ChartLegend(this.items, {super.key});

  /// (colour, name, drawn as a line).
  final List<(Color, String, bool)> items;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme.bodySmall?.copyWith(color: context.tokens.textMuted);
    return Wrap(
      spacing: 16,
      runSpacing: 6,
      children: [
        for (final (color, label, isLine) in items)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: isLine ? 14 : 10,
                height: isLine ? 2 : 10,
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(isLine ? 1 : 3)),
              ),
              const SizedBox(width: 6),
              Text(label, style: text),
            ],
          ),
      ],
    );
  }
}
