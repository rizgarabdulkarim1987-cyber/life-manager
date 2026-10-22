import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../../core/crypto/kdf.dart';
import '../../core/db/app_database.dart';
import '../../core/logging/app_logger.dart';
import '../../core/security/sensitive.dart';
import '../settings/settings_repository.dart';
import 'backup_format.dart';
import 'backup_payload.dart';
import 'db_snapshot.dart';

const _dbEntry = 'db/app.db';

String backupFileName(DateTime now) {
  String two(int n) => n.toString().padLeft(2, '0');
  return 'life-manager-${now.year}-${two(now.month)}-${two(now.day)}.$kBackupExtension';
}

/// Files the restore swap uses inside the app support directory.
class RestorePaths {
  RestorePaths(Directory supportDir)
    : db = appDatabaseFile(supportDir),
      preRestore = File(p.join(supportDir.path, 'app.db.pre-restore')),
      incoming = File(p.join(supportDir.path, 'app.db.incoming')),
      marker = File(p.join(supportDir.path, 'restore.pending')),
      tmp = Directory(p.join(supportDir.path, 'restore_tmp'));

  final File db;
  final File preRestore;
  final File incoming;
  final File marker;
  final Directory tmp;
}

class BackupService {
  BackupService({
    required this._db,
    required Directory supportDir,
    required this._codec,
    required this._snapshotter,
    required this._dbKey,
    required this._settings,
    required this._appVersion,
  }) : _paths = RestorePaths(supportDir);

  final AppDatabase _db;
  final RestorePaths _paths;
  final BackupCodec _codec;
  final DbSnapshotter _snapshotter;
  final Sensitive<String> _dbKey;
  final SettingsRepository _settings;
  final String _appVersion;

  Future<Uint8List> createBackup(Sensitive<String> password, {KdfParams? kdf, DateTime? now}) async {
    final at = (now ?? DateTime.now()).toUtc();
    final snapshot = await _snapshotter.exportPlain(_db);
    final file = await _codec.encode(
      payload: buildPayload({_dbEntry: snapshot}),
      password: password,
      schemaVersion: _db.schemaVersion,
      appVersion: _appVersion,
      kdf: kdf ?? kDefaultKdfParams,
      now: at,
    );
    await _db
        .into(_db.backupMetadata)
        .insert(
          BackupMetadataCompanion.insert(
            createdAt: at,
            kind: 'export',
            fileName: backupFileName(at.toLocal()),
            schemaVersion: _db.schemaVersion,
            appVersion: _appVersion,
            sizeBytes: file.length,
          ),
        );
    await _settings.setLastBackupAt(at);
    return file;
  }

  BackupHeader inspect(Uint8List file) => _codec.readHeader(file);

  /// Replaces the live database with the backup's. Until step 4 nothing on disk
  /// changes, so any failure leaves the current data as it was. Afterwards the
  /// database is closed and the caller must restart the app.
  Future<void> restore(Uint8List file, Sensitive<String> password, {DateTime? now}) async {
    // 1. Decrypt and verify in memory.
    final (header, payload) = await _codec.decode(file, password);
    final snapshot = readPayload(payload)[_dbEntry];
    if (snapshot == null) throw const BackupCorruptException('no database in backup');

    final tmp = _paths.tmp;
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    tmp.createSync(recursive: true);
    try {
      // 2. Refuse a database newer than this app understands.
      final plain = File(p.join(tmp.path, 'app.db'))..writeAsBytesSync(snapshot, flush: true);
      final int version;
      try {
        version = plainUserVersion(plain);
      } on Exception {
        throw const BackupCorruptException('database unreadable');
      }
      if (version > _db.schemaVersion) throw BackupTooNewException(version, _db.schemaVersion);

      // 3. Re-encrypt with this phone's database key, then open it once so an
      // older schema migrates and the restore is recorded in the restored data.
      await _snapshotter.importToEncrypted(plainDb: plain, target: _paths.incoming, hexKey: _dbKey);
      final incoming = await openAppDatabase(file: _paths.incoming, hexKey: _dbKey);
      try {
        await incoming
            .into(incoming.backupMetadata)
            .insert(
              BackupMetadataCompanion.insert(
                createdAt: (now ?? DateTime.now()).toUtc(),
                kind: 'restore',
                fileName: backupFileName(header.createdAtUtc.toLocal()),
                schemaVersion: header.schemaVersion,
                appVersion: header.appVersion,
                sizeBytes: file.length,
              ),
            );
      } finally {
        await incoming.close();
      }

      // 4. Swap, keeping the old database until the next launch confirms the new one.
      await _db.close();
      if (_paths.preRestore.existsSync()) _paths.preRestore.deleteSync();
      _paths.db.renameSync(_paths.preRestore.path);
      _paths.marker.writeAsStringSync('1', flush: true);
      _paths.incoming.renameSync(_paths.db.path);
    } catch (_) {
      if (_paths.incoming.existsSync()) _paths.incoming.deleteSync();
      rethrow;
    } finally {
      // 5. The plain copy never outlives the restore.
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    }
  }

  /// Runs at startup before the database opens. Finishes or rolls back a
  /// restore that was interrupted (app killed, phone off) during the swap.
  static Future<void> recoverInterruptedRestore(Directory supportDir, Sensitive<String> hexKey) async {
    final paths = RestorePaths(supportDir);
    if (paths.tmp.existsSync()) paths.tmp.deleteSync(recursive: true);

    if (!paths.marker.existsSync()) {
      if (paths.incoming.existsSync()) paths.incoming.deleteSync();
      return;
    }

    if (encryptedDbIsHealthy(paths.db, hexKey)) {
      if (paths.preRestore.existsSync()) paths.preRestore.deleteSync();
    } else if (paths.preRestore.existsSync()) {
      AppLogger.warn('restore did not complete; rolling back');
      if (paths.db.existsSync()) paths.db.deleteSync();
      paths.preRestore.renameSync(paths.db.path);
    }
    if (paths.incoming.existsSync()) paths.incoming.deleteSync();
    paths.marker.deleteSync();
  }
}
