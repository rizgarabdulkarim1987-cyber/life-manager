import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;

import '../security/sensitive.dart';
import 'tables.dart';

export 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [Workspaces, Accounts, AppSettingsTable, BackupMetadata])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
          await into(appSettingsTable).insert(
            const AppSettingsTableCompanion(id: Value(1)),
            mode: InsertMode.insertOrIgnore,
          );
        },
      );
}

File appDatabaseFile(Directory supportDir) => File(p.join(supportDir.path, 'app.db'));

final _hexKey = RegExp(r'^[0-9a-f]{64}$');

/// Opens the SQLCipher database. The key is raw hex, so SQLCipher skips its
/// own KDF; [hexKey] comes from [obtainDatabaseKey].
Future<AppDatabase> openAppDatabase({required File file, required Sensitive<String> hexKey}) async {
  final key = hexKey.value;
  if (!_hexKey.hasMatch(key)) throw ArgumentError('database key must be 64 lowercase hex chars');
  return AppDatabase(NativeDatabase.createInBackground(
    file,
    setup: (raw) {
      final cipher = raw.select('PRAGMA cipher_version');
      if (cipher.isEmpty || '${cipher.first.values.first}'.isEmpty) {
        throw StateError('SQLCipher is not available');
      }
      raw.execute("PRAGMA key = \"x'$key'\"");
    },
  ));
}
