import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/core/db/app_database.dart';
import 'package:life_manager/features/finance/domain/alerts.dart';
import 'package:life_manager/features/finance/domain/buckets_math.dart';

Bucket b(int id, String key, int bp, {int? target}) =>
    Bucket(id: id, systemKey: key, percentBp: bp, targetMinor: target, sortOrder: id);

BucketStatus s(Bucket bucket, {int allocated = 0, int spent = 0}) => BucketStatus(
  bucket: bucket,
  allocatedMinor: allocated,
  spentMinor: spent,
  availableMinor: allocated - spent,
  targetMinor: bucket.targetMinor,
);

void main() {
  final now = DateTime(2026, 10, 23);

  test('defaultSplit 1,000,001 at 7000/2000/1000 → 700001/200000/100000', () {
    expect(defaultSplit(1000001, [7000, 2000, 1000]), [700001, 200000, 100000]);
  });

  test('defaultSplit sums to the total and breaks ties by order', () {
    expect(defaultSplit(10, [5000, 5000]), [5, 5]);
    expect(defaultSplit(11, [5000, 5000]), [6, 5]);
    expect(defaultSplit(0, [7000, 3000]), [0, 0]);
  });

  List<FinanceAlert> alerts(List<BucketStatus> buckets, {int unallocated = 0, bool on = false}) => evaluateAlerts(
    buckets: buckets,
    budgets: const [],
    debts: const [],
    unallocatedIncomeCount: unallocated,
    unallocatedAlertOn: on,
    now: now,
  );

  test('alerts at 79.99% none, 80% one, 100% one ExpensesBucketUsed(10000)', () {
    final e = b(1, 'expenses', 7000);
    expect(alerts([s(e, allocated: 10000, spent: 7999)]), isEmpty);
    final at80 = alerts([s(e, allocated: 10000, spent: 8000)]);
    expect(at80.single, isA<ExpensesBucketUsed>().having((a) => a.percentBp, 'bp', 8000));
    final at100 = alerts([s(e, allocated: 10000, spent: 12000)]);
    expect(at100.single, isA<ExpensesBucketUsed>().having((a) => a.percentBp, 'bp', 10000));
  });

  test('no expenses alert when nothing was allocated', () {
    expect(alerts([s(b(1, 'expenses', 7000), spent: 500)]), isEmpty);
  });

  test('emergency target reached, and below target after a tagged withdrawal', () {
    final em = b(2, 'emergency', 2000, target: 1000);
    expect(alerts([s(em, allocated: 1000)]).single, isA<EmergencyTargetReached>());
    expect(alerts([s(em, allocated: 1200, spent: 300)]).single, isA<EmergencyBelowTarget>());
    expect(alerts([s(em, allocated: 500)]), isEmpty);
  });

  test('unallocated alert only when the setting is on', () {
    expect(alerts(const [], unallocated: 3), isEmpty);
    expect(alerts(const [], unallocated: 3, on: true).single, isA<UnallocatedIncome>().having((a) => a.count, 'n', 3));
    expect(alerts(const [], unallocated: 0, on: true), isEmpty);
  });

  test('alert keys are stable and distinct', () {
    final keys = [
      const ExpensesBucketUsed(8000).key,
      const ExpensesBucketUsed(10000).key,
      const EmergencyTargetReached().key,
      const EmergencyBelowTarget().key,
      const UnallocatedIncome(2).key,
      const BudgetUsed(1, 8000).key,
      DebtDueSoon(1, now).key,
      const DebtOverdue(1).key,
    ];
    expect(keys.toSet(), hasLength(keys.length));
  });
}
