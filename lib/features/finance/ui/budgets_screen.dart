import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/db/app_database.dart';
import '../../../core/l10n/ckb_fallback_localizations.dart';
import '../../../core/money/money.dart';
import '../../../core/money/money_format.dart';
import '../../../core/theme/tokens.dart';
import '../data/categories_repository.dart';
import '../data/finance_providers.dart';
import '../domain/budgets_math.dart';
import 'accounts_screen.dart' show currencyChoices;
import 'ui_format.dart';
import 'widgets/amount_field.dart';
import 'widgets/money_text.dart';
import 'widgets/month_switcher.dart';
import 'widgets/panel.dart';
import 'widgets/usage_bar.dart';

String budgetName(Budget b, List<Category> categories, List<Workspace> workspaces, AppLocalizations l) {
  final c = categories.where((c) => c.id == b.categoryId).firstOrNull;
  final w = workspaces.where((w) => w.id == b.workspaceId).firstOrNull;
  return [if (c != null) categoryLabel(c, l), if (w != null) w.name].join(' · ');
}

class BudgetsScreen extends ConsumerStatefulWidget {
  const BudgetsScreen({super.key});

  @override
  ConsumerState<BudgetsScreen> createState() => _BudgetsScreenState();
}

class _BudgetsScreenState extends ConsumerState<BudgetsScreen> {
  DateTime _month = thisMonth();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final k = context.tokens;
    final text = Theme.of(context).textTheme;
    final progress = ref.watch(budgetProgressForMonthProvider(_month));
    final categories = ref.watch(categoriesProvider).value ?? const <Category>[];
    final workspaces = ref.watch(workspacesProvider).value ?? const <Workspace>[];
    final list = progress.value ?? const <BudgetProgress>[];

