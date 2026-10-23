import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/features/finance/data/buckets_repository.dart';
import 'package:life_manager/features/finance/data/budgets_repository.dart';
import 'package:life_manager/features/finance/data/rates_repository.dart';
import 'package:life_manager/features/finance/data/transactions_repository.dart';
import 'package:life_manager/features/projects/ai/planner.dart';
import 'package:life_manager/features/projects/data/projects_repository.dart';
import 'package:life_manager/features/shell/tips.dart';
import 'package:life_manager/features/tasks/data/tasks_repository.dart';

import '../../helpers/finance_fixtures.dart';

void main() {
  late FinanceFixture f;
  final now = DateTime(2026, 10, 23, 12);

  setUp(() async => f = await financeFixture());
  tearDown(() => f.db.close());

  Future<int> bucket(String key) async =>
      (await (f.db.select(f.db.buckets)..where((b) => b.systemKey.equals(key))).getSingle()).id;

  test('nothing to say → all clear', () async {
    final tips = await computeTips(f.db, now);
    expect(tips.first.kind, TipKind.allClear);
  });

  test('a budget at 80% or more is the tip, named without amounts', () async {
    await BudgetsRepository(
      f.db,
      RatesRepository(f.db),
    ).create(categoryId: f.cat('transport'), amountMinor: 100000, currencyCode: 'IQD');
    await TransactionsRepository(f.db).addSimple(
      type: 'expense',
      accountId: f.personalIqd,
      amountMinor: 85000,
      categoryId: f.cat('transport'),
      occurredAt: now.toUtc(),
    );
    final tip = (await computeTips(f.db, now)).first;
    expect(tip.kind, TipKind.budgetNear);
    expect(tip.args.join(' '), isNot(contains('85')));
    expect(tip.args.single, isNotEmpty);
  });

  test('Emergency below its target', () async {
    await BucketsRepository(f.db, RatesRepository(f.db)).setTarget(await bucket('emergency'), 1000000);
    final tips = await computeTips(f.db, now);
    expect(tips.first.kind, TipKind.emergencyLow);
  });

  test('tip picks overdue first, even when a budget is near', () async {
    await BudgetsRepository(
      f.db,
      RatesRepository(f.db),
    ).create(categoryId: f.cat('transport'), amountMinor: 100000, currencyCode: 'IQD');
    await TransactionsRepository(f.db).addSimple(
      type: 'expense',
      accountId: f.personalIqd,
      amountMinor: 85000,
      categoryId: f.cat('transport'),
      occurredAt: now.toUtc(),
    );
    await TasksRepository(f.db).add(title: 'Old', dueAt: DateTime(2026, 10, 20));
    await TasksRepository(f.db).add(title: 'Older', dueAt: DateTime(2026, 10, 1));
    await TasksRepository(f.db).add(title: 'Today', dueAt: DateTime(2026, 10, 23));
    final tips = await computeTips(f.db, now);
    expect(tips.first.kind, TipKind.overdueTasks);
    expect(tips.first.args, ['2'], reason: 'a task due today is not overdue');
    expect(tips.map((t) => t.kind), contains(TipKind.budgetNear));
  });

  test('a project step due this week is a tip; a done one or a dropped project is not', () async {
    final repo = ProjectsRepository(f.db);
    final id = await repo.create(title: 'Coffee shop');
    await repo.applyPlan(
      id,
      PlanProposal(
        phases: [
          PlanPhase('A', [PlanStep('Find a shop', DateTime(2026, 10, 27)), PlanStep('Later', DateTime(2026, 12, 1))]),
        ],
      ),
    );
    var tips = await computeTips(f.db, now);
    expect(tips.first.kind, TipKind.projectStepSoon);
    expect(tips.first.args, ['Find a shop', 'Coffee shop']);
    await repo.setStepDone((await repo.stepsOf(id)).first.id, true);
    expect((await computeTips(f.db, now)).first.kind, TipKind.allClear);
    await repo.setStepDone((await repo.stepsOf(id)).first.id, false);
    await repo.setStatus(id, 'dropped');
    tips = await computeTips(f.db, now);
    expect(tips.first.kind, TipKind.allClear);
  });
}
