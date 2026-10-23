import 'package:drift/drift.dart';

import '../../../core/db/app_database.dart';
import '../domain/recurrence.dart';
import '../domain/task_views.dart';

/// What the task form saves. Times are on the owner's clock; they are stored as UTC.
class TaskInput {
  TaskInput({
    required String title,
    String? notes,
    this.workspaceId,
    this.priority = 'normal',
    this.dueAt,
    this.dueAllDay = false,
    this.remindAt,
    this.recurrence,
    this.recurrenceInterval = 1,
    Iterable<String> tags = const [],
    this.captureId,
    this.meetingNoteId,
  }) : title = title.trim(),
       notes = notes == null || notes.trim().isEmpty ? null : notes.trim(),
       tags = joinTags(tags);

  final String title;
  final String? notes;
  final int? workspaceId;
  final String priority;
  final DateTime? dueAt;
  final bool dueAllDay;
  final DateTime? remindAt;
  final String? recurrence;
  final int recurrenceInterval;
  final String tags;
  final int? captureId;
  final int? meetingNoteId;
}

/// Called with every task id whose reminder may need to change.
typedef TaskChanged = Future<void> Function(Iterable<int> taskIds);

class TasksRepository {
  TasksRepository(this._db, {this._onChanged, DateTime Function()? now}) : _now = now ?? DateTime.now;

  final AppDatabase _db;
  final TaskChanged? _onChanged;
  final DateTime Function() _now;

  void _validate(TaskInput i) {
    if (i.title.isEmpty || i.title.length > 200) throw ArgumentError('title must be 1–200 characters');
    if ((i.notes?.length ?? 0) > 4000) throw ArgumentError('notes are too long');
    if (!kTaskPriorities.contains(i.priority)) throw ArgumentError('unknown priority');
    final r = i.recurrence;
    if (r != null && !kTaskRecurrences.contains(r)) throw ArgumentError('unknown recurrence');
    if (r != null && i.dueAt == null) throw ArgumentError('a repeating task needs a due date');
    if (i.recurrenceInterval < 1 || i.recurrenceInterval > 365) throw ArgumentError('bad recurrence interval');
  }

  Future<void> _changed(Iterable<int> ids) async => _onChanged?.call(ids);

  Stream<List<Task>> watchTop() => (_db.select(_db.tasks)..where((t) => t.parentId.isNull())).watch();

  Stream<List<Task>> watchSteps(int parentId) =>
      (_db.select(_db.tasks)
            ..where((t) => t.parentId.equals(parentId))
            ..orderBy([(t) => OrderingTerm.asc(t.id)]))
          .watch();

  Stream<Task?> watchOne(int id) => (_db.select(_db.tasks)..where((t) => t.id.equals(id))).watchSingleOrNull();