    return Scaffold(
      appBar: AppBar(
        title: Text(l.finBudgets),
        actions: [
          IconButton(
            key: const ValueKey('add-budget'),
            tooltip: l.finAddBudget,
            icon: const Icon(Icons.add_rounded),
            onPressed: () => showBudgetSheet(context),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 112),
        children: [
          MonthSwitcher(month: _month, onChanged: (m) => setState(() => _month = m)),
          const SizedBox(height: 8),
          if (progress.hasValue && list.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                l.finNoBudgets,
                textAlign: TextAlign.center,
                style: text.bodyLarge?.copyWith(color: k.textMuted),
              ),
            ),
          for (final p in list)
            Panel(
              key: ValueKey('budget-${p.budget.id}'),
              onTap: () => showBudgetSheet(context, editing: p.budget),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          budgetName(p.budget, categories, workspaces, l),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: text.titleMedium?.copyWith(color: k.text),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '${p.percentBp ~/ 100}%',
                        style: text.labelLarge?.copyWith(color: usageColor(k, p.percentBp)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  FittedMoney(
                    Money(p.actualMinor, p.budget.currencyCode),
                    alignment: AlignmentDirectional.centerStart,
                    style: text.headlineSmall?.copyWith(color: k.text, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    l.finOfBudget(
                      formatMoney(Money(p.budget.amountMinor, p.budget.currencyCode), localeCode: langOf(context)),
                    ),
                    textDirection: Directionality.of(context),
                    style: text.bodySmall?.copyWith(color: k.textMuted),
                  ),
                  const SizedBox(height: 10),
                  UsageBar(
                    barKey: ValueKey('budget-bar-${p.budget.id}'),
                    valueBp: p.percentBp,
                    color: usageColor(k, p.percentBp),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Text(l.finRemaining, style: text.bodyMedium?.copyWith(color: k.textMuted)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FittedMoney(
                          Money(p.remainingMinor, p.budget.currencyCode),
                          style: text.bodyLarge?.copyWith(color: p.remainingMinor < 0 ? k.danger : k.text),
                        ),
                      ),
                    ],
                  ),
                  if (p.missingRates.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        l.finMissingRatesNote(p.missingRates.join('، ')),
                        style: text.bodySmall?.copyWith(color: k.warning),
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

Future<void> showBudgetSheet(BuildContext context, {Budget? editing}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => _BudgetSheet(editing: editing),
);

class _BudgetSheet extends ConsumerStatefulWidget {
  const _BudgetSheet({this.editing});

  final Budget? editing;

  @override
  ConsumerState<_BudgetSheet> createState() => _BudgetSheetState();
}

class _BudgetSheetState extends ConsumerState<_BudgetSheet> {
  late int? _category = widget.editing?.categoryId;
  late int? _workspace = widget.editing?.workspaceId;
  late int? _amount = widget.editing?.amountMinor;
  late String _currency = widget.editing?.currencyCode ?? ref.read(settingsProvider).value?.baseCurrency ?? 'IQD';

  bool get _valid => (_category != null || _workspace != null) && _amount != null && _amount! > 0;

  Future<void> _save() async {
    final repo = ref.read(budgetsRepositoryProvider);
    final e = widget.editing;
    if (e == null) {
      await repo.create(categoryId: _category, workspaceId: _workspace, amountMinor: _amount!, currencyCode: _currency);
    } else {
      await repo.update(
        e.copyWith(
          categoryId: Value(_category),
          workspaceId: Value(_workspace),
          amountMinor: _amount!,
          currencyCode: _currency,
        ),
      );
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final k = context.tokens;
    final text = Theme.of(context).textTheme;
    final categories = (ref.watch(categoriesProvider).value ?? const <Category>[])
        .where((c) => c.kind == 'expense')
        .toList();
    final workspaces = ref.watch(workspacesProvider).value ?? const <Workspace>[];

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.editing == null ? l.finAddBudget : l.finEditBudget, style: text.titleLarge),
              const SizedBox(height: 16),
              DropdownButtonFormField<int?>(
                key: const ValueKey('budget-category'),
                initialValue: _category,
                isExpanded: true,
                decoration: InputDecoration(labelText: l.finCategory),
                items: [
                  DropdownMenuItem<int?>(value: null, child: Text(l.finAnyCategory)),
                  for (final c in categories)
                    DropdownMenuItem<int?>(
                      value: c.id,
                      child: Text(categoryLabel(c, l), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (v) => setState(() => _category = v),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int?>(
                key: const ValueKey('budget-workspace'),
                initialValue: _workspace,
                isExpanded: true,
                decoration: InputDecoration(labelText: l.finWorkspace),
                items: [
                  DropdownMenuItem<int?>(value: null, child: Text(l.finAnyWorkspace)),
                  for (final w in workspaces)
                    DropdownMenuItem<int?>(
                      value: w.id,
                      child: Text(w.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (v) => setState(() => _workspace = v),
              ),
              if (_category == null && _workspace == null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(l.finBudgetNeedsScope, style: text.bodySmall?.copyWith(color: k.warning)),
                ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: AmountField(
                      fieldKey: const ValueKey('budget-amount'),
                      currency: _currency,
                      initialMinor: _amount,
                      label: l.finAmount,
                      onMinor: (v) => setState(() => _amount = v),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String>(
                      key: const ValueKey('budget-currency'),
                      initialValue: _currency,
                      decoration: InputDecoration(labelText: l.finCurrency),
                      items: [for (final c in currencyChoices()) DropdownMenuItem(value: c, child: Text(c))],
                      onChanged: (v) => setState(() => _currency = v ?? _currency),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              FilledButton(
                key: const ValueKey('budget-save'),
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                onPressed: _valid ? _save : null,
                child: Text(l.save),
              ),
              if (widget.editing != null)
                TextButton(
                  key: const ValueKey('budget-archive'),
                  onPressed: () async {
                    await ref.read(budgetsRepositoryProvider).archive(widget.editing!.id);
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: Text(l.archive),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
