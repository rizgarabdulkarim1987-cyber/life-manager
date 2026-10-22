import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift_dev/api/migrations_native.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/core/db/app_database.dart';

import 'generated/schema.dart';

void main() {
  late SchemaVerifier verifier;
  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  test('schema v1 matches drift_schemas/drift_schema_v1.json', () async {
    final connection = await verifier.startAt(1);
    final db = AppDatabase(connection);
    await verifier.migrateAndValidate(db, 1);
    await db.close();
  });

  test('current schemaVersion has a dumped schema', () async {
    final db = AppDatabase(NativeDatabase.memory());
    expect(GeneratedHelper.versions, contains(db.schemaVersion));
    await db.close();
  });

  test('v1 → v2 keeps workspaces, accounts, settings, backup rows and seeds finance defaults', () async {
    final schema = await verifier.schemaAt(1);
    final raw = schema.rawDatabase;
    const created = 1761177600; // drift stores DateTime as unix seconds by default
    final names = ['Personal', 'Buzzify', 'EO', 'Other'];
    final icons = ['person', 'campaign', 'handshake', 'folder'];
    for (var i = 0; i < 4; i++) {
      raw.execute(
        'INSERT INTO workspaces (name, icon_key, color_argb, sort_order, is_archived, created_at) VALUES (?, ?, 0, ?, 0, ?)',
        [names[i], icons[i], i, created],
      );
    }
    for (var ws = 1; ws <= 3; ws++) {
      for (final c in ['IQD', 'USD']) {
        raw.execute(
          'INSERT INTO accounts (workspace_id, name, kind, currency_code, opening_balance_minor, sort_order, is_archived, created_at) '
          "VALUES (?, ?, 'cash', ?, 0, 0, 0, ?)",
          [ws, 'acc $ws $c', c, created],
        );
      }
    }
    raw.execute(
      "INSERT INTO app_settings (id, locale_code, theme_mode, lock_timeout_seconds, biometric_enabled, base_currency, setup_completed) "
      "VALUES (1, 'ckb', 'light', 60, 1, 'IQD', 1)",
    );
    raw.execute(
      "INSERT INTO backup_metadata (created_at, kind, file_name, schema_version, app_version, size_bytes) "
      "VALUES (?, 'export', 'b.plmbackup', 1, '1.0.0', 10)",
      [created],
    );

    final db = AppDatabase(schema.newConnection());
    await verifier.migrateAndValidate(db, 2);

    final ws = await (db.select(db.workspaces)..orderBy([(w) => OrderingTerm.asc(w.sortOrder)])).get();
    expect(ws.map((w) => w.name), names);
    expect(ws.map((w) => w.countsInBuckets), [true, false, false, false]);
    expect(ws.every((w) => w.aliases == ''), isTrue);
    expect(await db.select(db.accounts).get(), hasLength(6));
    final s = await db.select(db.appSettingsTable).getSingle();
    expect(
      (s.localeCode, s.themeMode, s.lockTimeoutSeconds, s.biometricEnabled, s.setupCompleted),
      ('ckb', 'light', 60, true, true),
    );
    expect(s.groqSttModel, 'whisper-large-v3-turbo');
    expect(await db.select(db.backupMetadata).get(), hasLength(1));
    expect(await db.select(db.categories).get(), hasLength(16));
    expect(await db.select(db.buckets).get(), hasLength(3));
    await db.close();
  });
}
