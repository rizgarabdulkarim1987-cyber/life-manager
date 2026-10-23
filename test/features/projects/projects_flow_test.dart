import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/core/db/app_database.dart';
import 'package:life_manager/features/finance/data/transactions_repository.dart';
import 'package:life_manager/features/projects/ai/planner.dart';
import 'package:life_manager/features/projects/data/projects_providers.dart';
import 'package:life_manager/features/projects/data/projects_repository.dart';
import 'package:life_manager/features/tasks/data/tasks_repository.dart';

import '../../helpers/finance_fixtures.dart';

PlanProposal _plan() => const PlanProposal(
  phases: [
    PlanPhase('Prepare', [PlanStep('Find a shop', null), PlanStep('Buy a machine', null)]),
  ],
);

void main() {
  late AppDatabase db;
  late ProjectsRepository repo;
  late TasksRepository tasks;
  late int id;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = ProjectsRepository(db);
    tasks = TasksRepository(db);
    id = await repo.create(title: 'Coffee shop');
    await repo.applyPlan(id, _plan());
  });
  tearDown(() => db.close());

  test('steps to tasks links taskId and does not duplicate on a second tap', () async {
    expect(await repo.makeAllTasks(id), 2);
    final steps = await repo.stepsOf(id);
    expect(steps.every((s) => s.taskId != null), isTrue);
    final all = await db.select(db.tasks).get();
    expect(all.map((t) => (t.title, t.projectId, t.projectStepId)), [
      ('Find a shop', id, steps[0].id),
      ('Buy a machine', id, steps[1].id),
    ]);
    expect(await repo.makeAllTasks(id), 0);
    expect(await db.select(db.tasks).get(), hasLength(2));
  });

  test('completing linked task marks step done, reopening undoes it', () async {
    final stepId = (await repo.stepsOf(id)).first.id;
    final taskId = (await repo.makeTask(stepId))!;
    await tasks.complete(taskId);
    expect((await repo.stepsOf(id)).first.done, isTrue);
    await tasks.reopen(taskId);
    expect((await repo.stepsOf(id)).first.done, isFalse);
  });

  test('a step whose task was deleted gets a fresh one', () async {
    final stepId = (await repo.stepsOf(id)).first.id;
    final first = (await repo.makeTask(stepId))!;
    await tasks.delete(first);
    final second = (await repo.makeTask(stepId))!;
    expect(second, isNot(first));
    expect((await repo.stepsOf(id)).first.taskId, second);
  });

  test('re-planning keeps the task link of a step and does not duplicate its task', () async {
    await repo.makeAllTasks(id);
    final before = await db.select(db.tasks).get();
    await repo.applyPlan(
      id,
      const PlanProposal(
        phases: [
          PlanPhase('New', [PlanStep('Find a shop', null), PlanStep('Hire staff', null)]),
        ],
      ),
    );
    final steps = await repo.stepsOf(id);
    expect(steps.first.taskId, before.firstWhere((t) => t.title == 'Find a shop').id);
    expect(steps.last.taskId, isNull);
    final shopTask = await tasks.get(steps.first.taskId!);
    expect(shopTask!.projectStepId, steps.first.id);
    final dropped = await tasks.get(before.firstWhere((t) => t.title == 'Buy a machine').id);
    expect((dropped!.projectId, dropped.projectStepId), (null, null), reason: 'a dropped step leaves a plain task');
    expect(await repo.makeAllTasks(id), 1, reason: 'only the new step gets a task');
    await tasks.complete(steps.first.taskId!);
    expect((await repo.stepsOf(id)).first.done, isTrue);
  });

  test('ticking a step, by hand or from the planner, completes its task', () async {
    await repo.makeAllTasks(id);
    final steps = await repo.stepsOf(id);
    await repo.setStepDone(steps[0].id, true);
    expect((await tasks.get(steps[0].taskId!))!.status, 'done');
    await repo.applyStepUpdates(id, const [StepUpdate(2, true)]);
    expect((await tasks.get(steps[1].taskId!))!.status, 'done');
    await repo.setStepDone(steps[0].id, false);
    final reopened = await tasks.get(steps[0].taskId!);
    expect((reopened!.status, reopened.completedAt), ('open', null));
  });

  test('investment average takes the last 3 full months only', () async {
    final f = await financeFixture();
    addTearDown(f.db.close);
    final invest = await (f.db.select(f.db.buckets)..where((b) => b.systemKey.equals('investment'))).getSingle();
    Future<void> alloc(DateTime at, int minor) async {
      final tx = await TransactionsRepository(f.db)
          .addSimple(type: 'income', accountId: f.personalIqd, amountMinor: minor, occurredAt: at.toUtc());
      await f.db
          .into(f.db.bucketAllocations)
          .insert(
            BucketAllocationsCompanion.insert(
              transactionId: tx,
              bucketId: invest.id,
              amountBaseMinor: minor,
              baseCurrency: 'IQD',
              createdAt: at.toUtc(),
            ),
          );
    }

    final now = DateTime(2026, 10, 23);
    await alloc(DateTime(2026, 9, 5), 300000);
    await alloc(DateTime(2026, 8, 5), 300000);
    await alloc(DateTime(2026, 7, 31, 12), 300000);
    await alloc(DateTime(2026, 6, 20), 9000000);
    await alloc(DateTime(2026, 10, 2), 9000000);
    expect(await investmentMonthlyAverage(f.db, now), 300000);
  });
}
