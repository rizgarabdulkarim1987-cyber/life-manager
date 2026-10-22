import 'package:flutter/material.dart';

import '../../../../core/l10n/ckb_fallback_localizations.dart';
import '../../../../core/theme/tokens.dart';
import '../../data/rates_repository.dart';
import '../ui_format.dart';
import 'money_text.dart';

Future<void> showHowConverted(BuildContext context, Consolidated c) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  builder: (_) => HowConvertedSheet(c),
);

/// Every line of a consolidated figure: original, rate and its date,
/// converted value, then the subtotals per currency (spec §10.2).
class HowConvertedSheet extends StatelessWidget {
  const HowConvertedSheet(this.c, {super.key});

  final Consolidated c;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final k = context.tokens;
    final text = Theme.of(context).textTheme;
    final muted = text.bodySmall?.copyWith(color: k.textMuted);
    final lines = [...c.lines.where((x) => x.original.minor != 0)];

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.8),
        child: ListView(
          key: const ValueKey('how-converted'),
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            Text(l.finHowConverted, style: text.titleLarge?.copyWith(color: k.text)),
            const SizedBox(height: 16),
            for (final line in lines)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(child: FittedMoney(line.original, alignment: AlignmentDirectional.centerStart)),
                        const SizedBox(width: 12),
                        Icon(Icons.arrow_forward_rounded, size: 16, color: k.textMuted),
                        const SizedBox(width: 12),
                        Expanded(
                          child: line.converted == null
                              ? Text(
                                  l.finNoRate,
                                  textAlign: TextAlign.end,
                                  style: text.bodyMedium?.copyWith(color: k.warning),
                                )
                              : FittedMoney(line.converted!, style: text.bodyMedium?.copyWith(color: k.text)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      line.rate == null
                          ? (line.converted == null ? l.finNoRate : l.finSameCurrency)
                          : l.finRateLine(
                              line.rate!.base,
                              formatRateE6(line.rate!.rateE6),
                              line.rate!.quote,
                              formatDate(context, line.rate!.effectiveFrom.toUtc()),
                            ),
                      style: muted,
                    ),
                  ],
                ),
              ),
            Divider(color: k.border, height: 24),
            Text(l.finPerCurrency, style: text.labelLarge?.copyWith(color: k.textMuted)),
            const SizedBox(height: 8),
            for (final e in c.subtotals.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Text(e.key, style: text.bodyMedium?.copyWith(color: k.textMuted)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FittedMoney(e.value, style: text.bodyLarge?.copyWith(color: k.text)),
                    ),
                  ],
                ),
              ),
            if (c.total != null) ...[
              Divider(color: k.border, height: 24),
              Row(
                children: [
                  Text(l.finTotal, style: text.titleMedium?.copyWith(color: k.text)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FittedMoney(c.total!, style: text.titleMedium?.copyWith(color: k.text)),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
