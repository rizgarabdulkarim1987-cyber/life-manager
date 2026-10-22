import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'app/app.dart';
import 'app/providers.dart';
import 'app/restart_scope.dart';
import 'core/crypto/aead.dart';
import 'core/crypto/kdf.dart';
import 'core/db/app_database.dart';
import 'core/db/db_key.dart';
import 'core/storage/secure_store.dart';
import 'core/theme/tokens.dart';
import 'features/backup/backup_format.dart';
import 'features/backup/backup_screen.dart';
import 'features/backup/backup_service.dart';
import 'features/backup/db_snapshot.dart';
import 'features/settings/settings_repository.dart';

/// Keep in step with `version:` in pubspec.yaml; it is written into every backup.
const kAppVersion = '1.0.0';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    RestartScope(
      loading: ColoredBox(color: AppTokens.dark.bg),
      build: _openApp,
    ),
  );
}

/// Opens the encrypted database and wraps the app in its provider scope.
/// Runs again on RestartScope.restart, e.g. after a restore replaced the database.
Future<Widget> _openApp() async {
  final supportDir = await getApplicationSupportDirectory();
  final key = await obtainDatabaseKey(FlutterSecureStore());
  // Finish or roll back a restore that was cut off before the app could restart.
  await BackupService.recoverInterruptedRestore(supportDir, key);
  final db = await openAppDatabase(file: appDatabaseFile(supportDir), hexKey: key);
  final backup = BackupService(
    db: db,
    supportDir: supportDir,
    codec: BackupCodec(const DartArgon2idKdf(), const AesGcmAead()),
    snapshotter: SqlCipherSnapshotter(Directory(p.join(supportDir.path, 'snapshot_tmp'))),
    dbKey: key,
    settings: SettingsRepository(db),
    appVersion: kAppVersion,
  );
  return ProviderScope(
    overrides: [appDatabaseProvider.overrideWithValue(db), backupServiceProvider.overrideWithValue(backup)],
    child: const App(),
  );
}
