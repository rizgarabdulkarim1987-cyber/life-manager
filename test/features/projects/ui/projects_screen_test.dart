import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/providers.dart';
import 'package:life_manager/core/storage/secure_store.dart';
import 'package:life_manager/features/projects/ai/planner.dart';
import 'package:life_manager/features/projects/data/projects_repository.dart';

import '../../../helpers/app_harness.dart';
import '../../../helpers/finance_ui.dart';

void main() {
  testWidgets('the Projects tab is empty at first, then lists a project with its progress', (t) async {
    final c = await pumpApp(t, locale: 'en');
    await t.tap(find.byKey(const ValueKey('nav-3')));
    await settle(t);
    expect(find.byKey(const ValueKey('projects-empty')), findsOneWidget);
    final repo = ProjectsRepository(dbOf(c));
    final id = await repo.create(title: 'Coffee shop');
    await repo.applyPlan(
      id,
      const PlanProposal(
        phases: [
          PlanPhase('A', [PlanStep('One', null), PlanStep('Two', null)]),
        ],
      ),
    );
    await repo.setStepDone((await repo.stepsOf(id)).first.id, true);
    await settle(t);
    expect(find.text('Coffee shop'), findsOneWidget);
    expect(find.text('1 of 2 steps done'), findsOneWidget);
  });

  testWidgets('the detail screen hides the cost until the eye is tapped and makes tasks from steps', (t) async {
    t.view.physicalSize = const Size(800, 1600);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final c = await pumpApp(t, locale: 'en', revealMoney: false);
    final repo = ProjectsRepository(dbOf(c));
    final id = await repo.create(title: 'Coffee shop');
    await repo.applyPlan(
      id,
      const PlanProposal(
        phases: [
          PlanPhase('A', [PlanStep('One', null), PlanStep('Two', null)]),
        ],
      ),
    );
    await repo.setEstimate(id, costMinor: 1250000, currency: 'IQD');
    await t.tap(find.byKey(const ValueKey('nav-3')));
    await settle(t);
    await t.tap(find.byKey(ValueKey('project-$id')));
    await settle(t);
    expect(find.byKey(const ValueKey('project-cost-card')), findsOneWidget);
    expect(find.textContaining('1,250,000'), findsNothing, reason: 'the amount stays masked');
    await t.ensureVisible(find.byKey(const ValueKey('steps-to-tasks')));
    await t.tap(find.byKey(const ValueKey('steps-to-tasks')));
    await settle(t);
    expect((await repo.stepsOf(id)).every((s) => s.taskId != null), isTrue);
    expect(find.text('2 tasks added'), findsOneWidget);
  });

  testWidgets('the planner says online AI is needed when it is off', (t) async {
    final c = await pumpApp(t, locale: 'en', overrides: [secureStoreProvider.overrideWithValue(InMemorySecureStore())]);
    final repo = ProjectsRepository(dbOf(c));
    final id = await repo.create(title: 'Coffee shop');
    await t.tap(find.byKey(const ValueKey('nav-3')));
    await settle(t);
    await t.tap(find.byKey(ValueKey('project-$id')));
    await settle(t);
    await t.enterText(find.byKey(const ValueKey('planner-input')), 'a coffee shop');
    await t.tap(find.byKey(const ValueKey('planner-send')));
    await settle(t);
    expect(find.textContaining('needs online AI'), findsOneWidget);
    expect(await repo.messagesOf(id), isEmpty, reason: 'nothing is saved or sent when AI is off');
  });
}
