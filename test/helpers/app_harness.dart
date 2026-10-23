import 'package:drift/drift.dart' show DatabaseConnection, Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/app.dart';
import 'package:life_manager/app/providers.dart';
import 'package:life_manager/core/db/app_database.dart';
import 'package:life_manager/core/db/seed.dart';
import 'package:life_manager/core/security/money_privacy.dart';
import 'package:life_manager/features/lock/lock_controller.dart';

import 'fakes.dart';

const _names = SeedNames(
  personal: 'Personal',
  buzzify: 'Buzzify',
  eo: 'EO',
  otherProjects: 'Other',
  cashIqd: 'Cash IQD',
  cashUsd: 'Cash USD',
);

/// Pumps the whole app past setup and the lock, landing on Home.
Future<ProviderContainer> pumpApp(
  WidgetTester t, {
  String locale = 'ar',
  FakeBiometric? bio,
  bool revealMoney = true,
  List<Override> overrides = const [],
}) async {
  // Widget tests fail on drift's deferred stream close; close synchronously instead.
  final db = AppDatabase(DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true));
  await seedInitialData(db, _names);
  await seedDemoData(db, _names);
  await db
      .update(db.appSettingsTable)
      .write(AppSettingsTableCompanion(setupCompleted: const Value(true), localeCode: Value(locale)));
  final container = ProviderContainer(
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      biometricAuthenticatorProvider.overrideWithValue(bio ?? FakeBiometric()),
      alwaysRevealMoneyProvider.overrideWithValue(revealMoney),
      ...overrides,
    ],
  );
  container.read(lockControllerProvider.notifier).unlock();
  addTearDown(() async {
    container.dispose();
    await db.close();
  });
  await t.pumpWidget(UncontrolledProviderScope(container: container, child: const App()));
  await t.pumpAndSettle();
  return container;
}
