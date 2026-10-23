import 'package:drift/drift.dart';

import '../../../core/db/app_database.dart';

enum TaskView { today, upcoming, overdue, inbox, done }

DateTime _midnight(DateTime d) => DateTime(d.year, d.month, d.day);

/// The same time of day, [months] later, held to the last day of a shorter month.
DateTime _addMonths(DateTime d, int months) {
  final first = DateTime(d.year, d.month + months);
  final last = DateTime(first.year, first.month + 1, 0).day;
  return DateTime(first.year, first.month, d.day > last ? last : d.day, d.hour, d.minute);
}

DateTime nextOccurrence(DateTime due, String recurrence) => switch (recurrence) {
  'daily' => DateTime(due.year, due.month, due.day + 1, due.hour, due.minute),
  'weekly' => DateTime(due.year, due.month, due.day + 7, due.hour, due.minute),
  'monthly' => _addMonths(due, 1),
  _ => due,
};

class TasksRepository {
  TasksRepository(this._db);

  final AppDatabase _db;

  DateTime get _now => DateTime.now().toUtc();

  Future<int> add({
    required String title,
    String? notes,
    String kind = 'task',
    DateTime? dueAt,
    bool hasTime = false,
    String? place,
    int priority = 1,
    String recurrence = 'none',
    int? workspaceId,
    int? projectId,
    int? projectStepId,
    int? captureId,
  }) {
    final t = title.trim();
    if (t.isEmpty) throw ArgumentError.value(title, 'title');
    return _db
        .into(_db.tasks)
        .insert(
          TasksCompanion.insert(
            title: t,
            notes: Value(notes),
            kind: Value(kind),
            dueAt: Value(dueAt),
            hasTime: Value(hasTime && dueAt != null),
            place: Value(place),
            priority: Value(priority),
            recurrence: Value(recurrence),
            workspaceId: Value(workspaceId),
            projectId: Value(projectId),
            projectStepId: Value(projectStepId),
            captureId: Value(captureId),
            createdAt: _now,
          ),
        );
  }

  Future<Task?> get(int id) => (_db.select(_db.tasks)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<void> update(int id, TasksCompanion changes) =>
      (_db.update(_db.tasks)..where((t) => t.id.equals(id))).write(changes);

  /// Marks the task done; a recurring one with a date spawns the next occurrence.
  /// Returns the new task's id, if any.
  Future<int?> complete(int id) => _db.transaction(() async {
    final t = await get(id);
    if (t == null || t.status == 'done') return null;
    await update(id, TasksCompanion(status: const Value('done'), completedAt: Value(_now)));
    final due = t.dueAt;
    if (t.recurrence == 'none' || due == null) return null;
    return add(
      title: t.title,
      notes: t.notes,
      kind: t.kind,
      dueAt: nextOccurrence(due, t.recurrence),
      hasTime: t.hasTime,
      place: t.place,
      priority: t.priority,
      recurrence: t.recurrence,
      workspaceId: t.workspaceId,
      projectId: t.projectId,
      projectStepId: t.projectStepId,
    );
  });

  Future<void> setDue(int id, DateTime? due, {bool hasTime = false}) =>
      update(id, TasksCompanion(dueAt: Value(due), hasTime: Value(due != null && hasTime)));

  Future<void> reopen(int id) => update(id, const TasksCompanion(status: Value('open'), completedAt: Value(null)));

  /// Deletes and returns the row, so Undo can [restore] it.
  Future<Task?> delete(int id) async {
    final t = await get(id);
    if (t != null) await (_db.delete(_db.tasks)..where((x) => x.id.equals(id))).go();
    return t;
  }

  Future<void> restore(Task t) => _db.into(_db.tasks).insert(t, mode: InsertMode.insertOrReplace);

  Stream<List<Task>> watchOpen() => (_db.select(_db.tasks)..where((t) => t.status.equals('open'))).watch();

  Future<List<Task>> open() => (_db.select(_db.tasks)..where((t) => t.status.equals('open'))).get();

  /// Boundaries are local midnights: due at 00:00 today is Today, due at 23:59 yesterday is Overdue.
  Stream<List<Task>> watchView(TaskView v, DateTime now) {
    final today = _midnight(now);
    final tomorrow = DateTime(today.year, today.month, today.day + 1);
    final q = _db.select(_db.tasks);
    switch (v) {
      case TaskView.today:
        q
          ..where(
            (t) => t.status.equals('open') & t.dueAt.isBiggerOrEqualValue(today) & t.dueAt.isSmallerThanValue(tomorrow),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.dueAt), (t) => OrderingTerm.desc(t.priority)]);
      case TaskView.upcoming:
        q
          ..where((t) => t.status.equals('open') & t.dueAt.isBiggerOrEqualValue(tomorrow))
          ..orderBy([(t) => OrderingTerm.asc(t.dueAt)]);
      case TaskView.overdue:
        q
          ..where((t) => t.status.equals('open') & t.dueAt.isSmallerThanValue(today))
          ..orderBy([(t) => OrderingTerm.asc(t.dueAt)]);
      case TaskView.inbox:
        q
          ..where((t) => t.status.equals('open') & t.dueAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.priority), (t) => OrderingTerm.desc(t.createdAt)]);
      case TaskView.done:
        q
          ..where((t) => t.status.equals('done'))
          ..orderBy([(t) => OrderingTerm.desc(t.completedAt)])
          ..limit(100);
    }
    return q.watch();
  }

  /// Every task with a due date in [month]'s local calendar month, open or done.
  Stream<List<Task>> watchMonth(DateTime month) {
    final from = DateTime(month.year, month.month);
    final to = DateTime(month.year, month.month + 1);
    return (_db.select(_db.tasks)
          ..where((t) => t.dueAt.isBiggerOrEqualValue(from) & t.dueAt.isSmallerThanValue(to))
          ..orderBy([(t) => OrderingTerm.asc(t.dueAt)]))
        .watch();
  }
}
