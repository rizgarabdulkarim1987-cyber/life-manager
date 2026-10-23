import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/ckb_fallback_localizations.dart';
import '../../../../core/theme/tokens.dart';
import '../../data/categories_repository.dart';
import '../../data/finance_providers.dart';
import '../../domain/alerts.dart';
import '../ui_format.dart';

/// Where tapping an alert goes.
String alertRoute(FinanceAlert a) => switch (a) {
  ExpensesBucketUsed() || EmergencyTargetReached() || EmergencyBelowTarget() => '/finance/buckets',
  UnallocatedIncome() => '/finance/history?type=income',
  BudgetUsed() => '/finance/budgets',
  DebtDueSoon(:final debtId) || DebtOverdue(:final debtId) => '/finance/debts/$debtId',
};

/// One line per alert, each opening the screen it is about.
class AlertsBanner extends ConsumerWidget {
  const AlertsBanner(this.alerts, {super.key, this.keyPrefix = ''});

  final List<FinanceAlert> alerts;

  /// Keeps keys unique when two screens show the banner at once (Home and Finance).
  final String keyPrefix;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (alerts.isEmpty) return const SizedBox.shrink();
    final k = context.tokens;
    final l = context.l10n;
    final budgets = ref.watch(budgetsProvider).value ?? const [];
    final categories = ref.watch(categoriesProvider).value ?? const [];
    final workspaces = ref.watch(workspacesProvider).value ?? const [];
    final debts = ref.watch(debtSummariesProvider).value ?? const [];

    String budgetName(int id) {
      final b = budgets.where((b) => b.id == id).firstOrNull;
      if (b == null) return '';
      final c = categories.where((c) => c.id == b.categoryId).firstOrNull;
      if (c != null) return categoryLabel(c, l);
      return workspaces.where((w) => w.id == b.workspaceId).firstOrNull?.name ?? '';
    }

    String debtName(int id) => debts.where((d) => d.debt.id == id).firstOrNull?.debt.counterparty ?? '';

    String label(FinanceAlert a) => switch (a) {
      ExpensesBucketUsed(:final percentBp) => l.alertExpensesBucket(percentBp ~/ 100),
      EmergencyTargetReached() => l.alertEmergencyReached,
      EmergencyBelowTarget() => l.alertEmergencyBelow,
      UnallocatedIncome(:final count) => l.alertUnallocated(count),
      BudgetUsed(:final budgetId, :final percentBp) => l.alertBudget(budgetName(budgetId), percentBp ~/ 100),
      DebtDueSoon(:final debtId, :final due) => l.alertDebtSoon(debtName(debtId), formatDate(context, due.toLocal())),
      DebtOverdue(:final debtId) => l.alertDebtOverdue(debtName(debtId)),
    };

    bool urgent(FinanceAlert a) => switch (a) {
      ExpensesBucketUsed(:final percentBp) => percentBp >= 10000,
      BudgetUsed(:final percentBp) => percentBp >= 10000,
      DebtOverdue() || EmergencyBelowTarget() => true,
      _ => false,
    };

    final text = Theme.of(context).textTheme;
    return Container(
      key: ValueKey('${keyPrefix}alerts-banner'),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: k.surface,
        borderRadius: BorderRadius.circular(AppTokens.radiusCard),
        border: Border.all(color: k.warning.withValues(alpha: 0.45)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (final a in alerts)
            InkWell(
              key: ValueKey('${keyPrefix}alert-${a.key}'),
              onTap: () => context.push(alertRoute(a)),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      Icon(
                        urgent(a) ? Icons.error_outline_rounded : Icons.notifications_none_rounded,
                        size: 20,
                        color: urgent(a) ? k.danger : k.warning,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(label(a), style: text.bodyMedium?.copyWith(color: k.text)),
                      ),
                      Icon(Icons.chevron_right_rounded, size: 20, color: k.textMuted),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
