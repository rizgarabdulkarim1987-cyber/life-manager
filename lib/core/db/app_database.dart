import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;

import '../security/sensitive.dart';
import 'capture_tables.dart';
import 'finance_seed.dart';
import 'finance_tables.dart';
import 'tables.dart';

export 'capture_tables.dart';
export 'finance_tables.dart';
export 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Workspaces,
    Accounts,
    AppSettingsTable,
    BackupMetadata,
    Categories,
    ExchangeRates,
    ImportBatches,
    Debts,
    Installments,
    Transactions,
    Buckets,
    BucketAllocations,
    Budgets,
    Captures,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await seedFinanceDefaults(this);
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.addColumn(workspaces, workspaces.aliases);
        await m.addColumn(workspaces, workspaces.countsInBuckets);
        for (final c in <GeneratedColumn>[
          appSettingsTable.aiOnlineEnabled,
          appSettingsTable.aiVoiceConsent,
          appSettingsTable.aiParseConsent,
          appSettingsTable.groqSttModel,
          appSettingsTable.groqLlmModel,
          appSettingsTable.localWhisperModel,
          appSettingsTable.unallocatedIncomeAlert,
          appSettingsTable.bucketsConfirmed,
        ]) {
          await m.addColumn(appSettingsTable, c);
        }
        for (final t in <TableInfo>[
          categories,
          exchangeRates,
          importBatches,
          debts,
          installments,
          transactions,
          buckets,
          bucketAllocations,
          budgets,
          captures,
        ]) {
          await m.createTable(t);
        }
        for (final i in [txAccountTime, txTime, txBatch]) {
          await m.createIndex(i);
        }
        await seedFinanceDefaults(this);
        await markPersonalCountsInBuckets(this);
      }
      if (from < 3) await _toV3(m);
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
      await into(appSettingsTable)
          .insert(const AppSettingsTableCompanion(id: Value(1)), mode: InsertMode.insertOrIgnore);
    },
  );

  /// Redesign (spec 2026-10-23): light and minimal by default, relock after a minute.
  Future<void> _toV3(Migrator m) async {
    // Rebuilt so the column defaults change too.
    await m.alterTable(TableMigration(appSettingsTable));
    await customStatement("UPDATE app_settings SET theme_mode = 'light' WHERE theme_mode = 'dark'");
    await customStatement('UPDATE app_settings SET lock_timeout_seconds = 60 WHERE lock_timeout_seconds = 300');
  }
}

File appDatabaseFile(Directory supportDir) => File(p.join(supportDir.path, 'app.db'));

final _hexKey = RegExp(r'^[0-9a-f]{64}$');

/// Opens the SQLCipher database. The key is raw hex, so SQLCipher skips its
/// own KDF; [hexKey] comes from [obtainDatabaseKey].
Future<AppDatabase> openAppDatabase({required File file, required Sensitive<String> hexKey}) async {
  final key = hexKey.value;
  if (!_hexKey.hasMatch(key)) throw ArgumentError('database key must be 64 lowercase hex chars');
  return AppDatabase(
    NativeDatabase.createInBackground(
      file,
      setup: (raw) {
        final cipher = raw.select('PRAGMA cipher_version');
        if (cipher.isEmpty || '${cipher.first.values.first}'.isEmpty) {
          throw StateError('SQLCipher is not available');
        }
        raw.execute("PRAGMA key = \"x'$key'\"");
      },
    ),
  );
}
