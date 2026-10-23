import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/core/db/app_database.dart';
import 'package:life_manager/features/tasks/data/tasks_repository.dart';

Matcher same(DateTime d) => predicate<DateTime?>((x) => x != null && x.isAtSameMomentAs(d), 'is $d');

void main() {
  late AppDatabase db;
  late TasksRepository repo;
  late DateTime now;
  late List<List<int>> changes;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    now = DateTime(2026, 10, 23, 12);
    changes = [];
    repo = TasksRepository(db, now: () => now, onChanged: (ids) async => changes.add(ids.toList()));
  });
  tearDown(() => db.close());

  test('create stores UTC times, cleaned tags and trimmed text', () async {
    final id = await repo.create(
      TaskInput(
        title: '  Call Ahmed ',
        notes: '   ',
        dueAt: DateTime(2026, 10, 24, 9),
        remindAt: DateTime(2026, 10, 24, 8),
        tags: ['Client', 'client', ' Urgent '],
        priority: 'high',
      ),
    );
    final t = (await repo.get(id))!;
    expect((t.title, t.notes, t.tags, t.priority, t.status), ('Call Ahmed', null, 'client,urgent', 'high', 'todo'));
    expect(t.dueAt, same(DateTime(2026, 10, 24, 9)));
    expect(changes.single, [id]);
  });

  test('validation: title, priority, recurrence needs a due date', () async {
    await expectLater(repo.create(TaskInput(title: '  ')), throwsArgumentError);
    await expectLater(repo.create(TaskInput(title: 'x' * 201)), throwsArgumentError);
    await expectLater(repo.create(TaskInput(title: 'a', priority: 'meh')), throwsArgumentError);
    await expectLater(repo.create(TaskInput(title: 'a', recurrence: 'daily')), throwsArgumentError);
    await expectLater(repo.create(TaskInput(title: 'a', dueAt: now, recurrence: 'hourly')), throwsArgumentError);
    expect(await db.select(db.tasks).get(), isEmpty);
  });

  test('update replaces the fields and notifies', () async {
    final id = await repo.create(TaskInput(title: 'a'));
    changes.clear();
    await repo.update(id, TaskInput(title: 'b', notes: 'n', priority: 'low'));
    final t = (await repo.get(id))!;
    expect((t.title, t.notes, t.priority), ('b', 'n', 'low'));
    expect(changes.single, [id]);
  });

  test('complete marks done with a time; completing twice does nothing', () async {
    final id = await repo.create(TaskInput(title: 'a'));
    expect(await repo.complete(id), isNull);
    final t = (await repo.get(id))!;
    expect(t.status, 'done');
    expect(t.completedAt, same(now));
    changes.clear();
    expect(await repo.complete(id), isNull);
    expect(changes, isEmpty);
  });

  test('a repeating task spawns the next occurrence with the same reminder gap and open copies of its steps', () async {
    final id = await repo.create(
      TaskInput(
        title: 'Rent',
        dueAt: DateTime(2026, 10, 20, 9),
        remindAt: DateTime(2026, 10, 20, 8),
        recurrence: 'monthly',
        tags: ['home'],
        workspaceId: null,
      ),
    );
    final step = await repo.addStep(id, 'Transfer');
    await repo.complete(step);
    final next = await repo.complete(id);
    final n = (await repo.get(next!))!;
    expect(n.status, 'todo');
    expect(n.dueAt!.toLocal(), DateTime(2026, 11, 20, 9));
    expect(n.remindAt!.toLocal(), DateTime(2026, 11, 20, 8));
    expect((n.recurrence, n.tags), ('monthly', 'home'));
    final steps = await (db.select(db.tasks)..where((t) => t.parentId.equals(next))).get();
    expect(steps.map((s) => (s.title, s.status)), [('Transfer', 'todo')]);
    expect((await repo.get(id))!.status, 'done');
    expect(changes.last, [id, next]);
  });

  test('finishing a daily task days late gives a future date, not a backlog', () async {
    final id = await repo.create(TaskInput(title: 'Stretch', dueAt: DateTime(2026, 10, 10, 7), recurrence: 'daily'));
    final next = await repo.complete(id);
    expect((await repo.get(next!))!.dueAt!.toLocal(), DateTime(2026, 10, 24, 7));
  });

  test('a step of a repeating task does not repeat', () async {
    final id = await repo.create(TaskInput(title: 'p', dueAt: DateTime(2026, 10, 25), recurrence: 'daily'));
    final step = await repo.addStep(id, 's');
    await repo.complete(step);
    expect(await db.select(db.tasks).get(), hasLength(2));
  });

  test('reopening clears the completion time', () async {
    final id = await repo.create(TaskInput(title: 'a'));
    await repo.complete(id);
    await repo.setStatus(id, 'doing');
    final t = (await repo.get(id))!;
    expect((t.status, t.completedAt), ('doing', null));
    await expectLater(repo.setStatus(id, 'weird'), throwsArgumentError);
  });

  test('deleting a task removes its steps and reports them', () async {
    final id = await repo.create(TaskInput(title: 'p'));
    final s = await repo.addStep(id, 's');
    changes.clear();
    await repo.delete(id);
    expect(await db.select(db.tasks).get(), isEmpty);
    expect(changes.single, [id, s]);
  });

  test('setReminder moves only the reminder', () async {
    final id = await repo.create(
      TaskInput(title: 'a', dueAt: DateTime(2026, 10, 25), remindAt: DateTime(2026, 10, 24)),
    );
    await repo.setReminder(id, DateTime(2026, 10, 24, 10));
    final t = (await repo.get(id))!;
    expect(t.remindAt, same(DateTime(2026, 10, 24, 10)));
    expect(t.dueAt, same(DateTime(2026, 10, 25)));
  });

  test('openWithReminder lists only open tasks that have one', () async {
    final a = await repo.create(TaskInput(title: 'a', remindAt: DateTime(2026, 10, 30)));
    final b = await repo.create(TaskInput(title: 'b', remindAt: DateTime(2026, 10, 30)));
    await repo.create(TaskInput(title: 'c'));
    await repo.complete(b);
    expect((await repo.openWithReminder()).map((t) => t.id), [a]);
  });

  test('meeting notes: create, update, delete; tasks keep living when their note is deleted', () async {
    final notes = MeetingNotesRepository(db, now: () => now);
    final n = await notes.create(title: ' Weekly ', body: 'a\nb');
    expect((await notes.get(n))!.title, 'Weekly');
    await notes.update(n, title: 'Weekly 2', body: 'x');
    expect((await notes.get(n))!.body, 'x');
    final t = await repo.create(TaskInput(title: 'follow up', meetingNoteId: n));
    await notes.delete(n);
    expect((await repo.get(t))!.meetingNoteId, isNull);
    await expectLater(notes.create(title: ' '), throwsArgumentError);
  });
}
