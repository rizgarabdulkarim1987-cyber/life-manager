import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/features/capture/ui/composer.dart';
import 'package:life_manager/features/finance/ui/widgets/money_text.dart';
import 'package:life_manager/features/projects/ai/planner.dart';
import 'package:life_manager/features/projects/data/projects_repository.dart';
import 'package:life_manager/features/tasks/data/tasks_repository.dart';

import '../../helpers/app_harness.dart';
import '../../helpers/finance_ui.dart';

void main() {
  testWidgets('home shows no money digits', (t) async {
    final c = await pumpApp(t, locale: 'en');
    final p = await accountId(c, 'Personal', 'IQD');
    await txRepo(c).addSimple(
      type: 'expense',
      accountId: p,
      amountMinor: 250000,
      description: 'lunch',
      occurredAt: DateTime.now().toUtc(),
    );
    await settle(t);
    expect(find.byType(MoneyText), findsNothing);
    expect(find.textContaining('250'), findsNothing);
    expect(find.text('lunch'), findsOneWidget, reason: 'the entry shows by its words');
  });

  testWidgets('home shows the large composer and no second one', (t) async {
    await pumpApp(t, locale: 'en');
    expect(find.byType(Composer), findsOneWidget);
    expect(t.widget<Composer>(find.byType(Composer)).large, isTrue);
    expect(find.byKey(const ValueKey('home-tip')), findsOneWidget);
  });

  testWidgets('recent entry swipe deletes with undo', (t) async {
    final c = await pumpApp(t, locale: 'en');
    final p = await accountId(c, 'Personal', 'IQD');
    final id = await txRepo(c).addSimple(
      type: 'expense',
      accountId: p,
      amountMinor: 40000,
      description: 'taxi',
      occurredAt: DateTime.now().toUtc(),
    );
    await settle(t);
    final row = find.byKey(ValueKey('recent-$id'));
    await t.scrollUntilVisible(row, 200, scrollable: find.byType(Scrollable).first);
    await t.drag(row, const Offset(-600, 0));
    await settle(t);
    expect(await t.runAsync(() => txRepo(c).get(id)), isNull);
    await t.tap(find.text('Undo'));
    await settle(t);
    expect((await t.runAsync(() => txRepo(c).get(id)))!.amountMinor, 40000);
  });

  testWidgets('Home lists overdue and due-today tasks and the active projects with progress', (t) async {
    t.view.physicalSize = const Size(800, 2200);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final c = await pumpApp(t, locale: 'en');
    final now = DateTime.now();
    final tasks = TasksRepository(dbOf(c));
    await tasks.add(title: 'Pay rent', dueAt: DateTime(now.year, now.month, now.day - 2));
    await tasks.add(title: 'Call Ahmed', dueAt: DateTime(now.year, now.month, now.day, 17), hasTime: true);
    await tasks.add(title: 'Next month', dueAt: DateTime(now.year, now.month + 1, 5));
    final projects = ProjectsRepository(dbOf(c));
    final id = await projects.create(title: 'Coffee shop');
    await projects.applyPlan(
      id,
      const PlanProposal(
        phases: [
          PlanPhase('A', [PlanStep('One', null), PlanStep('Two', null)]),
        ],
      ),
    );
    await projects.setStepDone((await projects.stepsOf(id)).first.id, true);
    final dropped = await projects.create(title: 'Dropped idea');
    await projects.setStatus(dropped, 'dropped');
    await settle(t);
    final today = find.byKey(const ValueKey('home-today'));
    expect(find.descendant(of: today, matching: find.text('Pay rent')), findsOneWidget);
    expect(find.descendant(of: today, matching: find.text('Call Ahmed')), findsOneWidget);
    expect(find.descendant(of: today, matching: find.text('Next month')), findsNothing);
    final box = find.byKey(const ValueKey('home-projects'));
    expect(find.descendant(of: box, matching: find.text('Coffee shop')), findsOneWidget);
    expect(find.descendant(of: box, matching: find.text('1 of 2 steps done')), findsOneWidget);
    expect(find.descendant(of: box, matching: find.text('Dropped idea')), findsNothing);
    expect(find.text('1 task is overdue.'), findsOneWidget, reason: 'the tip');
  });
}
