import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/core/crypto/aead.dart';
import 'package:life_manager/core/crypto/kdf.dart';
import 'package:life_manager/core/db/app_database.dart';
import 'package:life_manager/core/db/seed.dart';
import 'package:life_manager/core/security/sensitive.dart';
import 'package:life_manager/features/backup/backup_format.dart';
import 'package:life_manager/features/backup/backup_service.dart';
import 'package:life_manager/features/backup/db_snapshot.dart';
import 'package:life_manager/features/settings/settings_repository.dart';

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

  BackupService service(AppDatabase db) => BackupService(
    db: db,
    supportDir: dir,
    codec: BackupCodec(const DartArgon2idKdf(), const AesGcmAead()),
    snapshotter: SqlCipherSnapshotter(Directory('${dir.path}/snap')),
    dbKey: _key,
    settings: SettingsRepository(db),
    appVersion: '1.0.0',
  );

  setUp(() async {
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

  test('recoverInterruptedRestore removes orphan incoming', () async {
    paths.incoming.writeAsStringSync('half-written');
    await BackupService.recoverInterruptedRestore(dir, _key);
    expect(paths.incoming.existsSync(), isFalse);
    expect(paths.db.existsSync(), isTrue);
  });

  test('createBackup records metadata and lastBackupAt', () async {
    final at = DateTime.utc(2026, 10, 22, 9);
    final file = await service(db).createBackup(_pw, kdf: _cheap, now: at);
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
}
