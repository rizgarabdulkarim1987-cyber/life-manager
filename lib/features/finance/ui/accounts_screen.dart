import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/db/app_database.dart';
import '../../../core/l10n/ckb_fallback_localizations.dart';
import '../../../core/money/currency.dart';
import '../../../core/money/money.dart';
import '../../../core/theme/tokens.dart';
import '../data/finance_providers.dart';
import 'ui_format.dart';
import 'widgets/money_text.dart';
import 'widgets/panel.dart';

/// IQD and USD first, then the other offered currencies.
List<String> currencyChoices() => [
  ...kSeedCurrencies,
  ...kCurrencyExponents.keys.where((c) => !kSeedCurrencies.contains(c)),
];

class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final k = context.tokens;
    final text = Theme.of(context).textTheme;
    final groups = ref.watch(accountGroupsProvider).value ?? const [];
    final balances = ref.watch(balancesProvider).value ?? const {};

    return Scaffold(
      appBar: AppBar(
        title: Text(l.accounts),
        actions: [
          IconButton(
            key: const ValueKey('add-account'),
            tooltip: l.finAddAccount,
            icon: const Icon(Icons.add_rounded),
            onPressed: () => showAccountDialog(context, ref),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 112),
        children: [
          for (final (ws, accounts) in groups)
            Panel(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    ws.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: text.labelLarge?.copyWith(color: k.textMuted),
                  ),
                  for (final a in accounts)
                    InkWell(
                      key: ValueKey('account-row-${a.id}'),
                      borderRadius: BorderRadius.circular(AppTokens.radiusSmall),
                      onTap: () => context.push('/finance/accounts/${a.id}'),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 56),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    shortAccountName(a.name, ws.name),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: text.bodyLarge?.copyWith(color: k.text),
                                  ),
                                  Text(
                                    '${accountKindLabel(a.kind, l)} · ${a.currencyCode}',
                                    style: text.bodySmall?.copyWith(color: k.textMuted),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Flexible(
                              child: FittedMoney(
                                balances[a.id] ?? Money(a.openingBalanceMinor, a.currencyCode),
                                style: text.bodyLarge?.copyWith(color: k.text),
                              ),
                            ),
                            PopupMenuButton<String>(
                              key: ValueKey('account-menu-${a.id}'),
                              onSelected: (v) => v == 'rename'
                                  ? showAccountDialog(context, ref, editing: a)
                                  : _archive(context, ref, a),
                              itemBuilder: (_) => [
                                PopupMenuItem(value: 'rename', child: Text(l.rename)),
                                PopupMenuItem(value: 'archive', child: Text(l.archive)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _archive(BuildContext context, WidgetRef ref, Account a) async {
    final l = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(l.finArchiveAccount(a.name)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.cancel)),
          FilledButton(
            key: const ValueKey('archive-confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.archive),
          ),
        ],
      ),
    );
    if (ok == true) await ref.read(accountsRepositoryProvider).archive(a.id);
  }
}

/// Add an account, or rename [editing] (its currency and workspace stay).
Future<void> showAccountDialog(BuildContext context, WidgetRef ref, {Account? editing}) async {
  final workspaces = ref.read(workspacesProvider).value ?? const <Workspace>[];
  if (workspaces.isEmpty) return;
  await showDialog<void>(
    context: context,
    builder: (_) => _AccountDialog(workspaces: workspaces, editing: editing),
  );
}

class _AccountDialog extends ConsumerStatefulWidget {
  const _AccountDialog({required this.workspaces, this.editing});

  final List<Workspace> workspaces;
  final Account? editing;

  @override
  ConsumerState<_AccountDialog> createState() => _AccountDialogState();
}

class _AccountDialogState extends ConsumerState<_AccountDialog> {
  late final _name = TextEditingController(text: widget.editing?.name);
  late int _ws = widget.editing?.workspaceId ?? widget.workspaces.first.id;
  late String _currency = widget.editing?.currencyCode ?? 'IQD';
  late String _kind = widget.editing?.kind ?? 'cash';
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final n = _name.text.trim();
    if (n.isEmpty) return setState(() => _error = context.l10n.finNameRequired);
    final repo = ref.read(accountsRepositoryProvider);
    final editing = widget.editing;
    if (editing == null) {
      await repo.create(workspaceId: _ws, name: n, kind: _kind, currencyCode: _currency);
    } else {
      await repo.update(editing.copyWith(name: n, kind: _kind));
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final adding = widget.editing == null;
    return AlertDialog(
      title: Text(adding ? l.finAddAccount : l.rename),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const ValueKey('account-name'),
              controller: _name,
              autofocus: true,
              maxLength: 80,
              decoration: InputDecoration(labelText: l.finAccountName, errorText: _error),
            ),
            if (adding) ...[
              DropdownButtonFormField<int>(
                key: const ValueKey('account-workspace'),
                initialValue: _ws,
                isExpanded: true,
                decoration: InputDecoration(labelText: l.finWorkspace),
                items: [
                  for (final w in widget.workspaces)
                    DropdownMenuItem(
                      value: w.id,
                      child: Text(w.name, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (v) => setState(() => _ws = v ?? _ws),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: const ValueKey('account-currency'),
                initialValue: _currency,
                decoration: InputDecoration(labelText: l.finCurrency),
                items: [for (final c in currencyChoices()) DropdownMenuItem(value: c, child: Text(c))],
                onChanged: (v) => setState(() => _currency = v ?? _currency),
              ),
              const SizedBox(height: 12),
            ],
            DropdownButtonFormField<String>(
              key: const ValueKey('account-kind'),
              initialValue: _kind,
              decoration: InputDecoration(labelText: l.finKind),
              items: [for (final k in kAccountKinds) DropdownMenuItem(value: k, child: Text(accountKindLabel(k, l)))],
              onChanged: (v) => setState(() => _kind = v ?? _kind),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.cancel)),
        FilledButton(key: const ValueKey('account-save'), onPressed: _save, child: Text(l.save)),
      ],
    );
  }
}
