// Drift check constraints reference their own column getter by design.
// ignore_for_file: recursive_getters

import 'package:drift/drift.dart';

import 'capture_tables.dart';
import 'tables.dart';

const kTaskPriorities = ['low', 'normal', 'high', 'urgent'];
const kTaskStatuses = ['todo', 'doing', 'done'];
const kTaskRecurrences = ['daily', 'weekly', 'monthly', 'yearly'];

/// Free text the owner writes or dictates in a meeting. Its action points
/// become tasks (spec §8.6).
class MeetingNotes extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text().withLength(min: 1, max: 200)();
  TextColumn get body => text().withDefault(const Constant(''))();
  IntColumn get workspaceId => integer().nullable().references(Workspaces, #id, onDelete: KeyAction.restrict)();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
}

/// A task or, with [parentId], one step of a task (spec §11). Times are UTC;
/// [dueAllDay] means only the local date of [dueAt] counts.
@TableIndex(name: 'task_due', columns: {#dueAt})
@TableIndex(name: 'task_parent', columns: {#parentId})
class Tasks extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get parentId => integer().nullable().references(Tasks, #id, onDelete: KeyAction.cascade)();
  TextColumn get title => text().withLength(min: 1, max: 200)();
  TextColumn get notes => text().nullable().withLength(max: 4000)();
  IntColumn get workspaceId => integer().nullable().references(Workspaces, #id, onDelete: KeyAction.restrict)();
  TextColumn get priority => text().withDefault(const Constant('normal')).check(priority.isIn(kTaskPriorities))();
  TextColumn get status => text().withDefault(const Constant('todo')).check(status.isIn(kTaskStatuses))();
  DateTimeColumn get dueAt => dateTime().nullable()();
  BoolColumn get dueAllDay => boolean().withDefault(const Constant(false))();
  DateTimeColumn get remindAt => dateTime().nullable()();
  TextColumn get recurrence => text().nullable().check(recurrence.isNull() | recurrence.isIn(kTaskRecurrences))();
  IntColumn get recurrenceInterval =>
      integer().withDefault(const Constant(1)).check(recurrenceInterval.isBetweenValues(1, 365))();

  /// Comma-separated, lower-cased, no empty parts.
  TextColumn get tags => text().withDefault(const Constant(''))();
  DateTimeColumn get completedAt => dateTime().nullable()();
  IntColumn get captureId => integer().nullable().references(Captures, #id, onDelete: KeyAction.setNull)();
  IntColumn get meetingNoteId => integer().nullable().references(MeetingNotes, #id, onDelete: KeyAction.setNull)();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
}
