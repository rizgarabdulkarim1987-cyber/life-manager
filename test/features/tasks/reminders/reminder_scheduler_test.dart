import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/core/db/app_database.dart';
import 'package:life_manager/features/tasks/data/tasks_repository.dart';
import 'package:life_manager/features/tasks/reminders/reminder_scheduler.dart';

import '../../../helpers/fake_notifications.dart';

void main() {
  late AppDatabase db;
  late TasksRepository repo;
  late FakeNotificationPort port;
  // Friday 23 Oct 2026, 14:30.
  final now = DateTime(2026, 10, 23, 14, 30);

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = TasksRepository(db);
    port = FakeNotificationPort();
  });
  tearDown(() => db.close());

  Future<void> sync() async => ReminderScheduler(port).sync(await repo.open(), now);

  test('a future timed task fires at its time, a date-only one at 09:00 on its day', () async {
    final a = await repo.add(title: 'call', dueAt: DateTime(2026, 10, 23, 17), hasTime: true);
    final b = await repo.add(title: 'rent', dueAt: DateTime(2026, 10, 25));
    await sync();
    expect(port.scheduled[a], PlannedReminder('call', DateTime(2026, 10, 23, 17)));
    expect(port.scheduled[b], PlannedReminder('rent', DateTime(2026, 10, 25, 9)));
  });

  test('an overdue task gets a 09:00 nudge, tomorrow once 09:00 has passed', () async {
    final late = await repo.add(title: 'late', dueAt: DateTime(2026, 10, 20, 8), hasTime: true);
    await sync();
    expect(port.scheduled[late]!.at, DateTime(2026, 10, 24, 9));
    await ReminderScheduler(port).sync(await repo.open(), DateTime(2026, 10, 23, 7));
    expect(port.scheduled[late]!.at, DateTime(2026, 10, 23, 9));
  });

  test('tasks without a date, done tasks and deleted tasks have nothing scheduled', () async {
    final undated = await repo.add(title: 'someday');
    final done = await repo.add(title: 'done', dueAt: DateTime(2026, 10, 30));
    final gone = await repo.add(title: 'gone', dueAt: DateTime(2026, 10, 31));
    await sync();
    expect(port.scheduled.keys, unorderedEquals([done, gone]));
    expect(port.scheduled.containsKey(undated), isFalse);
    await repo.complete(done);
    await repo.delete(gone);
    await sync();
    expect(port.scheduled, isEmpty);
    expect(port.cancelled, containsAll([done, gone]));
  });

  test('changing a due date moves the notification', () async {
    final id = await repo.add(title: 'x', dueAt: DateTime(2026, 10, 26, 10), hasTime: true);
    await sync();
    await repo.setDue(id, DateTime(2026, 10, 27, 11), hasTime: true);
    await sync();
    expect(port.scheduled[id]!.at, DateTime(2026, 10, 27, 11));
    expect(port.scheduled, hasLength(1));
  });

  test('the notification buttons: Done completes, snoozes move the time', () async {
    final actions = ReminderActions(repo);
    final id = await repo.add(title: 'x', dueAt: DateTime(2026, 10, 23, 14), hasTime: true);
    await actions.handle(ReminderAction.snooze10, id, now);
    expect((await repo.get(id))!.dueAt!.isAtSameMomentAs(DateTime(2026, 10, 23, 14, 40)), isTrue);
    await actions.handle(ReminderAction.snooze60, id, now);
    expect((await repo.get(id))!.dueAt!.isAtSameMomentAs(DateTime(2026, 10, 23, 15, 30)), isTrue);
    await actions.handle(ReminderAction.snoozeTomorrow, id, now);
    final t = (await repo.get(id))!;
    expect(t.dueAt!.isAtSameMomentAs(DateTime(2026, 10, 24, 9)), isTrue);
    expect(t.hasTime, isTrue);
    await actions.handle(ReminderAction.done, id, now);
    expect((await repo.get(id))!.status, 'done');
    await actions.handle(ReminderAction.done, 999, now);
    await actions.handle(ReminderAction.snooze10, 999, now);
  });
}
