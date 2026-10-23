import 'dart:io';
import 'dart:ui' show Locale;

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;

import '../../features/finance/data/categories_repository.dart' show systemLabel;
import '../../l10n/gen/app_localizations.dart';
import '../security/sensitive.dart';
import 'capture_tables.dart';
import 'finance_seed.dart';
import 'finance_tables.dart';
import 'life_tables.dart';
import 'project_tables.dart';
import 'tables.dart';

export 'capture_tables.dart';
export 'finance_tables.dart';
export 'life_tables.dart';
export 'project_tables.dart';
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
    Tasks,
    Notes,
    Projects,
    ProjectSteps,
    ProjectMessages,
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
      await seedBuckets(this);
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

  /// A v1 database gets the v2 tables in their current shape, so a column added
  /// to them later may already be there.
  Future<void> _addColumnOnce(Migrator m, TableInfo table, GeneratedColumn column) async {
    final cols = await customSelect('PRAGMA table_info("${table.actualTableName}")').get();
    if (cols.any((r) => r.read<String>('name') == column.name)) return;
    await m.addColumn(table, column);
  }

  Future<void> _createOnce(Migrator m, TableInfo table) async {
    final found = await customSelect(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
      variables: [Variable<String>(table.actualTableName)],
    ).get();
    if (found.isEmpty) await m.createTable(table);
  }

  /// Redesign (spec 2026-10-23): light and minimal by default, relock after a minute.
  Future<void> _toV3(Migrator m) async {
    // Rebuilt so the column defaults change too.
    await m.alterTable(
      TableMigration(
        appSettingsTable,
        newColumns: [appSettingsTable.groqVisionModel, appSettingsTable.aiReceiptConsent],
      ),
    );
    await _addColumnOnce(m, captures, captures.undoJson);
    await _addColumnOnce(m, captures, captures.image);
    // The source check now allows 'image'.
    await m.alterTable(TableMigration(captures));
    await _createOnce(m, tasks);
    await _createOnce(m, notes);
    await _createOnce(m, projects);
    await _createOnce(m, projectSteps);
    await _createOnce(m, projectMessages);
    await customStatement("UPDATE app_settings SET theme_mode = 'light' WHERE theme_mode = 'dark'");
    await customStatement('UPDATE app_settings SET lock_timeout_seconds = 60 WHERE lock_timeout_seconds = 300');
    await _dropUnusedSeeds();
    await seedBuckets(this);
  }

  /// Redesign §11.1: the owner makes their own categories and accounts. Seeded
  /// rows nothing points at go; seeded categories still in use keep their
  /// shown name and default keywords and stop being system rows.
  Future<void> _dropUnusedSeeds() async {
    const used =
        'id IN (SELECT category_id FROM transactions WHERE category_id IS NOT NULL) '
        'OR id IN (SELECT category_id FROM budgets WHERE category_id IS NOT NULL)';
    await customStatement('DELETE FROM categories WHERE system_key IS NOT NULL AND NOT ($used)');
    final settings = await customSelect('SELECT locale_code FROM app_settings WHERE id = 1').getSingleOrNull();
    final l = lookupAppLocalizations(Locale(settings?.read<String>('locale_code') ?? 'ar'));
    for (final c in await customSelect('SELECT id, system_key FROM categories WHERE system_key IS NOT NULL').get()) {
      final key = c.read<String>('system_key');
      await customStatement(
        "UPDATE categories SET name = COALESCE(name, ?), extra_keywords = ?, system_key = NULL WHERE id = ?",
        [systemLabel(key, l) ?? key, (kDefaultCategoryKeywords[key] ?? const []).join(','), c.read<int>('id')],
      );
    }
    // Seeded cash accounts are named «<workspace> · <label>» with no opening balance.
    await customStatement(
      "DELETE FROM accounts WHERE kind = 'cash' AND opening_balance_minor = 0 AND name LIKE '% · %' "
      'AND id NOT IN (SELECT account_id FROM transactions) '
      'AND id NOT IN (SELECT to_account_id FROM transactions WHERE to_account_id IS NOT NULL) '
      'AND id <> (SELECT MIN(id) FROM accounts)',
    );
    await customStatement(
      "DELETE FROM workspaces WHERE icon_key IN ('campaign', 'handshake', 'folder') "
      'AND sort_order > (SELECT MIN(sort_order) FROM workspaces) '
      'AND id NOT IN (SELECT workspace_id FROM accounts) '
      'AND id NOT IN (SELECT workspace_id FROM transactions) '
      'AND id NOT IN (SELECT workspace_id FROM debts) '
      'AND id NOT IN (SELECT workspace_id FROM budgets WHERE workspace_id IS NOT NULL) '
      'AND id NOT IN (SELECT workspace_id FROM categories WHERE workspace_id IS NOT NULL)',
    );
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
