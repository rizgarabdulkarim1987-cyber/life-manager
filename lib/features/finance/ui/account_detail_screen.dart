import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/app_database.dart';
import '../../../core/l10n/ckb_fallback_localizations.dart';
import '../../../core/money/amount_parse.dart';
import '../../../core/money/money.dart';
import '../../../core/theme/tokens.dart';
import '../data/finance_providers.dart';
import '../data/transactions_repository.dart';
import 'ui_format.dart';
import 'widgets/money_text.dart';
import 'widgets/panel.dart';
import 'widgets/text_prompt_dialog.dart';
import 'widgets/transaction_list.dart';

class AccountDetailScreen extends ConsumerWidget {
  const AccountDetailScreen({super.key, required this.accountId});

  final int accountId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final k = context.tokens;
    final text = Theme.of(context).textTheme;
    final account = (ref.watch(accountsProvider).value ?? const <Account>[])
        .where((a) => a.id == accountId)
        .firstOrNull;
    final workspaces = ref.watch(workspacesProvider).value ?? const <Workspace>[];
    final balance = ref.watch(balancesProvider).value?[accountId];
    if (account == null) return Scaffold(appBar: AppBar());
    final ws = workspaces.where((w) => w.id == account.workspaceId).firstOrNull;
    final current = balance ?? Money(account.openingBalanceMinor, account.currencyCode);

    return Scaffold(
      appBar: AppBar(
        title: Text(shortAccountName(account.name, ws?.name ?? ''), maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            sliver: SliverToBoxAdapter(
              child: Panel(
                key: const ValueKey('account-balance'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      [
                        ws?.name,
                        accountKindLabel(account.kind, l),
                        account.currencyCode,
                      ].whereType<String>().join(' · '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodySmall?.copyWith(color: k.textMuted),
                    ),
                    const SizedBox(height: 8),
                    FittedMoney(
                      current,
                      alignment: AlignmentDirectional.centerStart,
                      style: text.headlineMedium?.copyWith(color: k.text, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: OutlinedButton.icon(
                        key: const ValueKey('adjust-balance'),
                        onPressed: () => _adjust(context, ref, account, current),
                        icon: const Icon(Icons.tune_rounded, size: 18),
                        label: Text(l.finAdjustBalance),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          TransactionSliverList(
            filter: TxFilter(accountIds: {accountId}),
            filterKey: accountId,
            accountId: accountId,
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 112)),
        ],
      ),
    );
  }

  Future<void> _adjust(BuildContext context, WidgetRef ref, Account a, Money current) async {
    final l = context.l10n;
    final actual = await showDialog<int>(
      context: context,
      builder: (_) => TextPromptDialog<int>(
        title: l.finAdjustBalance,
        message: l.finAdjustHint,
        label: l.finActualAmount,
        suffix: a.currencyCode,
        parse: (t) => parseDecimalToMinor(t, a.currencyCode)?.minor,
        invalidText: l.finAmountInvalid,
        numeric: true,
        fieldKey: const ValueKey('adjust-amount'),
        saveKey: const ValueKey('adjust-save'),
      ),
    );
    if (actual == null || actual == current.minor) return;
    await ref
        .read(transactionsRepositoryProvider)
        .addSimple(
          type: 'adjustment',
          accountId: a.id,
          amountMinor: actual - current.minor,
          occurredAt: DateTime.now().toUtc(),
        );
  }
}
