// Drift check constraints reference their own column getter by design.
// ignore_for_file: recursive_getters

import 'package:drift/drift.dart';

class Workspaces extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 80)();
  TextColumn get iconKey => text()();
  IntColumn get colorArgb => integer()();
  TextColumn get description => text().nullable()();
  TextColumn get notes => text().nullable()();
  IntColumn get sortOrder => integer()();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();

  /// Comma-separated names the capture parser also matches.
  TextColumn get aliases => text().withDefault(const Constant(''))();

  /// Whether this workspace's expenses count against the buckets (spec §10.3).
  BoolColumn get countsInBuckets => boolean().withDefault(const Constant(false))();
}

const kAccountKinds = ['cash', 'bank', 'savings', 'custom'];

class Accounts extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get workspaceId => integer().references(Workspaces, #id, onDelete: KeyAction.restrict)();
  TextColumn get name => text().withLength(min: 1, max: 80)();
  TextColumn get kind => text().check(kind.isIn(kAccountKinds))();
  TextColumn get currencyCode => text().withLength(min: 3, max: 3)();

  /// Integer minor units (IQD exponent 0, USD exponent 2). Never a double.
  IntColumn get openingBalanceMinor => integer().withDefault(const Constant(0))();
  IntColumn get sortOrder => integer()();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
}

/// Exactly one row, id 1.
@DataClassName('AppSetting')
class AppSettingsTable extends Table {
  @override
  String get tableName => 'app_settings';

  IntColumn get id => integer().check(id.equals(1)).withDefault(const Constant(1))();
  TextColumn get localeCode => text().withDefault(const Constant('ar'))();
  TextColumn get themeMode => text().withDefault(const Constant('light'))();
  IntColumn get lockTimeoutSeconds => integer().withDefault(const Constant(60))();
  BoolColumn get biometricEnabled => boolean().withDefault(const Constant(false))();
  TextColumn get baseCurrency => text().withDefault(const Constant('IQD'))();
  BoolColumn get setupCompleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get lastBackupAt => dateTime().nullable()();

  // Phase 2 (schema v2)
  BoolColumn get aiOnlineEnabled => boolean().withDefault(const Constant(true))();
  TextColumn get aiVoiceConsent => text().nullable().check(aiVoiceConsent.isIn(const ['granted', 'declined']))();
  TextColumn get aiParseConsent => text().nullable().check(aiParseConsent.isIn(const ['granted', 'declined']))();
  TextColumn get groqSttModel => text().withDefault(const Constant('whisper-large-v3-turbo'))();
  TextColumn get groqLlmModel => text().withDefault(const Constant('llama-3.3-70b-versatile'))();
  TextColumn get localWhisperModel =>
      text().withDefault(const Constant('small')).check(localWhisperModel.isIn(const ['small', 'base']))();
  BoolColumn get unallocatedIncomeAlert => boolean().withDefault(const Constant(false))();
  BoolColumn get bucketsConfirmed => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('BackupRecord')
class BackupMetadata extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get createdAt => dateTime()();
  TextColumn get kind => text().check(kind.isIn(const ['export', 'restore']))();
  TextColumn get fileName => text()();
  IntColumn get schemaVersion => integer()();
  TextColumn get appVersion => text()();
  IntColumn get sizeBytes => integer()();
}
