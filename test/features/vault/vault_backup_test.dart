import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/core/crypto/aead.dart';
import 'package:life_manager/core/crypto/kdf.dart';
import 'package:life_manager/core/db/app_database.dart';
import 'package:life_manager/core/db/seed.dart';
import 'package:life_manager/core/logging/app_logger.dart';
import 'package:life_manager/core/security/sensitive.dart';
import 'package:life_manager/core/storage/secure_store.dart';
import 'package:life_manager/features/backup/backup_format.dart';
import 'package:life_manager/features/backup/backup_payload.dart';
import 'package:life_manager/features/backup/backup_service.dart';
import 'package:life_manager/features/backup/db_snapshot.dart';
import 'package:life_manager/features/settings/settings_repository.dart';
import 'package:life_manager/features/vault/crypto/field_cipher.dart';
import 'package:life_manager/features/vault/crypto/key_wrap.dart';
import 'package:life_manager/features/vault/crypto/recovery_key.dart';
import 'package:life_manager/features/vault/crypto/vault_errors.dart';
import 'package:life_manager/features/vault/data/unlock_throttle.dart';
import 'package:life_manager/features/vault/data/vault_items_repository.dart';
import 'package:life_manager/features/vault/data/vault_key_service.dart';
import 'package:life_manager/features/vault/domain/notes_parser.dart';
import 'package:life_manager/features/vault/domain/password_generator.dart';
import 'package:life_manager/features/vault/platform/biometric_key_store.dart';

import '../../core/db/generated/schema.dart';
import '../../helpers/fakes.dart';

const _dbKey = Sensitive('00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff');
const _cheap = KdfParams(memoryKiB: 1024, iterations: 1);
const _backupPw = Sensitive('TEST-ONLY-backup-pw');
const _master = 'TEST-ONLY-MASTER-8812';
const _secretPw = 'TEST-ONLY-ITEM-PW-4417';
const _secretNote = 'TEST-ONLY-ITEM-NOTE-4417';
const _secretCodes = 'TEST-ONLY-CODES-4417';
const _bio = BioPromptText(title: 't', subtitle: 's', cancel: 'c');
const _names = SeedNames(
  personal: 'Personal',
  buzzify: 'Buzzify',
  eo: 'EO',
  otherProjects: 'Other',
  cashIqd: 'Cash IQD',
  cashUsd: 'Cash USD',
);

/// True when [bytes] holds [marker] as UTF-8 or UTF-16LE.
bool _holds(List<int> bytes, String marker) {
  final hay = latin1.decode(bytes, allowInvalid: true);
  final utf16 = String.fromCharCodes([
    for (final c in marker.codeUnits) ...[c & 0xff, c >> 8],
  ]);
  return hay.contains(latin1.decode(utf8.encode(marker))) || hay.contains(utf16);
}

