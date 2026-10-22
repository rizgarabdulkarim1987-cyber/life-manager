import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import '../../core/db/app_database.dart';
import '../../core/security/sensitive.dart';

/// Moves the database between its encrypted on-disk form and a plain SQLite
/// file, which is what goes (re-encrypted) into a backup.
abstract interface class DbSnapshotter {
  Future<Uint8List> exportPlain(AppDatabase db);
  Future<void> importToEncrypted({required File plainDb, required File target, required Sensitive<String> hexKey});
}

String _quote(String path) => "'${path.replaceAll("'", "''")}'";

/// Uses SQLCipher's `sqlcipher_export`. The plain copy exists only for a moment
/// inside app-private storage and is deleted before returning.
class SqlCipherSnapshotter implements DbSnapshotter {
  SqlCipherSnapshotter(this.workDir);

  final Directory workDir;

  @override
  Future<Uint8List> exportPlain(AppDatabase db) async {
    await workDir.create(recursive: true);
    final plain = File(p.join(workDir.path, 'export-${DateTime.now().microsecondsSinceEpoch}.db'));
    try {
      final version = (await db.customSelect('PRAGMA user_version').getSingle()).data.values.first as int;
      await db.customStatement('ATTACH DATABASE ${_quote(plain.path)} AS plain KEY \'\'');
      try {
        await db.customSelect("SELECT sqlcipher_export('plain')").get();
        // sqlcipher_export does not carry user_version, which restore relies on.
        await db.customStatement('PRAGMA plain.user_version = $version');
      } finally {
        await db.customStatement('DETACH DATABASE plain');
      }
      return await plain.readAsBytes();
    } finally {
      if (plain.existsSync()) plain.deleteSync();
    }
  }

  @override
  Future<void> importToEncrypted({
    required File plainDb,
    required File target,
    required Sensitive<String> hexKey,
  }) async {
    if (target.existsSync()) target.deleteSync();
    final db = sqlite3.open(plainDb.path);
    try {
      final version = db.select('PRAGMA user_version').first.values.first as int;
      db.execute("ATTACH DATABASE ${_quote(target.path)} AS enc KEY \"x'${hexKey.value}'\"");
      db.execute("SELECT sqlcipher_export('enc')");
      db.execute('PRAGMA enc.user_version = $version');
      db.execute('DETACH DATABASE enc');
    } finally {
      db.close();
    }
  }
}

/// `PRAGMA user_version` of a plain SQLite file, or throws if it isn't one.
int plainUserVersion(File plainDb) {
  final db = sqlite3.open(plainDb.path, mode: OpenMode.readOnly);
  try {
    return db.select('PRAGMA user_version').first.values.first as int;
  } finally {
    db.close();
  }
}

/// True when [file] opens with [hexKey] and passes `PRAGMA integrity_check`.
bool encryptedDbIsHealthy(File file, Sensitive<String> hexKey) {
  if (!file.existsSync()) return false;
  try {
    final db = sqlite3.open(file.path, mode: OpenMode.readOnly);
    try {
      db.execute("PRAGMA key = \"x'${hexKey.value}'\"");
      final r = db.select('PRAGMA integrity_check');
      return r.length == 1 && r.first.values.first == 'ok';
    } finally {
      db.close();
    }
  } on SqliteException {
    return false;
  }
}
