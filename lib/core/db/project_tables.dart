// Drift check constraints reference their own column getter by design.
// ignore_for_file: recursive_getters

import 'package:drift/drift.dart';

const kProjectStatuses = ['idea', 'planning', 'active', 'done', 'dropped'];

/// A project the AI planner chat helps plan; its cost is tracked against the Investment bucket (redesign §9.3).
class Projects extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text().withLength(min: 1, max: 200)();
  TextColumn get description => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('idea')).check(status.isIn(kProjectStatuses))();

  /// The planner's or the owner's cost estimate in [currencyCode] minor units.
  IntColumn get estCostMinor => integer().nullable()();
  TextColumn get currencyCode => text().nullable().withLength(min: 3, max: 3)();
  DateTimeColumn get targetDate => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  IntColumn get captureId => integer().nullable()();
}

class ProjectSteps extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get projectId => integer().references(Projects, #id, onDelete: KeyAction.cascade)();

  /// Order inside the project, from 1.
  IntColumn get seq => integer()();
  TextColumn get phase => text().nullable()();
  TextColumn get title => text().withLength(min: 1, max: 300)();
  DateTimeColumn get dueDate => dateTime().nullable()();
  BoolColumn get done => boolean().withDefault(const Constant(false))();

  /// The task made from this step, if any (a plain int: deleting the task must not break the step).
  IntColumn get taskId => integer().nullable()();
}

class ProjectMessages extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get projectId => integer().references(Projects, #id, onDelete: KeyAction.cascade)();
  TextColumn get role => text().check(role.isIn(const ['user', 'assistant']))();
  TextColumn get body => text()();
  DateTimeColumn get createdAt => dateTime()();
}
