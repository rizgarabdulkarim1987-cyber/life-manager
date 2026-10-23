import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/db/app_database.dart';
import '../../../core/l10n/ckb_fallback_localizations.dart';
import '../../../core/money/money.dart';
import '../../../core/text/digits.dart';
import '../../../core/theme/tokens.dart';
import '../data/finance_providers.dart';
import '../domain/installments.dart';
import '../domain/reports.dart' show outstandingDebts;
import 'accounts_screen.dart' show currencyChoices;
import 'ui_format.dart';
import 'widgets/account_picker.dart';
import 'widgets/amount_field.dart';
import 'widgets/money_text.dart';

class DebtsScreen extends ConsumerWidget {
  const DebtsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final all = outstandingDebts(ref.watch(debtSummariesProvider).value ?? const <DebtSummary>[]);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l.finDebts),
          actions: [
            IconButton(
              key: const ValueKey('add-debt'),
              tooltip: l.finAddDebt,
              icon: const Icon(Icons.add_rounded),
              onPressed: () => showDebtSheet(context),
            ),
            const SizedBox(width: 4),
          ],
          bottom: TabBar(
            tabs: [
              Tab(key: const ValueKey('tab-owed-to-me'), text: l.finOwedToMe),
              Tab(key: const ValueKey('tab-owed-by-me'), text: l.finOwedByMe),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _DebtList(all.where((d) => d.debt.direction == 'owed_to_me').toList()),
            _DebtList(all.where((d) => d.debt.direction == 'owed_by_me').toList()),
          ],
        ),
      ),
    );
  }
}

class _DebtList extends StatelessWidget {
  const _DebtList(this.debts);

  final List<DebtSummary> debts;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final k = context.tokens;
    final text = Theme.of(context).textTheme;
    if (debts.isEmpty) {
      return Center(
        child: Text(l.finNoDebts, style: text.bodyLarge?.copyWith(color: k.textMuted)),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 112),
      itemCount: debts.length,
      separatorBuilder: (_, _) => Divider(color: k.border, height: 1, indent: 20, endIndent: 20),
      itemBuilder: (context, i) {
        final d = debts[i];
        return InkWell(
          key: ValueKey('debt-${d.debt.id}'),
          onTap: () => context.push('/finance/debts/${d.debt.id}'),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 72),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          d.debt.counterparty,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.bodyLarge?.copyWith(color: k.text),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (d.overdue) _Badge(l.finOverdue, k.danger),
                            if (d.nextDue != null)
                              Text(
                                l.finNextDue(formatDate(context, d.nextDue!.toLocal())),
                                style: text.bodySmall?.copyWith(color: k.textMuted),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.45),
                    child: FittedMoney(
                      Money(d.remainingMinor, d.debt.currencyCode),
                      style: text.titleMedium?.copyWith(color: k.text),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.label, this.color);

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(8)),
    child: Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color)),
  );
}

Future<void> showDebtSheet(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => const _DebtSheet(),
);

class _DebtSheet extends ConsumerStatefulWidget {
  const _DebtSheet();

  @override
  ConsumerState<_DebtSheet> createState() => _DebtSheetState();
}

class _DebtSheetState extends ConsumerState<_DebtSheet> {
  String _direction = 'owed_to_me';
  final _counterparty = TextEditingController();
  final _count = TextEditingController();
  int? _workspace;
  int? _amount;
  String _currency = 'IQD';
  DateTime _start = DateTime.now();
  DateTime? _firstDue;
  bool _recordNow = false;
  int? _account;

  @override
  void dispose() {
    _counterparty.dispose();
    _count.dispose();
    super.dispose();
  }

  int get _installments => int.tryParse(normalizeDigits(_count.text.trim())) ?? 0;

  bool get _valid =>
      _counterparty.text.trim().isNotEmpty &&
      _amount != null &&
      _amount! > 0 &&
      _installments <= _amount! &&
      (!_recordNow || _account != null);

