import 'package:flutter/material.dart';

import '../../../../core/l10n/ckb_fallback_localizations.dart';
import '../../../../core/money/money.dart';
import '../../../../core/money/money_format.dart';
import '../../../../core/theme/tokens.dart';
import '../../data/categories_repository.dart' show bucketLabel;
import '../../domain/buckets_math.dart';
import '../ui_format.dart';
import '../widgets/money_text.dart';
import '../widgets/usage_bar.dart';

/// Spent against allocated per bucket, in the usage colours of the Buckets screen.
class BucketBars extends StatelessWidget {
  const BucketBars({super.key, required this.statuses, required this.currency});

  final List<BucketStatus> statuses;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final k = context.tokens;
    final text = Theme.of(context).textTheme;
    final lang = langOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final s in statuses)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        bucketLabel(s.bucket, l),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodyMedium?.copyWith(color: k.text),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: FittedMoney(
                        Money(s.availableMinor, currency),
                        style: text.bodyMedium?.copyWith(color: k.text),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                UsageBar(
                  barKey: ValueKey('report-bucket-${s.bucket.id}'),
                  valueBp: s.usedBp ?? 0,
                  color: usageColor(k, s.usedBp),
                ),
                const SizedBox(height: 4),
                Text(
                  '${l.finSpent} ${formatMoney(Money(s.spentMinor, currency), localeCode: lang)} · '
                  '${l.finAllocated} ${formatMoney(Money(s.allocatedMinor, currency), localeCode: lang)}',
                  style: text.bodySmall?.copyWith(color: k.textMuted),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
