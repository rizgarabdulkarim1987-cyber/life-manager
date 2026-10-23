import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/core/db/app_database.dart';
import 'package:life_manager/core/security/sensitive.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  AccountsCompanion account(int workspaceId) => AccountsCompanion.insert(
    workspaceId: workspaceId,
    name: 'x',
    kind: 'cash',
    currencyCode: 'IQD',
    sortOrder: 0,
    createdAt: DateTime.utc(2026),
  );

  test('settings row exists with defaults', () async {
    final s = await db.select(db.appSettingsTable).getSingle();
    expect(s.localeCode, 'ar');
    expect(s.themeMode, 'light');
    expect(s.lockTimeoutSeconds, 60);
    expect(s.biometricEnabled, false);
    expect(s.baseCurrency, 'IQD');
    expect(s.setupCompleted, false);
    expect(s.lastBackupAt, isNull);
  });

  test('foreign keys are enforced', () async {
    expect(() => db.into(db.accounts).insert(account(999)), throwsA(isA<SqliteException>()));
  });

  test('cannot delete a workspace that has accounts', () async {
    final ws = await db
        .into(db.workspaces)
        .insert(
          WorkspacesCompanion.insert(
            name: 'W',
            iconKey: 'person',
            colorArgb: 0xFF3B82FF,
            sortOrder: 0,
            createdAt: DateTime.utc(2026),
          ),
        );
    await db.into(db.accounts).insert(account(ws));
    expect(() => (db.delete(db.workspaces)..where((w) => w.id.equals(ws))).go(), throwsA(isA<SqliteException>()));
  });

  test('account kind is restricted', () async {
    final ws = await db
        .into(db.workspaces)
        .insert(
          WorkspacesCompanion.insert(
            name: 'W',
            iconKey: 'person',
            colorArgb: 0,
            sortOrder: 0,
            createdAt: DateTime.utc(2026),
          ),
        );
    expect(
      () => db.into(db.accounts).insert(account(ws).copyWith(kind: const Value('crypto'))),
      throwsA(isA<SqliteException>()),
    );
  });

  test('only one settings row may exist', () async {
    expect(
      () => db.into(db.appSettingsTable).insert(AppSettingsTableCompanion.insert(id: const Value(2))),
      throwsA(isA<SqliteException>()),
    );
  });

  test('encrypted file database round-trips and rejects a wrong key', () async {
    final dir = await Directory.systemTemp.createTemp('lm_db');
    final file = appDatabaseFile(dir);
    const key = Sensitive('00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff');
    final a = await openAppDatabase(file: file, hexKey: key);
    await a
        .into(a.workspaces)
        .insert(
          WorkspacesCompanion.insert(
            name: 'Secret workspace name',
            iconKey: 'person',
            colorArgb: 0,
            sortOrder: 0,
            createdAt: DateTime.utc(2026),
          ),
        );
    await a.close();

    final header = file.readAsBytesSync().sublist(0, 16);
    expect(String.fromCharCodes(header), isNot(startsWith('SQLite format 3')));
    expect(String.fromCharCodes(file.readAsBytesSync()), isNot(contains('Secret workspace name')));

    final b = await openAppDatabase(file: file, hexKey: key);
    expect(await b.select(b.workspaces).get(), hasLength(1));
    await b.close();

    const wrong = Sensitive('ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff');
    final c = await openAppDatabase(file: file, hexKey: wrong);
    await expectLater(c.select(c.workspaces).get(), throwsA(anything));
    await c.close();
    await dir.delete(recursive: true);
  });
}
