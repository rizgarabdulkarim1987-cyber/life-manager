import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/providers.dart';
import '../../core/l10n/ckb_fallback_localizations.dart';
import '../../core/money/money.dart';
import '../../core/theme/tokens.dart';
import '../finance/data/categories_repository.dart';
import '../finance/data/finance_providers.dart';
import '../finance/ui/charts/income_expense_chart.dart';
import '../finance/ui/ui_format.dart';
import '../finance/ui/widgets/how_converted_sheet.dart';
import '../finance/ui/widgets/money_text.dart';
import '../finance/ui/widgets/panel.dart';
import '../finance/ui/widgets/usage_bar.dart';

/// This month's income, expense and surplus in the base currency. Opens Reports.
class HomeMonthCard extends ConsumerWidget {
  const HomeMonthCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final k = context.tokens;
    final text = Theme.of(context).textTheme;
    final base = ref.watch(settingsProvider).value?.baseCurrency ?? 'IQD';
    final summary = ref.watch(monthSummaryProvider).value;

    Widget row(String key, String label, Widget value, {TextStyle? labelStyle}) => Padding(
      key: ValueKey(key),
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Text(label, style: labelStyle ?? text.bodyLarge?.copyWith(color: k.textMuted)),
          const SizedBox(width: 16),
          Expanded(child: value),
        ],
      ),
    );

    return Panel(
      key: const ValueKey('home-month-card'),
      onTap: () => context.push('/finance/reports'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l.homeMonthSummary, style: text.titleMedium?.copyWith(color: k.text)),
          const SizedBox(height: 6),
          row(
            'home-month-income',
            l.finIncome,
            FittedMoney(Money(summary?.data.income ?? 0, base), style: text.titleMedium?.copyWith(color: k.text)),
          ),
          row(
            'home-month-expense',
            l.finExpense,
            FittedMoney(Money(summary?.data.expense ?? 0, base), style: text.titleMedium?.copyWith(color: k.text)),
          ),
          Divider(color: k.border, height: 14),
          row(
            'home-month-surplus',
            l.finSurplus,
            FittedMoney(
              Money(summary?.data.surplus ?? 0, base),
              signed: true,
              style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            labelStyle: text.titleMedium?.copyWith(color: k.text),
          ),
          if ((summary?.skippedCount ?? 0) > 0)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                l.finNoTotal(summary!.missingRates.join('، ')),
                style: text.bodySmall?.copyWith(color: k.warning),
              ),
            ),
        ],
      ),
    );
  }
}

/// Income against expenses for the last six months.
class HomeChartCard extends ConsumerWidget {
  const HomeChartCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final k = context.tokens;
    final text = Theme.of(context).textTheme;
    final base = ref.watch(settingsProvider).value?.baseCurrency ?? 'IQD';
    final months = ref.watch(lastSixMonthsProvider).value?.data;
    final locale = dateLocaleOf(context);

    return Panel(
      key: const ValueKey('home-chart-card'),
      onTap: () => context.push('/finance/reports'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l.homeChart, style: text.titleMedium?.copyWith(color: k.text)),
          const SizedBox(height: 12),
          if (months == null)
            const SizedBox(height: 220)
          else
            PairBarChart(
              labels: [for (final m in months) DateFormat.MMM(locale).format(m.period)],
              first: [for (final m in months) m.income],
              second: [for (final m in months) m.expense],
              net: [for (final m in months) m.surplus],
              currency: base,
              firstName: l.finIncome,
              secondName: l.finExpense,
              netName: l.finSurplus,
            ),
        ],
      ),
    );
  }
}

/// One progress bar per bucket for the current month.
class HomeBucketsCard extends ConsumerWidget {
  const HomeBucketsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final k = context.tokens;
    final text = Theme.of(context).textTheme;
    final base = ref.watch(settingsProvider).value?.baseCurrency ?? 'IQD';
    final buckets = ref.watch(bucketStatusProvider).value ?? const [];

    return Panel(
      key: const ValueKey('home-buckets-card'),
      onTap: () => context.push('/finance/buckets'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l.homeBuckets, style: text.titleMedium?.copyWith(color: k.text)),
          for (final s in buckets) ...[
            const SizedBox(height: 14),
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
                    Money(s.availableMinor, base),
                    style: text.bodyMedium?.copyWith(color: s.availableMinor < 0 ? k.danger : k.text),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            UsageBar(
              barKey: ValueKey('home-bucket-bar-${s.bucket.id}'),
              valueBp: s.usedBp ?? 0,
              color: usageColor(k, s.usedBp),
            ),
          ],
        ],
      ),
    );
  }
}

/// All balances in the base currency; the tap shows how each line was converted.
class HomeConsolidatedCard extends ConsumerWidget {
  const HomeConsolidatedCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final k = context.tokens;
    final text = Theme.of(context).textTheme;
    final c = ref.watch(consolidatedProvider).value;
    if (c == null) return const SizedBox(key: ValueKey('home-consolidated'));

    return Panel(
      key: const ValueKey('home-consolidated'),
      onTap: () => showHowConverted(context, c),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(l.finAllAccounts, style: text.titleMedium?.copyWith(color: k.text)),
              ),
              Icon(Icons.info_outline_rounded, size: 18, color: k.textMuted),
            ],
          ),
          const SizedBox(height: 10),
          if (c.total != null)
            FittedMoney(
              c.total!,
              alignment: AlignmentDirectional.centerStart,
              style: text.headlineMedium?.copyWith(color: k.text, fontWeight: FontWeight.w600),
            )
          else ...[
            for (final e in c.subtotals.entries)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Text(e.key, style: text.bodyMedium?.copyWith(color: k.textMuted)),
                    const SizedBox(width: 16),
                    Expanded(
                      child: FittedMoney(e.value, style: text.titleMedium?.copyWith(color: k.text)),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 6),
            Text(l.finNoTotal(c.missingRates.join('، ')), style: text.bodySmall?.copyWith(color: k.warning)),
          ],
        ],
      ),
    );
  }
}
