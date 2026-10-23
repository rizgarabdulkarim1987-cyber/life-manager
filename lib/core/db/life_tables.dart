// Drift check constraints reference their own column getter by design.
// ignore_for_file: recursive_getters

import 'package:drift/drift.dart';

import 'tables.dart';

const kTaskKinds = ['task', 'appointment', 'reminder'];
const kRecurrences = ['none', 'daily', 'weekly', 'monthly'];

/// Tasks, appointments and reminders share one table (redesign §9.2).
class Tasks extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text().withLength(min: 1, max: 300)();
  TextColumn get notes => text().nullable()();
  TextColumn get kind => text().withDefault(const Constant('task')).check(kind.isIn(kTaskKinds))();
  DateTimeColumn get dueAt => dateTime().nullable()();

  /// False when only the day was given; `dueAt` is then local midnight.
  BoolColumn get hasTime => boolean().withDefault(const Constant(false))();
  TextColumn get place => text().nullable()();
  IntColumn get priority => integer().withDefault(const Constant(1)).check(priority.isBetweenValues(0, 2))();
  TextColumn get status => text().withDefault(const Constant('open')).check(status.isIn(const ['open', 'done']))();
  TextColumn get recurrence => text().withDefault(const Constant('none')).check(recurrence.isIn(kRecurrences))();
  IntColumn get workspaceId => integer().nullable().references(Workspaces, #id, onDelete: KeyAction.setNull)();

  /// Plain ints, no foreign keys: a deleted project or capture must never block.
  IntColumn get projectId => integer().nullable()();
  IntColumn get projectStepId => integer().nullable()();
  IntColumn get captureId => integer().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get completedAt => dateTime().nullable()();
}

class Notes extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get body => text().withLength(min: 1, max: 5000)();
  IntColumn get projectId => integer().nullable()();
  IntColumn get captureId => integer().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
}