void main() {
  late Directory dir;
  late AppDatabase db;
  late InMemorySecureStore store;
  late FakeBiometricKeyStore keystore;
  late List<String> logs;

  VaultKeyService keys(AppDatabase db) => VaultKeyService(
    db: db,
    wrapper: KeyWrapper(FakeKdf(), const AesGcmAead()),
    throttle: UnlockThrottle(store),
    kdf: FakeKdf(),
    bioWraps: SecureBioWrapStore(store),
    keystore: keystore,
  );

  VaultItemsRepository items(AppDatabase db) => VaultItemsRepository(db, FieldCipher(const AesGcmAead()));

  BackupService backup(AppDatabase db) => BackupService(
    db: db,
    supportDir: dir,
    codec: BackupCodec(const DartArgon2idKdf(), const AesGcmAead()),
    snapshotter: SqlCipherSnapshotter(Directory('${dir.path}/snap')),
    dbKey: _dbKey,
    settings: SettingsRepository(db),
    appVersion: '1.2.0',
    afterRestore: () => forgetVaultDeviceKeys(SecureBioWrapStore(store), keystore),
  );

  Future<void> restoreInto(Uint8List file) async {
    await backup(db).restore(file, _backupPw);
    await BackupService.recoverInterruptedRestore(dir, _dbKey);
    db = await openAppDatabase(file: appDatabaseFile(dir), hexKey: _dbKey);
  }

  /// Sets up a vault with one item and fingerprint unlock; returns the recovery key display.
  Future<String> vaultWithItem() async {
    final service = keys(db);
    final pending = await service.prepareSetUp(const Sensitive(_master), params: kDefaultKdfParams);
    final recovery = pending.recoveryKey.display;
    await service.commitSetUp(pending);
    await items(db).create(
      pending.vaultKey,
      VaultItemInput(
        title: 'Hostinger',
        username: 'owner',
        category: 'hosting',
        password: const Sensitive(_secretPw),
        notes: const Sensitive(_secretNote),
        recoveryCodes: const Sensitive(_secretCodes),
      ),
    );
    await service.enableBiometric(pending.vaultKey, _bio);
    pending.discard();
    return recovery;
  }

  setUp(() async {
    store = InMemorySecureStore();
    keystore = FakeBiometricKeyStore();
    logs = [];
    AppLogger.sink = logs.add;
    dir = await Directory.systemTemp.createTemp('vault_backup');
    db = await openAppDatabase(file: appDatabaseFile(dir), hexKey: _dbKey);
    await seedInitialData(db, _names);
  });

  tearDown(() async {
    try {
      await db.close();
    } catch (_) {}
    await dir.delete(recursive: true);
  });

  test('the vault survives backup and restore; fingerprint unlock is reset', () async {
    final recovery = await vaultWithItem();
    expect(await keys(db).biometricEnabled(), isTrue);
    final file = await backup(db).createBackup(_backupPw, kdf: _cheap);
    await restoreInto(file);

    final service = keys(db);
    expect(await service.isSetUp(), isTrue);
    expect(await service.biometricEnabled(), isFalse);
    expect(keystore.deletes, greaterThan(0));
    await expectLater(service.unlockWithBiometric(_bio), throwsA(isA<VaultBiometricInvalidated>()));

    final byRecovery = await service.unlockWithRecovery(recovery);
    byRecovery.destroy();
    final k = await service.unlockWithPassword(const Sensitive(_master));
    final item = (await db.select(db.vaultItems).get()).single;
    final s = await items(db).secrets(k, item.id);
    expect((s.password!.value, s.notes!.value, s.recoveryCodes!.value), (_secretPw, _secretNote, _secretCodes));
    k.destroy();
  });

  test('the backup file and its plaintext database hold no vault secret', () async {
    final recovery = await vaultWithItem();
    final file = await backup(db).createBackup(_backupPw, kdf: _cheap);
    final (_, payload) = await BackupCodec(const DartArgon2idKdf(), const AesGcmAead()).decode(file, _backupPw);
    final snapshot = readPayload(payload)['db/app.db']!;
    // The plain snapshot is a real database: the plain title is there, so the search for markers is meaningful.
    expect(_holds(snapshot, 'Hostinger'), isTrue);
    for (final marker in [_secretPw, _secretNote, _secretCodes, _master, recovery, recovery.replaceAll('-', '')]) {
      expect(_holds(file, marker), isFalse, reason: 'backup file: $marker');
      expect(_holds(snapshot, marker), isFalse, reason: 'snapshot: $marker');
    }
  });

  test('restoring a v2 backup gives an empty vault on schema 3', () async {
    final schema = await SchemaVerifier(GeneratedHelper()).schemaAt(2);
    final raw = schema.rawDatabase;
    raw.execute(
      'INSERT INTO workspaces (name, icon_key, color_argb, sort_order, is_archived, created_at) '
      "VALUES ('Personal', 'person', 0, 0, 0, 1761177600)",
    );
    raw.execute("INSERT INTO app_settings (id, locale_code, setup_completed) VALUES (1, 'ar', 1)");
    final v2 = File('${dir.path}/v2_plain.db');
    raw.execute('VACUUM INTO ?', [v2.path]);
    await schema.newConnection().close();
    final file = await BackupCodec(const DartArgon2idKdf(), const AesGcmAead()).encode(
      payload: buildPayload({'db/app.db': v2.readAsBytesSync()}),
      password: _backupPw,
      schemaVersion: 2,
      appVersion: '1.1.0',
      kdf: _cheap,
    );

    await restoreInto(file);
    expect(db.schemaVersion, 3);
    expect(await keys(db).isSetUp(), isFalse);
    expect(await db.select(db.vaultItems).get(), isEmpty);
    expect((await db.select(db.appSettingsTable).getSingle()).vaultAutoLockSeconds, 120);
  });

  test('a failing after-restore step is logged by type and the restore still completes', () async {
    final file = await backup(db).createBackup(_backupPw, kdf: _cheap);
    final failing = BackupService(
      db: db,
      supportDir: dir,
      codec: BackupCodec(const DartArgon2idKdf(), const AesGcmAead()),
      snapshotter: SqlCipherSnapshotter(Directory('${dir.path}/snap')),
      dbKey: _dbKey,
      settings: SettingsRepository(db),
      appVersion: '1.2.0',
      afterRestore: () async => throw StateError(_master),
    );
    await failing.restore(file, _backupPw);
    expect(logs.single, contains('StateError'));
    expect(logs.join(), isNot(contains(_master)));
    await BackupService.recoverInterruptedRestore(dir, _dbKey);
    db = await openAppDatabase(file: appDatabaseFile(dir), hexKey: _dbKey);
  });

  test('no vault secret reaches the log across the whole vault lifecycle', () async {
    final recovery = await vaultWithItem();
    final service = keys(db);
    for (final wrong in ['TEST-ONLY-WRONG-1', _secretPw]) {
      await expectLater(service.unlockWithPassword(Sensitive(wrong)), throwsA(isA<VaultUnlockError>()));
    }
    await expectLater(service.unlockWithRecovery('TEST-ONLY-NOT-A-KEY'), throwsA(isA<VaultUnlockError>()));
    final k = await service.unlockWithRecovery(recovery);
    final repo = items(db);
    final id = await repo.create(
      k,
      VaultItemInput(title: 'Second', category: 'other', password: const Sensitive(_secretPw)),
    );
    await repo.update(
      k,
      id,
      VaultItemInput(title: 'Second', category: 'other', password: const Sensitive('$_secretPw-2')),
    );
    await repo.secrets(k, id);
    await service.changeMasterPassword(k, const Sensitive('$_master-next'));
    final next = RecoveryKey.generate();
    final nextDisplay = next.display;
    await service.replaceRecoveryKey(k, next);
    keystore.failNext = const VaultBiometricInvalidated();
    await expectLater(service.unlockWithBiometric(_bio), throwsA(isA<VaultBiometricInvalidated>()));
    parseNotes('Site\nuser: x\npass: $_secretPw');
    final generated = generatePassword(const GeneratorOptions()).value;
    final file = await backup(db).createBackup(_backupPw, kdf: _cheap);
    k.destroy();
    await restoreInto(file);

    final all = logs.join('\n');
    for (final marker in [_secretPw, _secretNote, _secretCodes, _master, recovery, nextDisplay, generated]) {
      expect(all, isNot(contains(marker)), reason: marker);
    }
  });
}
