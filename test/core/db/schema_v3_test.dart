import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/core/db/app_database.dart';

void main() {
  late AppDatabase db;
  final now = DateTime.utc(2026, 10, 23);
  final uid = 'a' * 32;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<int> insertItem({String category = 'social', String? itemUid}) => db
      .into(db.vaultItems)
      .insert(
        VaultItemsCompanion.insert(
          uid: itemUid ?? uid,
          title: 'Example',
          category: category,
          createdAt: now,
          updatedAt: now,
        ),
      );

  Future<int> insertWrap(String kind, {String? kdfJson}) => db
      .into(db.vaultKeyWraps)
      .insert(
        VaultKeyWrapsCompanion.insert(
          kind: kind,
          kdfJson: Value(kdfJson),
          salt: Uint8List(16),
          sealedKey: Uint8List(61),
          createdAt: now,
        ),
      );

  test('a fresh database is on schema 3 with empty vault tables', () async {
    expect(db.schemaVersion, 3);
    expect(await db.select(db.vaultItems).get(), isEmpty);
    expect(await db.select(db.vaultKeyWraps).get(), isEmpty);
    expect(await db.select(db.vaultMeta).get(), isEmpty);
  });

  test('every vault category is accepted; an unknown one is rejected', () async {
    for (var i = 0; i < kVaultCategories.length; i++) {
      await insertItem(category: kVaultCategories[i], itemUid: '$i'.padLeft(32, '0'));
    }
    expect(() => insertItem(category: 'games'), throwsA(isA<SqliteException>()));
  });

  test('item uid is unique and exactly 32 characters', () async {
    await insertItem();
    expect(() => insertItem(), throwsA(isA<SqliteException>()));
    expect(() => insertItem(itemUid: 'short'), throwsA(anything));
  });

  test('password wrap needs kdfJson, recovery wrap must not have it', () async {
    expect(() => insertWrap('password'), throwsA(isA<SqliteException>()));
    expect(() => insertWrap('recovery', kdfJson: '{}'), throwsA(isA<SqliteException>()));
    await insertWrap('password', kdfJson: '{"alg":"argon2id","m":65536,"t":3,"p":1}');
    await insertWrap('recovery');
  });

  test('only one wrap per kind, and only the two known kinds', () async {
    await insertWrap('recovery');
    expect(() => insertWrap('recovery'), throwsA(isA<SqliteException>()));
    expect(() => insertWrap('biometric'), throwsA(isA<SqliteException>()));
  });

  test('vault_meta accepts only id 1', () async {
    await db.into(db.vaultMeta).insert(VaultMetaCompanion.insert(vaultId: 'b' * 32, checkBlob: Uint8List(45), createdAt: now));
    expect(
      () => db
          .into(db.vaultMeta)
          .insert(VaultMetaCompanion.insert(id: const Value(2), vaultId: 'c' * 32, checkBlob: Uint8List(45), createdAt: now)),
      throwsA(isA<SqliteException>()),
    );
  });

  test('vaultAutoLockSeconds defaults to 120 and only takes 60/120/300/600', () async {
    await db.into(db.appSettingsTable).insert(const AppSettingsTableCompanion(id: Value(1)), mode: InsertMode.insertOrIgnore);
    expect((await db.select(db.appSettingsTable).getSingle()).vaultAutoLockSeconds, 120);
    expect(
      () => db.update(db.appSettingsTable).write(const AppSettingsTableCompanion(vaultAutoLockSeconds: Value(45))),
      throwsA(isA<SqliteException>()),
    );
    await db.update(db.appSettingsTable).write(const AppSettingsTableCompanion(vaultAutoLockSeconds: Value(600)));
  });

  test('a workspace linked from a vault item cannot be deleted', () async {
    final ws = await db
        .into(db.workspaces)
        .insert(WorkspacesCompanion.insert(name: 'W', iconKey: 'person', colorArgb: 0, sortOrder: 0, createdAt: now));
    await db
        .into(db.vaultItems)
        .insert(
          VaultItemsCompanion.insert(
            uid: uid,
            title: 'T',
            category: 'other',
            workspaceId: Value(ws),
            createdAt: now,
            updatedAt: now,
          ),
        );
    await db.customStatement('PRAGMA foreign_keys = ON');
    expect(() => (db.delete(db.workspaces)..where((w) => w.id.equals(ws))).go(), throwsA(isA<SqliteException>()));
  });
}
