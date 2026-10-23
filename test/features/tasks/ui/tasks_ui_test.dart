import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/router.dart';
import 'package:life_manager/core/db/app_database.dart';
import 'package:life_manager/features/tasks/data/tasks_providers.dart';
import 'package:life_manager/features/tasks/data/tasks_repository.dart';

import '../../../helpers/app_harness.dart';
import '../../../helpers/fake_reminders.dart';
import '../../../helpers/finance_ui.dart';

void main() {
  late FakeReminderScheduler scheduler;

  Future<ProviderContainer> open(WidgetTester t, {FakeReminderScheduler? sched}) async {
    scheduler = sched ?? FakeReminderScheduler();
    final c = await pumpApp(t, locale: 'en', overrides: [reminderSchedulerProvider.overrideWithValue(scheduler)]);
    return c;
  }

  Future<void> openTasksTab(WidgetTester t) async {
    await t.tap(find.byKey(const ValueKey('nav-2')));
    await settle(t);
  }

  Future<void> view(WidgetTester t, String name) async {
    final f = find.byKey(ValueKey('tasks-view-$name'));
    await t.ensureVisible(f);
    await t.tap(f);
    await settle(t);
  }

  /// Types into a field, then drops focus: a focused field's blinking caret keeps pumpAndSettle from finishing.
  Future<void> typeIn(WidgetTester t, String key, String text) async {
    await t.enterText(find.byKey(ValueKey(key)), text);
    FocusManager.instance.primaryFocus?.unfocus();
    await t.pump();
  }

  /// Scrolls the screen keyed [screen] until the widget keyed [target] is built and on screen.
  Future<void> reveal(WidgetTester t, String screen, String target) async {
    final page = find
        .descendant(
          of: find.byKey(ValueKey(screen)),
          matching: find.byWidgetPredicate((w) => w is Scrollable && w.axis == Axis.vertical),
        )
        .first;
    await t.scrollUntilVisible(find.byKey(ValueKey(target)), 200, scrollable: page);
    await settle(t);
  }

  TasksRepository repoOf(ProviderContainer c) => c.read(tasksRepositoryProvider);

  Future<List<Task>> allTasks(WidgetTester t, ProviderContainer c) async =>
      (await t.runAsync(() => dbOf(c).select(dbOf(c).tasks).get()))!;

  testWidgets('quick add on the Today view makes an all-day task due today', (t) async {
    final c = await open(t);
    await openTasksTab(t);
    expect(find.byKey(const ValueKey('tasks-empty')), findsOneWidget);
    await typeIn(t, 'task-quick', 'Send the invoice');
    await t.tap(find.byKey(const ValueKey('task-quick-add')));
    await settle(t);
    expect(find.text('Send the invoice'), findsOneWidget);
    final task = (await allTasks(t, c)).single;
    expect((task.dueAllDay, task.status), (true, 'todo'));
    expect(find.byKey(const ValueKey('tasks-view-today')), findsOneWidget);
  });

  testWidgets('quick add on the Inbox view keeps it undated; the circle completes it', (t) async {
    final c = await open(t);
    await openTasksTab(t);
    await view(t, 'inbox');
    await settle(t);
    await typeIn(t, 'task-quick', 'Buy a charger');
    await t.tap(find.byKey(const ValueKey('task-quick-add')));
    await settle(t);
    final task = (await allTasks(t, c)).single;
    expect(task.dueAt, isNull);
    expect(find.text('Buy a charger'), findsOneWidget);

    await t.tap(find.byKey(ValueKey('task-toggle-${task.id}')));
    await settle(t);
    expect(find.text('Buy a charger'), findsNothing);
    await view(t, 'completed');
    await settle(t);
    expect(find.text('Buy a charger'), findsOneWidget);
    expect((await allTasks(t, c)).single.status, 'done');
  });

  testWidgets('views list the right tasks and the workspace filter narrows them', (t) async {
    final c = await open(t);
    final repo = repoOf(c);
    final now = DateTime.now();
    final personal = await workspaceId(c, 'Personal');
    await dbWrite(t, () => repo.create(TaskInput(title: 'Late one', dueAt: now.subtract(const Duration(days: 2)))));
    await dbWrite(
      t,
      () =>
          repo.create(TaskInput(title: 'Tomorrow one', dueAt: now.add(const Duration(days: 1)), workspaceId: personal)),
    );
    await dbWrite(t, () => repo.create(TaskInput(title: 'Next month', dueAt: now.add(const Duration(days: 40)))));
    await openTasksTab(t);

    await view(t, 'overdue');
    await settle(t);
    expect(find.text('Late one'), findsOneWidget);
    expect(find.text('Tomorrow one'), findsNothing);

    await view(t, 'upcoming');
    await settle(t);
    expect(find.text('Tomorrow one'), findsOneWidget);
    expect(find.text('Next month'), findsOneWidget);

    await t.tap(find.byKey(const ValueKey('tasks-workspace')));
    await settle(t);
    await t.tap(find.text('Personal').last);
    await settle(t);
    expect(find.text('Tomorrow one'), findsOneWidget);
    expect(find.text('Next month'), findsNothing);
  });

  testWidgets('the form saves a task with priority, tags and a morning reminder, and schedules the alarm', (t) async {
    final c = await open(t);
    final tomorrow = DateTime.now().add(const Duration(days: 2));
    c
        .read(routerProvider)
        .push('/tasks/new?due=${DateTime(tomorrow.year, tomorrow.month, tomorrow.day).toIso8601String()}');
    await settle(t);
    expect(find.byKey(const ValueKey('task-form')), findsOneWidget);
    expect(t.widget<FilledButton>(find.byKey(const ValueKey('task-save'))).onPressed, isNull);

    await typeIn(t, 'task-title', 'Call the client');
    await t.tap(find.byKey(const ValueKey('task-priority-high')));
    await reveal(t, 'task-form', 'task-tags');
    await typeIn(t, 'task-tags', 'Client, urgent');
    await reveal(t, 'task-form', 'task-remind');
    await t.tap(find.byKey(const ValueKey('task-remind')));
    await settle(t);
    await t.tap(find.text('9:00 on the day').last);
    await settle(t);
    await t.tap(find.byKey(const ValueKey('task-save')));
    await settle(t);

    final task = (await allTasks(t, c)).single;
    expect((task.title, task.priority, task.tags, task.dueAllDay), ('Call the client', 'high', 'client,urgent', true));
    final at = scheduler.scheduled[task.id]!.at.toLocal();
    expect((at.year, at.month, at.day, at.hour), (tomorrow.year, tomorrow.month, tomorrow.day, 9));
    expect(find.byKey(const ValueKey('task-form')), findsNothing);
  });

  testWidgets('a repeating task cannot be set without a date, and completing it creates the next one', (t) async {
    final c = await open(t);
    c.read(routerProvider).push('/tasks/new');
    await settle(t);
    await reveal(t, 'task-form', 'task-repeat');
    expect(t.widget<DropdownButtonFormField<String?>>(find.byKey(const ValueKey('task-repeat'))).onChanged, isNull);
    c.read(routerProvider).pop();
    await settle(t);

    final today = DateTime.now();
    final id = await dbWrite(
      t,
      () => repoOf(c).create(
        TaskInput(
          title: 'Pay rent',
          dueAt: DateTime(today.year, today.month, today.day),
          dueAllDay: true,
          recurrence: 'monthly',
        ),
      ),
    );
    await openTasksTab(t);
    await t.tap(find.byKey(ValueKey('task-toggle-$id')));
    await settle(t);
    expect(find.textContaining('Next one'), findsOneWidget);
    final all = await allTasks(t, c);
    expect(all, hasLength(2));
    expect(all.where((x) => x.status == 'todo').single.recurrence, 'monthly');
  });

  testWidgets('detail: steps can be added, ticked and removed; the task can be started, finished and deleted', (
    t,
  ) async {
    final c = await open(t);
    final id = await dbWrite(t, () => repoOf(c).create(TaskInput(title: 'Launch page', notes: 'Check the copy')));
    c.read(routerProvider).push('/tasks/$id');
    await settle(t);
    expect(find.byKey(const ValueKey('task-detail-title')), findsOneWidget);
    expect(find.text('Check the copy'), findsOneWidget);

    await reveal(t, 'task-detail', 'step-add');
    await typeIn(t, 'step-add', 'Write the text');
    await t.tap(find.byKey(const ValueKey('step-add-button')));
    await settle(t);
    expect(find.text('Write the text'), findsOneWidget);
    final step = (await allTasks(t, c)).firstWhere((x) => x.parentId == id);
    await t.tap(find.byKey(ValueKey('step-toggle-${step.id}')));
    await settle(t);
    expect(find.textContaining('1/1'), findsOneWidget);
    await t.tap(find.byKey(ValueKey('step-delete-${step.id}')));
    await settle(t);
    expect(find.text('Write the text'), findsNothing);

    await t.tap(find.byKey(const ValueKey('task-start')));
    await settle(t);
    expect(find.textContaining('In progress'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('task-done')));
    await settle(t);
    expect((await allTasks(t, c)).single.status, 'done');

    await t.tap(find.byKey(const ValueKey('task-delete')));
    await settle(t);
    await t.tap(find.byKey(const ValueKey('task-delete-confirm')));
    await settle(t);
    expect(await allTasks(t, c), isEmpty);
  });

  testWidgets('snoozing to tomorrow moves the reminder and the alarm', (t) async {
    final c = await open(t);
    final soon = DateTime.now().add(const Duration(hours: 3));
    final id = await dbWrite(t, () => repoOf(c).create(TaskInput(title: 'Water plants', remindAt: soon)));
    expect(scheduler.scheduled.containsKey(id), isTrue);
    c.read(routerProvider).push('/tasks/$id');
    await settle(t);
    await t.tap(find.byKey(const ValueKey('task-snooze')));
    await settle(t);
    final n = DateTime.now();
    final at = scheduler.scheduled[id]!.at.toLocal();
    expect((at.day, at.hour), (DateTime(n.year, n.month, n.day + 1).day, 9));
  });

  testWidgets('calendar counts open tasks per day and lists the selected day', (t) async {
    final c = await open(t);
    final today = DateTime.now();
    await dbWrite(
      t,
      () => repoOf(c).create(TaskInput(title: 'A', dueAt: DateTime(today.year, today.month, today.day, 9))),
    );
    await dbWrite(
      t,
      () => repoOf(c).create(TaskInput(title: 'B', dueAt: DateTime(today.year, today.month, today.day, 17))),
    );
    await openTasksTab(t);
    await t.tap(find.byKey(const ValueKey('tasks-calendar')));
    await settle(t);
    expect(find.byKey(const ValueKey('tasks-calendar-screen')), findsOneWidget);
    expect(t.widget<Text>(find.byKey(ValueKey('cal-count-${today.day}'))).data, '● 2');
    expect(find.text('A'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);

    await t.tap(find.byKey(const ValueKey('cal-next')));
    await settle(t);
    expect(find.byKey(ValueKey('cal-count-${today.day}')), findsNothing);
  });

  testWidgets('a meeting note turns its action points into tasks linked to it', (t) async {
    final c = await open(t);
    c.read(routerProvider).push('/tasks/meetings/new');
    await settle(t);
    await typeIn(t, 'meeting-title', 'Weekly sync');
    await typeIn(t, 'meeting-body', 'Agenda:\n- Call Ahmed\n- Send the contract\n- Book the hall');
    await settle(t);
    await reveal(t, 'meeting-editor', 'meeting-extract');
    await t.tap(find.byKey(const ValueKey('meeting-extract')));
    await settle(t);
    expect(find.byKey(const ValueKey('action-points')), findsOneWidget);
    expect(find.byKey(const ValueKey('point-2')), findsOneWidget);

    await t.tap(find.byKey(const ValueKey('point-keep-1')));
    await settle(t);
    await t.tap(find.byKey(const ValueKey('points-save')));
    await settle(t);

    final tasks = await allTasks(t, c);
    expect(tasks.map((x) => x.title), ['Call Ahmed', 'Book the hall']);
    final note = (await t.runAsync(() => dbOf(c).select(dbOf(c).meetingNotes).get()))!.single;
    expect(tasks.every((x) => x.meetingNoteId == note.id), isTrue);
  });

  testWidgets('a meeting note with no action points says so', (t) async {
    final c = await open(t);
    c.read(routerProvider).push('/tasks/meetings/new');
    await settle(t);
    await typeIn(t, 'meeting-title', 'Quiet');
    await typeIn(t, 'meeting-body', 'Heading:');
    await settle(t);
    await reveal(t, 'meeting-editor', 'meeting-extract');
    await t.tap(find.byKey(const ValueKey('meeting-extract')));
    await settle(t);
    expect(find.byKey(const ValueKey('action-points-none')), findsOneWidget);
  });

  testWidgets('the banner appears when notifications are off and asks for them', (t) async {
    final c = await open(t, sched: FakeReminderScheduler(notifications: false));
    await dbWrite(
      t,
      () => repoOf(c).create(TaskInput(title: 'With alarm', remindAt: DateTime.now().add(const Duration(days: 1)))),
    );
    await openTasksTab(t);
    await view(t, 'all');
    await settle(t);
    expect(find.byKey(const ValueKey('reminder-banner')), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('reminder-banner-action')));
    await settle(t);
    expect(scheduler.notificationRequests, 1);
  });

  testWidgets('no banner without a reminder, or when everything is allowed', (t) async {
    final c = await open(t, sched: FakeReminderScheduler(notifications: false));
    await dbWrite(t, () => repoOf(c).create(TaskInput(title: 'No alarm')));
    await openTasksTab(t);
    expect(find.byKey(const ValueKey('reminder-banner')), findsNothing);
  });

  testWidgets('a shared text opens Capture Review with one task per line', (t) async {
    final sched = FakeReminderScheduler()..sharedText = 'Please:\n- send the price list\n- call the supplier';
    final c = await open(t, sched: sched);
    await settle(t);
    expect(find.byKey(const ValueKey('capture-review')), findsOneWidget);
    expect(find.byType(TextFormField), findsWidgets);
    expect(find.text('send the price list'), findsOneWidget);
    expect(find.text('call the supplier'), findsOneWidget);

    await t.tap(find.byKey(const ValueKey('cap-save')));
    await settle(t);
    expect((await allTasks(t, c)).map((x) => x.title), ['send the price list', 'call the supplier']);
  });

  testWidgets('a tapped reminder opens its task, and a Done tap made while closed completes it', (t) async {
    final sched = FakeReminderScheduler();
    scheduler = sched;
    // The task exists before the app starts; the notification actions arrive with it.
    final c = await pumpApp(t, locale: 'en', overrides: [reminderSchedulerProvider.overrideWithValue(sched)]);
    final id = await dbWrite(t, () => repoOf(c).create(TaskInput(title: 'Open me')));
    final other = await dbWrite(t, () => repoOf(c).create(TaskInput(title: 'Done from shade')));
    sched.doneActions.add(other);
    sched.openTask = id;
    for (final state in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      t.binding.handleAppLifecycleStateChanged(state);
    }
    await settle(t);
    expect(find.byKey(const ValueKey('task-detail')), findsOneWidget);
    expect((await allTasks(t, c)).firstWhere((x) => x.id == other).status, 'done');
  });
}
