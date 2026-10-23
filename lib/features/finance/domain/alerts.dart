import 'budgets_math.dart';
import 'buckets_math.dart';
import 'installments.dart';

/// In-app finance alerts (Home card and Finance banner). System notifications
/// arrive with the reminder stack in Phase 4.
sealed class FinanceAlert {
  const FinanceAlert();

  /// Stable identity, for lists and later for notification ids.
  String get key;
}

final class ExpensesBucketUsed extends FinanceAlert {
  const ExpensesBucketUsed(this.percentBp);

  /// The threshold reached: 8000 or 10000.
  final int percentBp;

  @override
  String get key => 'bucket-expenses-$percentBp';
}

final class EmergencyTargetReached extends FinanceAlert {
  const EmergencyTargetReached();

  @override
  String get key => 'bucket-emergency-reached';
}

final class EmergencyBelowTarget extends FinanceAlert {
  const EmergencyBelowTarget();

  @override
  String get key => 'bucket-emergency-below';
}

final class UnallocatedIncome extends FinanceAlert {
  const UnallocatedIncome(this.count);

  final int count;

  @override
  String get key => 'income-unallocated';
}

final class BudgetUsed extends FinanceAlert {
  const BudgetUsed(this.budgetId, this.percentBp);

  final int budgetId;
  final int percentBp;

  @override
  String get key => 'budget-$budgetId-$percentBp';
}

final class DebtDueSoon extends FinanceAlert {
  const DebtDueSoon(this.debtId, this.due);

  final int debtId;
  final DateTime due;

  @override
  String get key => 'debt-$debtId-soon';
}

final class DebtOverdue extends FinanceAlert {
  const DebtOverdue(this.debtId);

  final int debtId;

  @override
  String get key => 'debt-$debtId-overdue';
}

int? _threshold(int? usedBp) => usedBp == null
    ? null
    : usedBp >= 10000
    ? 10000
    : usedBp >= 8000
    ? 8000
    : null;

List<FinanceAlert> evaluateAlerts({
  required List<BucketStatus> buckets,
  required List<BudgetProgress> budgets,
  required List<DebtSummary> debts,
  required int unallocatedIncomeCount,
  required bool unallocatedAlertOn,
  required DateTime now,
}) {
  final out = <FinanceAlert>[];
  for (final b in buckets) {
    switch (b.bucket.systemKey) {
      case 'expenses':
        final t = _threshold(b.usedBp);
        if (t != null) out.add(ExpensesBucketUsed(t));
      case 'emergency':
        final target = b.targetMinor;
        if (target == null || target <= 0) break;
        if (b.availableMinor >= target) {
          out.add(const EmergencyTargetReached());
        } else if (b.spentMinor > 0 && b.allocatedMinor >= target) {
          out.add(const EmergencyBelowTarget());
        }
    }
  }
  if (unallocatedAlertOn && unallocatedIncomeCount > 0) out.add(UnallocatedIncome(unallocatedIncomeCount));
  for (final p in budgets) {
    final t = _threshold(p.percentBp);
    if (t != null) out.add(BudgetUsed(p.budget.id, t));
  }
  final soon = now.add(const Duration(days: 7));
  for (final d in debts) {
    if (d.remainingMinor <= 0) continue;
    if (d.overdue) {
      out.add(DebtOverdue(d.debt.id));
    } else if (d.nextDue != null && !d.nextDue!.isAfter(soon)) {
      out.add(DebtDueSoon(d.debt.id, d.nextDue!));
    }
  }
  return out;
}
