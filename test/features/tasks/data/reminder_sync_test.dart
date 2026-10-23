import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/core/db/app_database.dart';
import 'package:life_manager/features/tasks/data/task_reminder_sync.dart';
import 'package:life_manager/features/tasks/data/tasks_repository.dart';
import 'package:life_manager/features/tasks/platform/reminder_scheduler.dart';

import '../../../helpers/fake_reminders.dart';

void main() {
  late AppDatabase db;
  late FakeReminderScheduler scheduler;
  late TasksRepository repo;
  late TaskReminderSync sync;
  final now = DateTime(2026, 10, 23, 12);

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    scheduler = FakeReminderScheduler();
    late TasksRepository r;
    sync = TaskReminderSync(tasks: () => r, scheduler: scheduler, texts: () async => fakeReminderTexts, now: () => now);
    r = repo = TasksRepository(db, now: () => now, onChanged: sync.sync);
  });
  tearDown(() => db.close());

  test('a task with a future reminder is scheduled with its title and the notification words', () async {
    final id = await repo.create(
      TaskInput(title: 'Call Ahmed', dueAt: DateTime(2026, 10, 24, 9), remindAt: DateTime(2026, 10, 24, 8)),
    );
    final r = scheduler.scheduled[id]!;
    expect((r.title, r.texts.done), ('Call Ahmed', 'Done'));
    expect(r.at.isAtSameMomentAs(DateTime(2026, 10, 24, 8)), isTrue);
  });

  test('no reminder, a past reminder, a step or a finished task is cancelled instead', () async {
    final none = await repo.create(TaskInput(title: 'a'));
    final past = await repo.create(TaskInput(title: 'b', remindAt: DateTime(2026, 10, 1)));
    final parent = await repo.create(TaskInput(title: 'c'));
    final step = await repo.create(
      TaskInput(title: 'd', remindAt: DateTime(2026, 11)),
      parentId: parent,
    );
    final done = await repo.create(TaskInput(title: 'e', remindAt: DateTime(2026, 11)));
    expect(scheduler.scheduled.containsKey(done), isTrue);
    await repo.complete(done);
    expect(scheduler.scheduled, isEmpty);
    expect(scheduler.cancelled, containsAll([none, past, step, done]));
  });

  test('editing the reminder moves the alarm; clearing it cancels', () async {
    final id = await repo.create(TaskInput(title: 'a', remindAt: DateTime(2026, 11, 1)));
    await repo.update(id, TaskInput(title: 'a', remindAt: DateTime(2026, 11, 2)));
    expect(scheduler.scheduled[id]!.at.isAtSameMomentAs(DateTime(2026, 11, 2)), isTrue);
    await repo.update(id, TaskInput(title: 'a'));
    expect(scheduler.scheduled, isEmpty);
  });

  test('finishing a repeating task schedules the next one', () async {
    final id = await repo.create(
      TaskInput(
        title: 'Rent',
        dueAt: DateTime(2026, 10, 25, 9),
        remindAt: DateTime(2026, 10, 25, 8),
        recurrence: 'monthly',
      ),
    );
    final next = await repo.complete(id);
    expect(scheduler.scheduled.keys, [next]);
    expect(scheduler.scheduled[next]!.at.isAtSameMomentAs(DateTime(2026, 11, 25, 8)), isTrue);
  });

  test('deleting a task cancels its alarm', () async {
    final id = await repo.create(TaskInput(title: 'a', remindAt: DateTime(2026, 11)));
    await repo.delete(id);
    expect(scheduler.scheduled, isEmpty);
  });

  test('syncAll schedules open future reminders and drops native ones with no task', () async {
    final keep = await repo.create(TaskInput(title: 'keep', remindAt: DateTime(2026, 12)));
    scheduler.scheduled.clear();
    scheduler.scheduled[999] = stub(999);
    await sync.syncAll();
    expect(scheduler.scheduled.keys, [keep]);
    expect(scheduler.cancelled, contains(999));
  });

  test('syncAll leaves a nagging reminder of an open task alone', () async {
    final id = await repo.create(TaskInput(title: 'late', remindAt: DateTime(2026, 10, 20)));
    scheduler.scheduled[id] = stub(id);
    scheduler.cancelled.clear();
    await sync.syncAll();
    expect(scheduler.cancelled, isEmpty);
    expect(scheduler.scheduled.containsKey(id), isTrue);
  });

  test('a failing scheduler never breaks saving a task', () async {
    final broken = _Broken();
    late TasksRepository r;
    final s = TaskReminderSync(tasks: () => r, scheduler: broken, texts: () async => fakeReminderTexts, now: () => now);
    r = TasksRepository(db, now: () => now, onChanged: s.sync);
    final id = await r.create(TaskInput(title: 'x', remindAt: DateTime(2026, 12)));
    expect((await r.get(id))!.title, 'x');
  });

  group('intake', () {
    test('Done taps from notifications complete the tasks; the open task and shared text come back once', () async {
      final a = await repo.create(TaskInput(title: 'a'));
      scheduler.doneActions.add(a);
      scheduler.doneActions.add(12345);
      scheduler.openTask = 7;
      scheduler.sharedText = '  hello  ';
      final intake = await takeIntake(scheduler, repo);
      expect((await repo.get(a))!.status, 'done');
      expect((intake.openTaskId, intake.sharedText), (7, 'hello'));
      final again = await takeIntake(scheduler, repo);
      expect((again.openTaskId, again.sharedText), (null, null));
    });

    test('blank shared text is nothing', () async {
      scheduler.sharedText = '   ';
      expect((await takeIntake(scheduler, repo)).sharedText, isNull);
    });
  });
}

ReminderRequest stub(int id) => ReminderRequest(taskId: id, at: DateTime(2030), title: 't', texts: fakeReminderTexts);

class _Broken extends FakeReminderScheduler {
  @override
  Future<void> schedule(ReminderRequest r) async => throw StateError('no alarm service');

  @override
  Future<void> cancel(int taskId) async => throw StateError('no alarm service');
}
