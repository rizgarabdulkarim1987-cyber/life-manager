import 'package:flutter/material.dart';

import '../../../../core/money/money.dart';
import '../../../../core/theme/tokens.dart';
import '../widgets/money_text.dart';

/// Horizontal bars, largest first, each with its name and exact amount.
/// Bars grow from the reading start, so they follow RTL by themselves.
class RankedBars extends StatelessWidget {
  const RankedBars({super.key, required this.rows, required this.currency, this.color});

  final List<(String, int)> rows;
  final String currency;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final k = context.tokens;
    final text = Theme.of(context).textTheme;
    final max = rows.fold<int>(0, (m, r) => r.$2 > m ? r.$2 : m);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (label, minor) in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodyMedium?.copyWith(color: k.text),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: FittedMoney(Money(minor, currency), style: text.bodyMedium?.copyWith(color: k.text)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    height: 8,
                    color: k.surfaceHigh,
                    alignment: AlignmentDirectional.centerStart,
                    child: FractionallySizedBox(
                      widthFactor: max <= 0 || minor <= 0 ? 0 : minor / max,
                      heightFactor: 1,
                      child: ColoredBox(color: color ?? k.accent),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
