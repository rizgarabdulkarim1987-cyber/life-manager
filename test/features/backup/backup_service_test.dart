import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/core/crypto/aead.dart';
import 'package:life_manager/core/crypto/kdf.dart';
import 'package:life_manager/core/db/app_database.dart';
import 'package:life_manager/core/db/seed.dart';
import 'package:life_manager/core/security/sensitive.dart';
import 'package:life_manager/core/storage/secure_store.dart';
import 'package:life_manager/features/backup/backup_format.dart';
import 'package:life_manager/features/backup/backup_payload.dart';
import 'package:life_manager/features/capture/ai/ai_config.dart';
import 'package:life_manager/features/finance/data/transactions_repository.dart';
import 'package:life_manager/features/backup/backup_service.dart';
import 'package:life_manager/features/backup/db_snapshot.dart';
import 'package:life_manager/features/settings/settings_repository.dart';

import '../../core/db/generated/schema.dart';

const _key = Sensitive('00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff');
const _cheap = KdfParams(memoryKiB: 1024, iterations: 1);
const _pw = Sensitive('backup-password');
const _names = SeedNames(
  personal: 'ZebraPersonalWorkspace',
  buzzify: 'Buzzify',
  eo: 'EO',
  otherProjects: 'Other',
  cashIqd: 'Cash IQD',
  cashUsd: 'Cash USD',
);

