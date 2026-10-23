import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/features/tasks/data/notes_repository.dart';
import 'package:life_manager/features/tasks/reminders/reminder_service.dart';
import 'package:life_manager/features/tasks/data/tasks_repository.dart';

import '../../../helpers/app_harness.dart';
import '../../../helpers/fake_notifications.dart';
import '../../../helpers/finance_ui.dart';

void main() {
  Future<(TasksRepository, NotesRepository)> open(WidgetTester t) async {
    final c = await pumpApp(t, locale: 'en');
    await t.tap(find.byKey(const ValueKey('nav-2')));
    await settle(t);
    return (TasksRepository(dbOf(c)), NotesRepository(dbOf(c)));
  }

  Future<void> segment(WidgetTester t, String name) async {
    await t.ensureVisible(find.byKey(ValueKey('segment-$name')));
    await t.pump();
    await t.tap(find.byKey(ValueKey('segment-$name')));
    await settle(t);
  }

  testWidgets('Today is empty at first and lists what is due today', (t) async {
    final (repo, _) = await open(t);
    expect(find.byKey(const ValueKey('tasks-empty')), findsOneWidget);
    final now = DateTime.now();
    await repo.add(title: 'Call Ahmed', dueAt: DateTime(now.year, now.month, now.day, 17), hasTime: true);
    await repo.add(title: 'Someday');
    await settle(t);
    expect(find.text('Call Ahmed'), findsOneWidget);
    expect(find.text('Someday'), findsNothing);
    await segment(t, 'noDate');
    expect(find.text('Someday'), findsOneWidget);
  });

  testWidgets('the checkbox completes a task, Done lists it, Undo reopens it', (t) async {
    final (repo, _) = await open(t);
    final now = DateTime.now();
    final id = await repo.add(title: 'Pay rent', dueAt: DateTime(now.year, now.month, now.day));
    await settle(t);
    await t.tap(find.byKey(ValueKey('task-check-$id')));
    await settle(t);
    expect(find.text('Pay rent'), findsNothing);
    await t.tap(find.text('Undo'));
    await settle(t);
    expect(find.text('Pay rent'), findsOneWidget);
    await t.tap(find.byKey(ValueKey('task-check-$id')));
    await settle(t);
    await segment(t, 'done');
    expect(find.text('Pay rent'), findsOneWidget);
  });

  testWidgets('swiping deletes a task and Undo brings it back', (t) async {
    final (repo, _) = await open(t);
    final now = DateTime.now();
    final id = await repo.add(title: 'Old thing', dueAt: DateTime(now.year, now.month, now.day));
    await settle(t);
    await t.drag(find.byKey(ValueKey('task-row-$id')), const Offset(-600, 0));
    await settle(t);
    expect(find.text('Old thing'), findsNothing);
    expect(await repo.get(id), isNull);
    await t.tap(find.text('Undo'));
    await settle(t);
    expect(find.text('Old thing'), findsOneWidget);
  });

  testWidgets('the form creates a task with no date, found under No date', (t) async {
    final (repo, _) = await open(t);
    await t.tap(find.byKey(const ValueKey('tasks-add')));
    await settle(t);
    expect(saveEnabled(t, 'task-save'), isFalse);
    await t.enterText(find.byKey(const ValueKey('task-title')), 'Buy a charger');
    await settle(t);
    await t.tap(find.byKey(const ValueKey('task-save')));
    await settle(t);
    await segment(t, 'noDate');
    expect(find.text('Buy a charger'), findsOneWidget);
    expect((await repo.open()).single.title, 'Buy a charger');
  });

  testWidgets('tapping a row edits it', (t) async {
    final (repo, _) = await open(t);
    final id = await repo.add(title: 'Draft');
    await segment(t, 'noDate');
    await t.tap(find.byKey(ValueKey('task-$id')));
    await settle(t);
    await t.enterText(find.byKey(const ValueKey('task-title')), 'Final');
    await settle(t);
    await t.tap(find.byKey(const ValueKey('task-save')));
    await settle(t);
    expect((await repo.get(id))!.title, 'Final');
  });

  testWidgets('the calendar puts a dot on days with tasks and lists the picked day', (t) async {
    t.view.physicalSize = const Size(800, 1400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final (repo, _) = await open(t);
    final now = DateTime.now();
    await repo.add(title: 'Dentist', dueAt: DateTime(now.year, now.month, 15, 10), hasTime: true, kind: 'appointment');
    await settle(t);
    await segment(t, 'calendar');
    expect(find.byKey(const ValueKey('cal-dot-15')), findsOneWidget);
    expect(find.byKey(const ValueKey('cal-dot-16')), findsNothing);
    await t.tap(find.byKey(const ValueKey('cal-day-15')));
    await settle(t);
    expect(find.text('Dentist'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('cal-next')));
    await settle(t);
    expect(find.byKey(const ValueKey('cal-dot-15')), findsNothing);
  });

  testWidgets('notes: add from the sheet, edit, delete with undo', (t) async {
    final (_, notes) = await open(t);
    await segment(t, 'notes');
    expect(find.byKey(const ValueKey('notes-empty')), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('tasks-add')));
    await settle(t);
    await t.enterText(find.byKey(const ValueKey('note-field')), 'Idea for the shop');
    await settle(t);
    await t.tap(find.byKey(const ValueKey('note-save')));
    await settle(t);
    expect(find.text('Idea for the shop'), findsOneWidget);
    final id = (await t.runAsync(() => notes.watchAll().first))!.single.id;
    await t.drag(find.byKey(ValueKey('note-row-$id')), const Offset(-600, 0));
    await settle(t);
    expect(find.text('Idea for the shop'), findsNothing);
    await t.tap(find.text('Undo'));
    await settle(t);
    expect(find.text('Idea for the shop'), findsOneWidget);
  });

  testWidgets('a banner warns when exact alarms are off, and Allow asks for them', (t) async {
    final port = FakeNotificationPort()..exact = false;
    await pumpApp(t, locale: 'en', overrides: [notificationPortProvider.overrideWithValue(port)]);
    await t.tap(find.byKey(const ValueKey('nav-2')));
    await settle(t);
    expect(find.byKey(const ValueKey('exact-alarm-warning')), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('exact-alarm-allow')));
    await settle(t);
    expect(find.byKey(const ValueKey('exact-alarm-warning')), findsNothing);
  });

  testWidgets('saving a task schedules its reminder', (t) async {
    final port = FakeNotificationPort();
    final c = await pumpApp(t, locale: 'en', overrides: [notificationPortProvider.overrideWithValue(port)]);
    await t.tap(find.byKey(const ValueKey('nav-2')));
    await settle(t);
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final id = await TasksRepository(dbOf(c))
        .add(title: 'Soon', dueAt: DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 10), hasTime: true);
    await settle(t);
    expect(port.scheduled.keys, contains(id));
  });
}
