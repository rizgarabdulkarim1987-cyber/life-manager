import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/ckb_fallback_localizations.dart';
import '../../../core/money/money.dart';
import '../../../core/money/money_format.dart';
import '../../../core/theme/tokens.dart';
import '../data/finance_providers.dart';
import '../domain/installments.dart';
import 'ui_format.dart';
import 'widgets/account_picker.dart';
import 'widgets/amount_field.dart';
import 'widgets/money_text.dart';
import 'widgets/panel.dart';

class DebtDetailScreen extends ConsumerWidget {
  const DebtDetailScreen({super.key, required this.debtId});

  final int debtId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final k = context.tokens;
    final text = Theme.of(context).textTheme;
    final summary = (ref.watch(allDebtSummariesProvider).value ?? const <DebtSummary>[])
        .where((d) => d.debt.id == debtId)
        .firstOrNull;
    if (summary == null) return Scaffold(appBar: AppBar());
    final d = summary.debt;
    final installments = ref.watch(debtInstallmentsProvider(debtId)).value ?? const <InstallmentState>[];
    final payments = ref.watch(debtPaymentsProvider(debtId)).value ?? const [];
    final muted = text.bodySmall?.copyWith(color: k.textMuted);
    final closed = d.closedAt != null;

    return Scaffold(
      appBar: AppBar(title: Text(d.counterparty, maxLines: 1, overflow: TextOverflow.ellipsis)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 112),
        children: [
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(d.direction == 'owed_to_me' ? l.finOwedToMe : l.finOwedByMe, style: muted),
                const SizedBox(height: 6),
                Text(closed ? l.finClosed : l.finRemaining, style: muted),
                FittedMoney(
                  Money(summary.remainingMinor, d.currencyCode),
                  alignment: AlignmentDirectional.centerStart,
                  style: text.headlineMedium?.copyWith(color: k.text, fontWeight: FontWeight.w600),
                ),
                Row(
                  children: [
                    Text('${l.finPrincipal}: ', style: muted),
                    Flexible(child: FittedMoney(Money(d.principalMinor, d.currencyCode), style: muted)),
                  ],
                ),
                if (d.notes != null) ...[const SizedBox(height: 8), Text(d.notes!, style: text.bodyMedium)],
                if (!closed) ...[
                  const SizedBox(height: 14),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: FilledButton.icon(
                      key: const ValueKey('record-repayment'),
                      onPressed: () => showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        showDragHandle: true,
                        builder: (_) => _RepaymentSheet(summary: summary),
                      ),
                      icon: const Icon(Icons.payments_outlined, size: 18),
                      label: Text(l.finRecordRepayment),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (installments.isNotEmpty)
            Panel(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(l.finInstallments, style: text.titleMedium?.copyWith(color: k.text)),
                  for (final s in installments)
                    Padding(
                      key: ValueKey('installment-${s.inst.seq}'),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Icon(
                            s.isPaid ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                            size: 20,
                            color: s.isPaid ? k.success : (s.isOverdue ? k.danger : k.textMuted),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              formatDate(context, s.inst.dueDate.toLocal()),
                              style: text.bodyMedium?.copyWith(color: s.isOverdue ? k.danger : k.text),
                            ),
                          ),
                          Flexible(
                            child: FittedMoney(Money(s.inst.amountMinor, d.currencyCode), style: text.bodyMedium),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          if (payments.isNotEmpty)
            Panel(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(l.finPayments, style: text.titleMedium?.copyWith(color: k.text)),
                  for (final p in payments)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${p.debtLeg == 'principal' ? l.finPrincipal : l.finRepayment} · '
                              '${formatDate(context, p.occurredAt.toLocal())}',
                              style: text.bodyMedium,
                            ),
                          ),
                          Flexible(child: FittedMoney(Money(p.amountMinor, p.currencyCode), style: text.bodyMedium)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _RepaymentSheet extends ConsumerStatefulWidget {
  const _RepaymentSheet({required this.summary});

  final DebtSummary summary;

  @override
  ConsumerState<_RepaymentSheet> createState() => _RepaymentSheetState();
}

class _RepaymentSheetState extends ConsumerState<_RepaymentSheet> {
  int? _account;
  int? _amount;
  DateTime _at = DateTime.now();

  bool get _valid => _account != null && _amount != null && _amount! > 0 && _amount! <= widget.summary.remainingMinor;

  Future<void> _save() async {
    await ref
        .read(debtsRepositoryProvider)
        .recordRepayment(
          debtId: widget.summary.debt.id,
          accountId: _account!,
          amountMinor: _amount!,
          occurredAt: _at.toUtc(),
        );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final k = context.tokens;
    final text = Theme.of(context).textTheme;
    final cur = widget.summary.debt.currencyCode;
    final remaining = Money(widget.summary.remainingMinor, cur);
    final tooBig = _amount != null && _amount! > remaining.minor;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l.finRecordRepayment, style: text.titleLarge),
              const SizedBox(height: 16),
              AccountPicker(
                fieldKey: const ValueKey('repay-account'),
                label: l.finAccount,
                value: _account,
                currency: cur,
                onChanged: (id) => setState(() => _account = id),
              ),
              const SizedBox(height: 12),
              AmountField(
                fieldKey: const ValueKey('repay-amount'),
                currency: cur,
                label: l.finAmount,
                helper: l.finRepaymentTooBig(formatMoney(remaining, localeCode: langOf(context))),
                onMinor: (v) => setState(() => _amount = v),
              ),
              if (tooBig)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    l.finRepaymentTooBig(formatMoney(remaining, localeCode: langOf(context))),
                    style: text.bodySmall?.copyWith(color: k.danger),
                  ),
                ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: _at,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(DateTime.now().year + 1, 12, 31),
                  );
                  if (d != null) setState(() => _at = d);
                },
                icon: const Icon(Icons.event_rounded, size: 18),
                label: Text(formatDate(context, _at)),
              ),
              const SizedBox(height: 20),
              FilledButton(
                key: const ValueKey('repay-save'),
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
