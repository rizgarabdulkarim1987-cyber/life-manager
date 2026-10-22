import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/db/app_database.dart';
import '../../../../core/l10n/ckb_fallback_localizations.dart';
import '../../../../core/money/money.dart';
import '../../../../core/theme/tokens.dart';
import '../../data/categories_repository.dart';
import '../../data/finance_providers.dart';
import '../../data/transactions_repository.dart';
import '../../domain/ledger.dart';
import '../ui_format.dart';
import 'money_text.dart';

/// Transactions matching [filter] as slivers: day headers with the day's net
/// per currency, swipe to delete with an Undo snackbar. [filterKey] changes
/// whenever the filter does, so the list resubscribes.
class TransactionSliverList extends ConsumerStatefulWidget {
  const TransactionSliverList({
    super.key,
    required this.filter,
    required this.filterKey,
    this.accountId,
    this.filtered = false,
    this.onTap,
  });

  final TxFilter filter;
  final Object filterKey;

  /// When set, amounts are signed by their effect on this account.
  final int? accountId;

  /// Picks the empty-state copy: no matches vs nothing yet.
  final bool filtered;
  final void Function(Transaction t)? onTap;

  @override
  ConsumerState<TransactionSliverList> createState() => _TransactionSliverListState();
}

class _TransactionSliverListState extends ConsumerState<TransactionSliverList> {
  late Stream<List<Transaction>> _stream;
  final _hidden = <int>{};

  @override
  void initState() {
    super.initState();
    _stream = ref.read(transactionsRepositoryProvider).watch(widget.filter);
  }

  @override
  void didUpdateWidget(TransactionSliverList old) {
    super.didUpdateWidget(old);
    if (old.filterKey != widget.filterKey) _stream = ref.read(transactionsRepositoryProvider).watch(widget.filter);
  }

  /// Signed effect for display. Transfers outside an account view are shown unsigned.
  Money? _signed(Transaction t, Map<int, String> debts) {
    if (t.type == 'transfer' && widget.accountId == null) return null;
    if (t.type == 'income' && t.paymentStatus != 'paid') return null;
    final acc = widget.accountId ?? t.accountId;
    final effect = balanceEffect(t, acc, debtDirection: t.debtId == null ? null : debts[t.debtId]);
    final currency = t.type == 'transfer' && t.toAccountId == acc
        ? (ref.read(accountsProvider).value?.where((a) => a.id == acc).firstOrNull?.currencyCode ?? t.currencyCode)
        : t.currencyCode;
    return Money(effect, currency);
  }

  Future<void> _delete(Transaction t) async {
    final repo = ref.read(transactionsRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    final l = context.l10n;
    setState(() => _hidden.add(t.id));
    await repo.delete(t.id);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(l.finDeleted),
        action: SnackBarAction(
          label: l.undo,
          onPressed: () async {
            await repo.restore(t);
            if (mounted) setState(() => _hidden.remove(t.id));
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final k = context.tokens;
    final text = Theme.of(context).textTheme;
    final accounts = {for (final a in ref.watch(accountsProvider).value ?? const <Account>[]) a.id: a};
    final workspaces = {for (final w in ref.watch(workspacesProvider).value ?? const <Workspace>[]) w.id: w};
    final categories = {for (final c in ref.watch(categoriesProvider).value ?? const <Category>[]) c.id: c};
    final debts = ref.watch(debtDirectionsProvider);
    final dayFormat = DateFormat.MMMMEEEEd(dateLocaleOf(context));
    final timeFormat = DateFormat.Hm('en');

    String accountName(int id) {
      final a = accounts[id];
      if (a == null) return '';
      return shortAccountName(a.name, workspaces[a.workspaceId]?.name ?? '');
    }

    return StreamBuilder<List<Transaction>>(
      stream: _stream,
      builder: (context, snap) {
        if (!snap.hasData) return const SliverToBoxAdapter(child: SizedBox.shrink());
        final rows = snap.data!.where((t) => !_hidden.contains(t.id)).toList();
        if (rows.isEmpty) {
          return SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  widget.filtered ? l.finNoMatches : l.finNoTransactions,
                  textAlign: TextAlign.center,
                  style: text.bodyLarge?.copyWith(color: k.textMuted),
                ),
              ),
            ),
          );
        }
        final days = <DateTime, List<Transaction>>{};
        for (final t in rows) {
          final d = t.occurredAt.toLocal();
          days.putIfAbsent(DateTime(d.year, d.month, d.day), () => []).add(t);
        }
        final today = DateTime.now();
        final items = <Widget>[];
        for (final MapEntry(key: day, value: list) in days.entries) {
          final totals = <String, int>{};
          for (final t in list) {
            final m = _signed(t, debts);
            if (m == null || t.type == 'transfer') continue;
            totals[m.currency] = (totals[m.currency] ?? 0) + m.minor;
          }
          final isToday = day.year == today.year && day.month == today.month && day.day == today.day;
          items.add(
            Padding(
              key: ValueKey('day-${day.toIso8601String()}'),
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      isToday ? l.finToday : dayFormat.format(day),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.labelLarge?.copyWith(color: k.textMuted),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 10,
                      children: [
                        for (final e in totals.entries)
                          MoneyText(Money(e.value, e.key), signed: true, style: text.labelLarge),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
          for (final t in list) {
            final m = _signed(t, debts);
            final cat = t.categoryId == null ? null : categories[t.categoryId];
            final title = t.description ?? (cat != null ? categoryLabel(cat, l) : txTypeLabel(t, l));
            final where = t.type == 'transfer'
                ? '${accountName(t.accountId)} → ${accountName(t.toAccountId!)}'
                : accountName(t.accountId);
            final meta = [
              txTypeLabel(t, l),
              if (t.paymentStatus != 'paid') l.finPending,
              where,
              timeFormat.format(t.occurredAt.toLocal()),
            ].join(' · ');
            items.add(
              Dismissible(
                key: ValueKey('tx-${t.id}'),
                direction: DismissDirection.endToStart,
                background: Container(
                  color: k.danger.withValues(alpha: 0.16),
                  alignment: AlignmentDirectional.centerEnd,
                  padding: const EdgeInsetsDirectional.only(end: 24),
                  child: Icon(Icons.delete_outline_rounded, color: k.danger),
                ),
                onDismissed: (_) => _delete(t),
                child: InkWell(
                  onTap: widget.onTap == null ? null : () => widget.onTap!(t),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 64),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: text.bodyLarge?.copyWith(color: k.text),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  meta,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: text.bodySmall?.copyWith(color: k.textMuted),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.42),
                            child: FittedMoney(
                              m ?? Money(t.amountMinor, t.currencyCode),
                              signed: m != null,
                              style: text.bodyLarge?.copyWith(color: m == null ? k.textMuted : k.text),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }
        }
        return SliverList.list(children: items);
      },
    );
  }
}