  Future<Task?> get(int id) => (_db.select(_db.tasks)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<List<Task>> openWithReminder() =>
      (_db.select(_db.tasks)..where((t) => t.status.equals('done').not() & t.remindAt.isNotNull())).get();

  TasksCompanion _companion(TaskInput i) => TasksCompanion(
    title: Value(i.title),
    notes: Value(i.notes),
    workspaceId: Value(i.workspaceId),
    priority: Value(i.priority),
    dueAt: Value(i.dueAt?.toUtc()),
    dueAllDay: Value(i.dueAllDay),
    remindAt: Value(i.remindAt?.toUtc()),
    recurrence: Value(i.recurrence),
    recurrenceInterval: Value(i.recurrenceInterval),
    tags: Value(i.tags),
    captureId: Value(i.captureId),
    meetingNoteId: Value(i.meetingNoteId),
  );

  Future<int> create(TaskInput i, {int? parentId}) async {
    _validate(i);
    final now = _now().toUtc();
    final id = await _db
        .into(_db.tasks)
        .insert(_companion(i).copyWith(parentId: Value(parentId), createdAt: Value(now), updatedAt: Value(now)));
    await _changed([id]);
    return id;
  }

  Future<void> update(int id, TaskInput i) async {
    _validate(i);
    await (_db.update(
      _db.tasks,
    )..where((t) => t.id.equals(id))).write(_companion(i).copyWith(updatedAt: Value(_now().toUtc())));
    await _changed([id]);
  }

  Future<int> addStep(int parentId, String title) => create(TaskInput(title: title), parentId: parentId);

  Future<void> setStatus(int id, String status) async {
    if (!kTaskStatuses.contains(status)) throw ArgumentError('unknown status');
    if (status == 'done') {
      await complete(id);
      return;
    }
    await (_db.update(_db.tasks)..where((t) => t.id.equals(id))).write(
      TasksCompanion(status: Value(status), completedAt: const Value(null), updatedAt: Value(_now().toUtc())),
    );
    await _changed([id]);
  }

  /// Marks the task done. A repeating task also gets its next occurrence, with
  /// its steps copied as open; the new task's id is returned.
  Future<int?> complete(int id) async {
    final t = await get(id);
    if (t == null || t.status == 'done') return null;
    final now = _now();
    int? next;
    await _db.transaction(() async {
      await (_db.update(_db.tasks)..where((r) => r.id.equals(id))).write(
        TasksCompanion(status: const Value('done'), completedAt: Value(now.toUtc()), updatedAt: Value(now.toUtc())),
      );
      final rule = t.recurrence;
      final due = t.dueAt?.toLocal();
      if (t.parentId == null && rule != null && due != null) {
        final nextDue = nextOccurrenceAfter(due, rule, t.recurrenceInterval, now);
        final remind = t.remindAt?.toLocal();
        next = await _db
            .into(_db.tasks)
            .insert(
              TasksCompanion.insert(
                title: t.title,
                notes: Value(t.notes),
                workspaceId: Value(t.workspaceId),
                priority: Value(t.priority),
                dueAt: Value(nextDue.toUtc()),
                dueAllDay: Value(t.dueAllDay),
                remindAt: Value(remind == null ? null : nextDue.add(remind.difference(due)).toUtc()),
                recurrence: Value(rule),
                recurrenceInterval: Value(t.recurrenceInterval),
                tags: Value(t.tags),
                meetingNoteId: Value(t.meetingNoteId),
                createdAt: now.toUtc(),
                updatedAt: now.toUtc(),
              ),
            );
        for (final step in await (_db.select(_db.tasks)..where((s) => s.parentId.equals(id))).get()) {
          await _db
              .into(_db.tasks)
              .insert(
                TasksCompanion.insert(
                  parentId: Value(next),
                  title: step.title,
                  createdAt: now.toUtc(),
                  updatedAt: now.toUtc(),
                ),
              );
        }
      }
    });
    await _changed([id, ?next]);
    return next;
  }

  Future<void> delete(int id) async {
    final steps = await (_db.select(_db.tasks)..where((t) => t.parentId.equals(id))).get();
    await (_db.delete(_db.tasks)..where((t) => t.id.equals(id))).go();
    await _changed([id, for (final s in steps) s.id]);
  }

  /// Moves a reminder to [at] (Snooze) without touching anything else.
  Future<void> setReminder(int id, DateTime? at) async {
    await (_db.update(_db.tasks)..where((t) => t.id.equals(id))).write(
      TasksCompanion(remindAt: Value(at?.toUtc()), updatedAt: Value(_now().toUtc())),
    );
    await _changed([id]);
  }
}

class MeetingNotesRepository {
  MeetingNotesRepository(this._db, {DateTime Function()? now}) : _now = now ?? DateTime.now;

  final AppDatabase _db;
  final DateTime Function() _now;

  Stream<List<MeetingNote>> watchAll() =>
      (_db.select(_db.meetingNotes)..orderBy([(n) => OrderingTerm.desc(n.updatedAt)])).watch();

  Future<MeetingNote?> get(int id) => (_db.select(_db.meetingNotes)..where((n) => n.id.equals(id))).getSingleOrNull();

  Future<int> create({required String title, String body = '', int? workspaceId}) async {
    final t = title.trim();
    if (t.isEmpty || t.length > 200) throw ArgumentError('title must be 1–200 characters');
    final now = _now().toUtc();
    return _db
        .into(_db.meetingNotes)
        .insert(
          MeetingNotesCompanion.insert(
            title: t,
            body: Value(body),
            workspaceId: Value(workspaceId),
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  Future<void> update(int id, {required String title, required String body, int? workspaceId}) async {
    final t = title.trim();
    if (t.isEmpty || t.length > 200) throw ArgumentError('title must be 1–200 characters');
    await (_db.update(_db.meetingNotes)..where((n) => n.id.equals(id))).write(
      MeetingNotesCompanion(
        title: Value(t),
        body: Value(body),
        workspaceId: Value(workspaceId),
        updatedAt: Value(_now().toUtc()),
      ),
    );
  }

  Future<void> delete(int id) => (_db.delete(_db.meetingNotes)..where((n) => n.id.equals(id))).go();
}
