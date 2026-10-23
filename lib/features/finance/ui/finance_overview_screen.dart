import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/providers.dart';
import '../../../core/l10n/ckb_fallback_localizations.dart';
import '../../../core/money/money.dart';
import '../../../core/theme/tokens.dart';
import '../../capture/data/capture_providers.dart';
import '../data/finance_providers.dart';
import 'ui_format.dart';
import 'widgets/alerts_banner.dart';
import 'widgets/how_converted_sheet.dart';
import 'widgets/money_text.dart';
import 'widgets/panel.dart';
import 'widgets/set_rate_dialog.dart';

/// A way into one finance screen from the overview.
class FinanceEntry {
  const FinanceEntry(this.id, this.icon, this.label, this.route);

  final String id;
  final IconData icon;
  final String Function(AppLocalizations l) label;
  final String route;
}

/// Entry tiles in display order. Each task that adds a finance screen adds its entry here.
final kFinanceEntries = <FinanceEntry>[
  FinanceEntry('reports', Icons.insights_rounded, (l) => l.finReports, '/finance/reports'),
  FinanceEntry('history', Icons.receipt_long_rounded, (l) => l.finHistory, '/finance/history'),
  FinanceEntry('accounts', Icons.account_balance_wallet_outlined, (l) => l.accounts, '/finance/accounts'),
  FinanceEntry('buckets', Icons.savings_outlined, (l) => l.finBuckets, '/finance/buckets'),
  FinanceEntry('budgets', Icons.donut_small_outlined, (l) => l.finBudgets, '/finance/budgets'),
  FinanceEntry('debts', Icons.handshake_outlined, (l) => l.finDebts, '/finance/debts'),
  FinanceEntry('import', Icons.upload_file_rounded, (l) => l.impEntry, '/finance/import'),
  FinanceEntry('inbox-tile', Icons.inbox_outlined, (l) => l.capInbox, '/inbox'),
];

class FinanceOverviewScreen extends ConsumerWidget {
  const FinanceOverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final alerts = ref.watch(financeAlertsProvider).value ?? const [];
    return Scaffold(
      appBar: AppBar(title: Text(l.navFinance)),
      body: ListView(
        key: const ValueKey('finance-overview'),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 112),
        children: [
          const _MonthPanel(),
          const _AddActions(),
          const _ConsolidatedPanel(),
          AlertsBanner(alerts),
          const _Entries(),
          const _AccountsPanel(),
        ],
      ),
    );
  }
}

class _MonthPanel extends ConsumerWidget {
  const _MonthPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final k = context.tokens;
    final text = Theme.of(context).textTheme;
    final base = ref.watch(settingsProvider).value?.baseCurrency ?? 'IQD';
    final summary = ref.watch(monthSummaryProvider).value;
    final month = DateFormat.yMMMM(dateLocaleOf(context)).format(DateTime.now());
    final income = Money(summary?.data.income ?? 0, base);
    final expense = Money(summary?.data.expense ?? 0, base);
    final surplus = Money(summary?.data.surplus ?? 0, base);

    Widget row(String key, String label, Widget value, {TextStyle? labelStyle}) => Padding(
      key: ValueKey(key),
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(label, style: labelStyle ?? text.bodyLarge?.copyWith(color: k.textMuted)),
          const SizedBox(width: 16),
          Expanded(child: value),
        ],
      ),
    );

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(month, style: text.titleMedium?.copyWith(color: k.text)),
          const SizedBox(height: 8),
          row('month-income', l.finIncome, FittedMoney(income, style: text.titleMedium?.copyWith(color: k.text))),
          row('month-expense', l.finExpense, FittedMoney(expense, style: text.titleMedium?.copyWith(color: k.text))),
          Divider(color: k.border, height: 16),
          row(
            'month-surplus',
            l.finSurplus,
            FittedMoney(surplus, signed: true, style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w600)),
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

