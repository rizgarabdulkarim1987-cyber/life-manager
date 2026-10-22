import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'app/app.dart';
import 'app/providers.dart';
import 'app/restart_scope.dart';
import 'core/db/app_database.dart';
import 'core/db/db_key.dart';
import 'core/storage/secure_store.dart';
import 'core/theme/tokens.dart';

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
  final db = await openAppDatabase(file: appDatabaseFile(supportDir), hexKey: key);
  return ProviderScope(overrides: [appDatabaseProvider.overrideWithValue(db)], child: const App());
}
