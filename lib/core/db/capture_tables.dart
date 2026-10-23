// Drift check constraints reference their own column getter by design.
// ignore_for_file: recursive_getters

import 'package:drift/drift.dart';

/// A capture is written before any network call, so nothing is ever lost
/// (spec §8.1). Audio stays inside the encrypted DB and is dropped once the
/// capture is saved or discarded.
class Captures extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get source => text().check(source.isIn(const ['voice', 'text']))();
  TextColumn get status => text().check(status.isIn(const ['pending', 'done', 'discarded']))();
  BlobColumn get audio => blob().nullable()();
  TextColumn get transcript => text().nullable()();
  TextColumn get parsedJson => text().nullable()();
  TextColumn get parsedBy => text().nullable().check(parsedBy.isIn(const ['ai', 'rules']))();

  /// The error's type name only, never its message.
  TextColumn get failureType => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
}