/// One-tap entry to the three forms, under the month figures.
class _AddActions extends StatelessWidget {
  const _AddActions();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    Widget action(String key, IconData icon, String label, String route) => Expanded(
      child: FilledButton.tonal(
        key: ValueKey(key),
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 56),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTokens.radiusSmall)),
        ),
        onPressed: () => context.push(route),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20),
            const SizedBox(height: 2),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          action('add-expense', Icons.remove_rounded, l.typeExpense, '/finance/tx/new?type=expense'),
          const SizedBox(width: 10),
          action('add-income', Icons.add_rounded, l.typeIncome, '/finance/tx/new?type=income'),
          const SizedBox(width: 10),
          action('add-transfer', Icons.swap_horiz_rounded, l.typeTransfer, '/finance/transfer/new'),
        ],
      ),
    );
  }
}

class _ConsolidatedPanel extends ConsumerWidget {
  const _ConsolidatedPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final k = context.tokens;
    final text = Theme.of(context).textTheme;
    final c = ref.watch(consolidatedProvider).value;
    if (c == null) return const SizedBox(key: ValueKey('consolidated-card'), height: 0);

    return Panel(
      key: const ValueKey('consolidated-card'),
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
          if (c.total != null) ...[
            FittedMoney(
              c.total!,
              alignment: AlignmentDirectional.centerStart,
              style: text.headlineMedium?.copyWith(color: k.text, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(l.finHowConvertedHint, style: text.bodySmall?.copyWith(color: k.textMuted)),
          ] else ...[
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
            const SizedBox(height: 8),
            Text(l.finNoTotal(c.missingRates.join('، ')), style: text.bodySmall?.copyWith(color: k.warning)),
            const SizedBox(height: 10),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: FilledButton.tonalIcon(
                key: const ValueKey('set-rate'),
                onPressed: () => showSetRateDialog(context, ref),
                icon: const Icon(Icons.currency_exchange_rounded, size: 18),
                label: Text(l.finSetRate),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Entries extends ConsumerWidget {
  const _Entries();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final k = context.tokens;
    final waiting = ref.watch(pendingCapturesProvider).value?.length ?? 0;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: LayoutBuilder(
        builder: (context, box) {
          const gap = 10.0;
          final perRow = box.maxWidth >= 520 ? 3 : 2;
          final w = (box.maxWidth - gap * (perRow - 1)) / perRow;
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (final e in kFinanceEntries)
                SizedBox(
                  width: w,
                  child: Material(
                    color: k.surfaceHigh,
                    borderRadius: BorderRadius.circular(AppTokens.radiusSmall),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      key: ValueKey('open-${e.id}'),
                      onTap: () => context.push(e.route),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 56),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          child: Row(
                            children: [
                              Icon(e.icon, size: 20, color: k.accent),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  e.label(context.l10n),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: text.labelLarge?.copyWith(color: k.text),
                                ),
                              ),
                              if (e.id == 'inbox-tile' && waiting > 0) Badge(label: Text('$waiting')),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _AccountsPanel extends ConsumerWidget {
  const _AccountsPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final k = context.tokens;
    final text = Theme.of(context).textTheme;
    final groups = ref.watch(accountGroupsProvider).value ?? const [];
    final balances = ref.watch(balancesProvider).value ?? const {};

    return Panel(
      key: const ValueKey('finance-accounts'),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l.accounts, style: text.titleMedium?.copyWith(color: k.text)),
          for (final (ws, accounts) in groups) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: Color(ws.colorArgb), shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    ws.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.labelLarge?.copyWith(color: k.textMuted),
                  ),
                ),
              ],
            ),
            for (final a in accounts)
              InkWell(
                key: ValueKey('overview-account-${a.id}'),
                borderRadius: BorderRadius.circular(AppTokens.radiusSmall),
                onTap: () => context.push('/finance/accounts/${a.id}'),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: Padding(
                    padding: const EdgeInsetsDirectional.only(start: 16, end: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            shortAccountName(a.name, ws.name),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.bodyMedium?.copyWith(color: k.text),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Flexible(
                          child: FittedMoney(
                            balances[a.id] ?? Money(a.openingBalanceMinor, a.currencyCode),
                            style: text.bodyLarge?.copyWith(color: k.text),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