void main() {
  late Directory dir;
  late AppDatabase db;
  late RestorePaths paths;

  late InMemorySecureStore secrets;

  BackupService service(AppDatabase db) => BackupService(
    db: db,
    groqKey: GroqKeyStore(secrets),
    supportDir: dir,
    codec: BackupCodec(const DartArgon2idKdf(), const AesGcmAead()),
    snapshotter: SqlCipherSnapshotter(Directory('${dir.path}/snap')),
    dbKey: _key,
    settings: SettingsRepository(db),
    appVersion: '1.0.0',
  );

  setUp(() async {
    secrets = InMemorySecureStore();
    dir = await Directory.systemTemp.createTemp('backup');
    paths = RestorePaths(dir);
    db = await openAppDatabase(file: appDatabaseFile(dir), hexKey: _key);
    await seedInitialData(db, _names);
  });

  tearDown(() async {
    try {
      await db.close();
    } catch (_) {}
    await dir.delete(recursive: true);
  });

  String hashOf(File f) => sha256.convert(f.readAsBytesSync()).toString();

  test('backup then restore brings data back', () async {
    final file = await service(db).createBackup(_pw, kdf: _cheap);
    await db.delete(db.accounts).go();
    expect(await db.select(db.accounts).get(), isEmpty);

    await service(db).restore(file, _pw);
    expect(paths.marker.existsSync(), isTrue);
    expect(paths.preRestore.existsSync(), isTrue);
    expect(paths.tmp.existsSync(), isFalse);

    await BackupService.recoverInterruptedRestore(dir, _key);
    expect(paths.marker.existsSync(), isFalse);
    expect(paths.preRestore.existsSync(), isFalse);

    db = await openAppDatabase(file: appDatabaseFile(dir), hexKey: _key);
    expect(await db.select(db.accounts).get(), hasLength(6));
    final kinds = (await db.select(db.backupMetadata).get()).map((m) => m.kind);
    expect(kinds, contains('restore'));
  });

  test('restore leaves live db untouched on wrong password', () async {
    final file = await service(db).createBackup(_pw, kdf: _cheap);
    final before = hashOf(paths.db);
    await expectLater(service(db).restore(file, const Sensitive('nope')), throwsA(isA<BackupWrongPasswordException>()));
    expect(hashOf(paths.db), before);
    expect(paths.marker.existsSync(), isFalse);
    expect(await db.select(db.accounts).get(), hasLength(6));
  });

  test('rejects newer schema and keeps live data', () async {
    await db.customStatement('PRAGMA user_version = 99');
    final file = await service(db).createBackup(_pw, kdf: _cheap);
    await db.customStatement('PRAGMA user_version = 1');
    await expectLater(service(db).restore(file, _pw), throwsA(isA<BackupTooNewException>()));
    expect(paths.marker.existsSync(), isFalse);
    expect(paths.incoming.existsSync(), isFalse);
    expect(paths.tmp.existsSync(), isFalse);
    expect(await db.select(db.accounts).get(), hasLength(6));
  });

  test('recoverInterruptedRestore rolls back when new db is missing', () async {
    await db.close();
    final old = hashOf(paths.db);
    paths.db.renameSync(paths.preRestore.path);
    paths.marker.writeAsStringSync('1');

    await BackupService.recoverInterruptedRestore(dir, _key);
    expect(hashOf(paths.db), old);
    expect(paths.marker.existsSync(), isFalse);
    expect(paths.preRestore.existsSync(), isFalse);
  });

  test('recoverInterruptedRestore rolls back when new db is damaged', () async {
    await db.close();
    final old = hashOf(paths.db);
    paths.db.renameSync(paths.preRestore.path);
    paths.db.writeAsBytesSync(Uint8List.fromList(utf8.encode('garbage' * 200)));
    paths.marker.writeAsStringSync('1');

    await BackupService.recoverInterruptedRestore(dir, _key);
    expect(hashOf(paths.db), old);
  });

  test('recoverInterruptedRestore commits when new db is healthy', () async {
    await db.close();
    paths.db.copySync(paths.preRestore.path);
    paths.marker.writeAsStringSync('1');

    await BackupService.recoverInterruptedRestore(dir, _key);
    expect(paths.preRestore.existsSync(), isFalse);
    expect(paths.marker.existsSync(), isFalse);
    expect(paths.db.existsSync(), isTrue);
  });

  test('recoverInterruptedRestore restores the old db when killed mid-swap without a marker', () async {
    await db.close();
    final old = hashOf(paths.db);
    paths.db.renameSync(paths.preRestore.path);
    paths.incoming.writeAsStringSync('half-written');

    await BackupService.recoverInterruptedRestore(dir, _key);
    expect(hashOf(paths.db), old);
    expect(paths.preRestore.existsSync(), isFalse);
    expect(paths.incoming.existsSync(), isFalse);
  });

  test('recoverInterruptedRestore deletes a plaintext export left by a killed backup', () async {
    paths.snapshotTmp.createSync(recursive: true);
    File('${paths.snapshotTmp.path}/export-1.db').writeAsStringSync('plain');
    await BackupService.recoverInterruptedRestore(dir, _key);
    expect(paths.snapshotTmp.existsSync(), isFalse);
  });

  test('restore that fails during the swap puts the old db back', () async {
    final file = await service(db).createBackup(_pw, kdf: _cheap);
    final before = hashOf(paths.db);
    // A directory where the incoming file must go makes the final rename fail.
    final svc = service(db);
    paths.incoming.parent.createSync(recursive: true);
    await expectLater(
      svc.restore(file, _pw, beforeSwap: () => Directory(paths.preRestore.path).createSync()),
      throwsA(anything),
    );
    expect(svc.databaseClosed, isTrue);
    expect(hashOf(paths.db), before);
    expect(paths.marker.existsSync(), isFalse);
  });

  test('recoverInterruptedRestore removes orphan incoming', () async {
    paths.incoming.writeAsStringSync('half-written');
    await BackupService.recoverInterruptedRestore(dir, _key);
    expect(paths.incoming.existsSync(), isFalse);
    expect(paths.db.existsSync(), isTrue);
  });

  test('createBackup alone records nothing (the save may be cancelled)', () async {
    await service(db).createBackup(_pw, kdf: _cheap);
    expect(await db.select(db.backupMetadata).get(), isEmpty);
    expect((await SettingsRepository(db).get()).lastBackupAt, isNull);
  });

  test('recordExport records metadata and lastBackupAt', () async {
    final at = DateTime.utc(2026, 10, 22, 9);
    final file = await service(db).createBackup(_pw, kdf: _cheap, now: at);
    await service(db).recordExport(file);
    final rows = await db.select(db.backupMetadata).get();
    expect(rows, hasLength(1));
    expect(rows.single.kind, 'export');
    expect(rows.single.sizeBytes, file.length);
    expect((await SettingsRepository(db).get()).lastBackupAt!.isAtSameMomentAs(at), isTrue);
    expect(service(db).inspect(file).createdAtUtc, at);
  });

  test('backup bytes do not contain the db plaintext', () async {
    final file = await service(db).createBackup(_pw, kdf: _cheap);
    expect(latin1.decode(file).contains('ZebraPersonalWorkspace'), isFalse);
    expect(Directory('${dir.path}/snap').listSync(), isEmpty);
  });

  test('groq key round-trips inside the encrypted body', () async {
    const secret = 'gsk_TEST_ONLY_0000';
    final keys = GroqKeyStore(secrets);
    await keys.write(const Sensitive(secret));
    final file = await service(db).createBackup(_pw, kdf: _cheap);
    expect(utf8.decode(file, allowMalformed: true), isNot(contains(secret)));
    expect(String.fromCharCodes(file), isNot(contains(secret)));

    await keys.clear();
    expect(await keys.read(), isNull);
    await service(db).restore(file, _pw);
    expect((await keys.read())?.value, secret);
  });

  test('restoring a backup without a key clears the stored key; no key means no entry', () async {
    final keys = GroqKeyStore(secrets);
    final file = await service(db).createBackup(_pw, kdf: _cheap);
    await keys.write(const Sensitive('gsk_other_key'));
    await service(db).restore(file, _pw);
    expect(await keys.read(), isNull);
  });

  test('a failed restore leaves the stored key alone', () async {
    final keys = GroqKeyStore(secrets);
    await keys.write(const Sensitive('gsk_kept'));
    final file = await service(db).createBackup(_pw, kdf: _cheap);
    await expectLater(service(db).restore(file, const Sensitive('nope')), throwsA(isA<BackupWrongPasswordException>()));
    expect((await keys.read())?.value, 'gsk_kept');
  });

  test('backup bytes contain no transaction description plaintext', () async {
    final cash = (await db.select(db.accounts).get()).first;
    await TransactionsRepository(db).addSimple(
      type: 'expense',
      accountId: cash.id,
      amountMinor: 1000,
      occurredAt: DateTime.now().toUtc(),
      description: 'SECRET-DESC-7731',
    );
    final file = await service(db).createBackup(_pw, kdf: _cheap);
    expect(String.fromCharCodes(file), isNot(contains('SECRET-DESC-7731')));
  });

  test('restores a v1 backup and migrates', () async {
    final verifier = SchemaVerifier(GeneratedHelper());
    final schema = await verifier.schemaAt(1);
    final raw = schema.rawDatabase;
    const created = 1761177600;
    final names = ['Personal', 'Buzzify', 'EO', 'Other'];
    for (var i = 0; i < 4; i++) {
      raw.execute(
        'INSERT INTO workspaces (name, icon_key, color_argb, sort_order, is_archived, created_at) VALUES (?, ?, 0, ?, 0, ?)',
        [names[i], 'folder', i, created],
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
      'INSERT INTO app_settings (id, locale_code, theme_mode, lock_timeout_seconds, biometric_enabled, base_currency, setup_completed) '
      "VALUES (1, 'ckb', 'light', 60, 1, 'IQD', 1)",
    );
    final v1 = File('${dir.path}/v1_plain.db');
    raw.execute('VACUUM INTO ?', [v1.path]);
    await schema.newConnection().close();

    final file = await BackupCodec(const DartArgon2idKdf(), const AesGcmAead()).encode(
      payload: buildPayload({'db/app.db': v1.readAsBytesSync()}),
      password: _pw,
      schemaVersion: 1,
      appVersion: '1.0.0',
      kdf: _cheap,
    );

    await service(db).restore(file, _pw);
    await BackupService.recoverInterruptedRestore(dir, _key);
    db = await openAppDatabase(file: appDatabaseFile(dir), hexKey: _key);
    expect(db.schemaVersion, 2);
    expect(await db.select(db.workspaces).get(), hasLength(4));
    expect(await db.select(db.accounts).get(), hasLength(6));
    expect(await db.select(db.categories).get(), hasLength(16));
    final st = await db.select(db.appSettingsTable).getSingle();
    expect((st.localeCode, st.themeMode, st.lockTimeoutSeconds), ('ckb', 'light', 60));
  });
}