  Future<DateTime?> _pick(DateTime initial) => showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: DateTime(2000),
    lastDate: DateTime(DateTime.now().year + 30),
  );

  Future<void> _save() async {
    final workspaces = ref.read(workspacesProvider).value ?? const <Workspace>[];
    final count = _installments;
    final firstDue = _firstDue ?? DateTime(_start.year, _start.month + 1, _start.day);
    await ref
        .read(debtsRepositoryProvider)
        .create(
          direction: _direction,
          counterparty: _counterparty.text,
          workspaceId: _workspace ?? workspaces.first.id,
          principalMinor: _amount!,
          currencyCode: _currency,
          startDate: DateTime(_start.year, _start.month, _start.day).toUtc(),
          recordPrincipalFromAccountId: _recordNow ? _account : null,
          installmentCount: count,
          firstInstallmentDue: count > 0 ? DateTime(firstDue.year, firstDue.month, firstDue.day).toUtc() : null,
        );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final text = Theme.of(context).textTheme;
    final workspaces = ref.watch(workspacesProvider).value ?? const <Workspace>[];
    final firstDue = _firstDue ?? DateTime(_start.year, _start.month + 1, _start.day);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l.finAddDebt, style: text.titleLarge),
              const SizedBox(height: 16),
              SegmentedButton<String>(
                key: const ValueKey('debt-direction'),
                segments: [
                  ButtonSegment(value: 'owed_to_me', label: Text(l.finOwedToMe)),
                  ButtonSegment(value: 'owed_by_me', label: Text(l.finOwedByMe)),
                ],
                selected: {_direction},
                showSelectedIcon: false,
                onSelectionChanged: (s) => setState(() => _direction = s.first),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('debt-counterparty'),
                controller: _counterparty,
                maxLength: 80,
                decoration: InputDecoration(labelText: l.finCounterparty),
                onChanged: (_) => setState(() {}),
              ),
              DropdownButtonFormField<int>(
                key: const ValueKey('debt-workspace'),
                initialValue: _workspace ?? workspaces.firstOrNull?.id,
                isExpanded: true,
                decoration: InputDecoration(labelText: l.finWorkspace),
                items: [
                  for (final w in workspaces)
                    DropdownMenuItem(
                      value: w.id,
                      child: Text(w.name, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (v) => setState(() => _workspace = v),
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: AmountField(
                      fieldKey: const ValueKey('debt-amount'),
                      currency: _currency,
                      label: l.finAmount,
                      onMinor: (v) => setState(() => _amount = v),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String>(
                      key: const ValueKey('debt-currency'),
                      initialValue: _currency,
                      decoration: InputDecoration(labelText: l.finCurrency),
                      items: [for (final c in currencyChoices()) DropdownMenuItem(value: c, child: Text(c))],
                      onChanged: (v) => setState(() {
                        _currency = v ?? _currency;
                        _account = null;
                      }),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                key: const ValueKey('debt-start'),
                onPressed: () async {
                  final d = await _pick(_start);
                  if (d != null) setState(() => _start = d);
                },
                icon: const Icon(Icons.event_rounded, size: 18),
                label: Text('${l.finStartDate}: ${formatDate(context, _start)}'),
              ),
              SwitchListTile(
                key: const ValueKey('debt-record-now'),
                contentPadding: EdgeInsets.zero,
                title: Text(l.finRecordMoveNow),
                subtitle: Text(_direction == 'owed_to_me' ? l.finRecordMoveGiven : l.finRecordMoveReceived),
                value: _recordNow,
                onChanged: (v) => setState(() => _recordNow = v),
              ),
              if (_recordNow)
                AccountPicker(
                  key: ValueKey('debt-account-$_currency'),
                  fieldKey: const ValueKey('debt-account'),
                  label: l.finAccount,
                  value: _account,
                  currency: _currency,
                  onChanged: (id) => setState(() => _account = id),
                ),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('debt-installments'),
                controller: _count,
                keyboardType: TextInputType.number,
                textDirection: TextDirection.ltr,
                decoration: InputDecoration(labelText: l.finInstallmentCount),
                onChanged: (_) => setState(() {}),
              ),
              if (_installments > 0) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  key: const ValueKey('debt-first-due'),
                  onPressed: () async {
                    final d = await _pick(firstDue);
                    if (d != null) setState(() => _firstDue = d);
                  },
                  icon: const Icon(Icons.event_repeat_rounded, size: 18),
                  label: Text('${l.finFirstDue}: ${formatDate(context, firstDue)}'),
                ),
              ],
              const SizedBox(height: 20),
              FilledButton(
                key: const ValueKey('debt-save'),
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                onPressed: _valid ? _save : null,
                child: Text(l.save),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
