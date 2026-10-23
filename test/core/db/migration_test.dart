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

  test('v1 → current keeps workspaces, accounts, settings, backup rows and seeds finance defaults', () async {
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
    await verifier.migrateAndValidate(db, db.schemaVersion);

    final ws = await (db.select(db.workspaces)..orderBy([(w) => OrderingTerm.asc(w.sortOrder)])).get();
    // v3 drops seeded workspaces nobody used; v1 account names have no « · », so they look owner-made and stay.
    expect(ws.map((w) => w.name), ['Personal', 'Buzzify', 'EO']);
    expect(ws.first.countsInBuckets, isTrue);
    expect(ws.every((w) => w.aliases == ''), isTrue);
    expect(await db.select(db.accounts).get(), hasLength(6));
    final s = await db.select(db.appSettingsTable).getSingle();
    expect(
      (s.localeCode, s.themeMode, s.lockTimeoutSeconds, s.biometricEnabled, s.setupCompleted),
      ('ckb', 'light', 60, true, true),
    );
    expect(s.groqSttModel, 'whisper-large-v3-turbo');
    expect(await db.select(db.backupMetadata).get(), hasLength(1));
    expect(await db.select(db.categories).get(), isEmpty, reason: 'unused seeded categories go in the redesign step');
    expect(await db.select(db.buckets).get(), hasLength(3));
    await db.close();
  });

  test('v2 → current switches to the light theme and the 60 s relock once', () async {
    final schema = await verifier.schemaAt(2);
    schema.rawDatabase.execute(
      "INSERT INTO app_settings (id, locale_code, theme_mode, lock_timeout_seconds, biometric_enabled, base_currency, setup_completed) "
      "VALUES (1, 'ar', 'dark', 300, 1, 'IQD', 1)",
    );
    final db = AppDatabase(schema.newConnection());
    await verifier.migrateAndValidate(db, db.schemaVersion);
    final s = await db.select(db.appSettingsTable).getSingle();
    expect((s.themeMode, s.lockTimeoutSeconds), ('light', 60));
    await db.close();
  });

  test('a fresh database defaults to light and 60 s', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final s = await db.select(db.appSettingsTable).getSingle();
    expect((s.themeMode, s.lockTimeoutSeconds), ('light', 60));
    await db.close();
  });

  test('v2 → current keeps used seeded rows (named) and removes the unused ones', () async {
    final schema = await verifier.schemaAt(2);
    final raw = schema.rawDatabase;
    const at = 1761177600;
    raw.execute(
      "INSERT INTO app_settings (id, locale_code, theme_mode, lock_timeout_seconds, biometric_enabled, base_currency, setup_completed) "
      "VALUES (1, 'en', 'light', 60, 1, 'IQD', 1)",
    );
    for (final (i, name, icon) in [(0, 'Personal', 'person'), (1, 'Buzzify', 'campaign'), (2, 'EO', 'handshake')]) {
      raw.execute(
        'INSERT INTO workspaces (name, icon_key, color_argb, sort_order, is_archived, created_at, aliases, counts_in_buckets) '
        "VALUES (?, ?, 0, ?, 0, ?, '', ?)",
        [name, icon, i, at, i == 0 ? 1 : 0],
      );
    }
    void account(int ws, String name, String currency) => raw.execute(
      'INSERT INTO accounts (workspace_id, name, kind, currency_code, opening_balance_minor, sort_order, is_archived, created_at) '
      "VALUES (?, ?, 'cash', ?, 0, 0, 0, ?)",
      [ws, name, currency, at],
    );
    account(1, 'Personal · Cash IQD', 'IQD'); // 1, used
    account(1, 'Personal · Cash USD', 'USD'); // 2, empty seed
    account(2, 'Buzzify · Cash IQD', 'IQD'); // 3, empty seed
    account(1, 'My bank', 'IQD'); // 4, empty but owner-made
    for (final (i, key, kind) in [(0, 'food', 'expense'), (1, 'transport', 'expense'), (2, 'salary', 'income')]) {
      raw.execute(
        'INSERT INTO categories (kind, system_key, icon_key, color_argb, sort_order) VALUES (?, ?, ?, 0, ?)',
        [kind, key, 'tag', i],
      );
    }
    raw.execute(
      'INSERT INTO transactions (type, account_id, workspace_id, amount_minor, currency_code, category_id, occurred_at, created_at, updated_at) '
      "VALUES ('expense', 1, 1, 5000, 'IQD', 1, ?, ?, ?)",
      [at, at, at],
    );

    final db = AppDatabase(schema.newConnection());
    await verifier.migrateAndValidate(db, db.schemaVersion);
    expect((await db.select(db.accounts).get()).map((a) => a.name).toSet(), {'Personal · Cash IQD', 'My bank'});
    expect((await db.select(db.workspaces).get()).map((w) => w.name), ['Personal']);
    final cats = await db.select(db.categories).get();
    expect(cats.map((c) => (c.name, c.systemKey)), [('Food', null)]);
    expect(cats.single.extraKeywords, contains('food'), reason: 'its default keywords stay with it');
    expect(await db.select(db.buckets).get(), hasLength(3));
    await db.close();
  });

  test('v2 → current never removes every account, even when all of them are unused seeds', () async {
    final schema = await verifier.schemaAt(2);
    final raw = schema.rawDatabase;
    const at = 1761177600;
    raw.execute(
      "INSERT INTO app_settings (id, locale_code, theme_mode, lock_timeout_seconds, biometric_enabled, base_currency, setup_completed) "
      "VALUES (1, 'en', 'light', 60, 1, 'IQD', 1)",
    );
    raw.execute(
      'INSERT INTO workspaces (name, icon_key, color_argb, sort_order, is_archived, created_at, aliases, counts_in_buckets) '
      "VALUES ('Personal', 'person', 0, 0, 0, ?, '', 1)",
      [at],
    );
    for (final (name, cur) in [('Personal · Cash IQD', 'IQD'), ('Personal · Cash USD', 'USD')]) {
      raw.execute(
        'INSERT INTO accounts (workspace_id, name, kind, currency_code, opening_balance_minor, sort_order, is_archived, created_at) '
        "VALUES (1, ?, 'cash', ?, 0, 0, 0, ?)",
        [name, cur, at],
      );
    }
    final db = AppDatabase(schema.newConnection());
    await verifier.migrateAndValidate(db, db.schemaVersion);
    expect(
      await db.select(db.accounts).get(),
      hasLength(1),
      reason: 'one account is kept so the app has somewhere to record',
    );
    await db.close();
  });

  void seedVault(dynamic raw, int at) {
    raw.execute(
      "INSERT INTO app_settings (id, locale_code, theme_mode, lock_timeout_seconds, biometric_enabled, base_currency, setup_completed) "
      "VALUES (1, 'ar', 'light', 60, 1, 'IQD', 1)",
    );
    raw.execute("INSERT INTO vault_meta (id, vault_id, check_blob, created_at) VALUES (1, 'v-1', X'0102', ?)", [at]);
    raw.execute(
      "INSERT INTO vault_key_wraps (kind, kdf_json, salt, sealed_key, created_at) VALUES ('password', '{}', X'0A0B', X'0C0D', ?)",
      [at],
    );
    raw.execute(
      "INSERT INTO vault_items (uid, title, username, category, favorite, password_blob, created_at, updated_at) "
      "VALUES ('u-1', 'Netflix', 'me@x.com', 'social', 1, X'AABB', ?, ?)",
      [at, at],
    );
  }

  Future<void> expectVaultKept(AppDatabase db) async {
    final item = await db.select(db.vaultItems).getSingle();
    expect((item.title, item.username, item.category, item.favorite), ('Netflix', 'me@x.com', 'social', true));
    expect(item.passwordBlob, isNotNull);
    expect((await db.select(db.vaultMeta).getSingle()).vaultId, 'v-1');
    expect(await db.select(db.vaultKeyWraps).get(), hasLength(1));
    expect((await db.select(db.appSettingsTable).getSingle()).vaultAutoLockSeconds, 120);
  }

  test('v3 (1.2.0, vault) → current keeps every vault row', () async {
    final schema = await verifier.schemaAt(3);
    seedVault(schema.rawDatabase, 1761177600);
    final db = AppDatabase(schema.newConnection());
    await verifier.migrateAndValidate(db, db.schemaVersion);
    await expectVaultKept(db);
    await db.close();
  });

  test('v4 (1.3.0, vault + old tasks) → current keeps the vault and carries tasks and meeting notes over', () async {
    final schema = await verifier.schemaAt(4);
    final raw = schema.rawDatabase;
    const at = 1761177600;
    seedVault(raw, at);
    raw.execute(
      "INSERT INTO tasks (title, priority, status, due_at, due_all_day, recurrence, tags, created_at, updated_at) "
      "VALUES ('Pay rent', 'high', 'todo', ?, 0, 'monthly', '', ?, ?)",
      [at + 86400, at, at],
    );
    raw.execute(
      "INSERT INTO tasks (title, priority, status, due_all_day, tags, completed_at, created_at, updated_at) "
      "VALUES ('Old thing', 'low', 'done', 1, '', ?, ?, ?)",
      [at, at, at],
    );
    raw.execute("INSERT INTO meeting_notes (title, body, created_at, updated_at) VALUES ('Standup', 'ship it', ?, ?)", [
      at,
      at,
    ]);
    final db = AppDatabase(schema.newConnection());
    await verifier.migrateAndValidate(db, db.schemaVersion);
    await expectVaultKept(db);
    final tasks = await (db.select(db.tasks)..orderBy([(t) => OrderingTerm.asc(t.id)])).get();
    expect(tasks.map((t) => t.title), ['Pay rent', 'Old thing']);
    expect((tasks[0].priority, tasks[0].status, tasks[0].recurrence, tasks[0].hasTime), (2, 'open', 'monthly', true));
    expect((tasks[1].priority, tasks[1].status, tasks[1].recurrence), (0, 'done', 'none'));
    final notes = await db.select(db.notes).get();
    expect(notes.single.body, 'Standup\nship it');
    await db.close();
  });

  test('a fresh database has the vault tables, empty', () async {
    final db = AppDatabase(NativeDatabase.memory());
    expect(await db.select(db.vaultItems).get(), isEmpty);
    await db.close();
  });
}
