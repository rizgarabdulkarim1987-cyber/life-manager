import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/core/db/app_database.dart';
import 'package:life_manager/features/tasks/data/notes_repository.dart';
import 'package:life_manager/features/tasks/data/tasks_repository.dart';

void main() {
  late AppDatabase db;
  late TasksRepository repo;
  // Friday 23 Oct 2026, 14:30 local.
  final now = DateTime(2026, 10, 23, 14, 30);

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = TasksRepository(db);
  });
  tearDown(() => db.close());

  Future<List<String>> titles(TaskView v) async => [for (final t in await repo.watchView(v, now).first) t.title];

  test('views split at local midnight', () async {
    await repo.add(title: 'yesterday late', dueAt: DateTime(2026, 10, 22, 23, 59));
    await repo.add(title: 'today start', dueAt: DateTime(2026, 10, 23));
    await repo.add(title: 'today end', dueAt: DateTime(2026, 10, 23, 23, 59), hasTime: true);
    await repo.add(title: 'tomorrow start', dueAt: DateTime(2026, 10, 24));
    await repo.add(title: 'no date');
    expect(await titles(TaskView.overdue), ['yesterday late']);
    expect(await titles(TaskView.today), ['today start', 'today end']);
    expect(await titles(TaskView.upcoming), ['tomorrow start']);
    expect(await titles(TaskView.inbox), ['no date']);
    expect(await titles(TaskView.done), isEmpty);
  });

  test('completing moves a task to Done and out of the open views', () async {
    final id = await repo.add(title: 'a', dueAt: DateTime(2026, 10, 23));
    expect(await repo.complete(id), isNull);
    expect(await titles(TaskView.today), isEmpty);
    expect(await titles(TaskView.done), ['a']);
    await repo.reopen(id);
    expect(await titles(TaskView.today), ['a']);
  });

  test('a recurring task spawns the next occurrence when completed', () async {
    final daily = await repo.add(title: 'd', dueAt: DateTime(2026, 10, 23, 9), hasTime: true, recurrence: 'daily');
    final weekly = await repo.add(title: 'w', dueAt: DateTime(2026, 10, 23), recurrence: 'weekly');
    final monthly = await repo.add(title: 'm', dueAt: DateTime(2026, 1, 31, 8), hasTime: true, recurrence: 'monthly');
    final undated = await repo.add(title: 'u', recurrence: 'daily');
    final d = (await repo.get((await repo.complete(daily))!))!;
    expect(d.dueAt!.isAtSameMomentAs(DateTime(2026, 10, 24, 9)), isTrue);
    expect(d.hasTime, isTrue);
    expect(d.status, 'open');
    final w = (await repo.get((await repo.complete(weekly))!))!;
    expect(w.dueAt!.isAtSameMomentAs(DateTime(2026, 10, 30)), isTrue);
    final m = (await repo.get((await repo.complete(monthly))!))!;
    expect(m.dueAt!.isAtSameMomentAs(DateTime(2026, 2, 28, 8)), isTrue, reason: 'clamped to the shorter month');
    expect(await repo.complete(undated), isNull, reason: 'nothing to repeat from');
    expect(await repo.complete(daily), isNull, reason: 'already done');
  });

  test('delete and restore round-trip the row', () async {
    final id = await repo.add(
      title: 'x',
      notes: 'n',
      kind: 'appointment',
      place: 'Mansour',
      dueAt: DateTime(2026, 10, 25, 10),
      hasTime: true,
    );
    final before = (await repo.get(id))!;
    final gone = await repo.delete(id);
    expect(await repo.get(id), isNull);
    await repo.restore(gone!);
    expect(await repo.get(id), before);
  });

  test('watchMonth lists the month only, open and done', () async {
    await repo.add(title: 'in', dueAt: DateTime(2026, 10, 31, 23, 59));
    final done = await repo.add(title: 'done', dueAt: DateTime(2026, 10, 1));
    await repo.complete(done);
    await repo.add(title: 'next', dueAt: DateTime(2026, 11, 1));
    await repo.add(title: 'prev', dueAt: DateTime(2026, 9, 30, 23, 59));
    final list = await repo.watchMonth(DateTime(2026, 10, 15)).first;
    expect([for (final t in list) t.title], ['done', 'in']);
  });

  test('rejects an empty title and a time without a date', () async {
    expect(() => repo.add(title: '  '), throwsArgumentError);
    final id = await repo.add(title: 't', hasTime: true);
    expect((await repo.get(id))!.hasTime, isFalse);
    await repo.update(id, const TasksCompanion(priority: Value(2)));
    expect((await repo.get(id))!.priority, 2);
  });

  test('notes: add, edit, delete, restore, filter by project', () async {
    final notes = NotesRepository(db);
    final a = await notes.add('  first ');
    final b = await notes.add('in project', projectId: 7);
    expect((await notes.get(a))!.body, 'first');
    await notes.update(a, 'edited');
    expect((await notes.watchAll().first).map((n) => n.body), containsAll(['edited', 'in project']));
    expect((await notes.watchAll(projectId: 7).first).single.id, b);
    final gone = await notes.delete(a);
    expect(await notes.get(a), isNull);
    await notes.restore(gone!);
    expect((await notes.get(a))!.body, 'edited');
    expect(() => notes.add(' '), throwsArgumentError);
  });
}
