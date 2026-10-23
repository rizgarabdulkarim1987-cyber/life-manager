import 'dart:typed_data';

import 'package:drift/drift.dart' show InsertMode, Value;
import 'package:drift/native.dart';
import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/providers.dart';
import 'package:life_manager/core/db/app_database.dart';
import 'package:life_manager/core/storage/secure_store.dart';
import 'package:life_manager/features/lock/lock_controller.dart';
import 'package:life_manager/features/settings/settings_repository.dart';
import 'package:life_manager/features/vault/crypto/vault_key.dart';
import 'package:life_manager/features/vault/data/vault_providers.dart';
import 'package:life_manager/features/vault/vault_session.dart';

import '../../helpers/app_harness.dart';
import '../../helpers/fakes.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer c;
  late DateTime now;

  Future<void> boot(WidgetTester t, {bool setUp = true, int autoLockSeconds = 120}) async {
    db = AppDatabase(NativeDatabase.memory());
    await db
        .into(db.appSettingsTable)
        .insert(const AppSettingsTableCompanion(id: Value(1)), mode: InsertMode.insertOrIgnore);
    if (setUp) {
      await db
          .into(db.vaultMeta)
          .insert(
            VaultMetaCompanion.insert(vaultId: 'a' * 32, checkBlob: Uint8List(45), createdAt: DateTime.utc(2026)),
          );
    }
    now = DateTime.utc(2026, 10, 23, 12);
    await db.update(db.appSettingsTable).write(AppSettingsTableCompanion(vaultAutoLockSeconds: Value(autoLockSeconds)));
    final settings = await db.select(db.appSettingsTable).getSingle();
    c = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        secureStoreProvider.overrideWithValue(InMemorySecureStore()),
        kdfProvider.overrideWithValue(FakeKdf()),
        biometricKeyStoreProvider.overrideWithValue(FakeBiometricKeyStore()),
        vaultClockProvider.overrideWithValue(() => now),
        settingsProvider.overrideWith((ref) => Stream.value(settings)),
      ],
    );
    addTearDown(() async {
      c.dispose();
      await db.close();
    });
    c.listen(settingsProvider, (_, _) {});
    c.read(vaultSessionProvider);
    await c.read(vaultSessionProvider.notifier).refresh();
    await t.pump();
  }

  VaultSession session() => c.read(vaultSessionProvider.notifier);

  testWidgets('no vault yet → VaultNotSetUp; set up → VaultLocked', (t) async {
    await boot(t, setUp: false);
    expect(c.read(vaultSessionProvider), isA<VaultNotSetUp>());
    await db
        .into(db.vaultMeta)
        .insert(VaultMetaCompanion.insert(vaultId: 'a' * 32, checkBlob: Uint8List(45), createdAt: DateTime.utc(2026)));
    await session().refresh();
    expect(c.read(vaultSessionProvider), isA<VaultLocked>());
  });

  testWidgets('unlock, then 120 s idle → locked and the key wiped', (t) async {
    await boot(t);
    final k = generateVaultKey();
    session().unlocked(k);
    expect(c.read(vaultSessionProvider), isA<VaultUnlocked>());
    expect(session().requireKey(), same(k));
    await t.pump(const Duration(seconds: 119));
    expect(c.read(vaultSessionProvider), isA<VaultUnlocked>());
    await t.pump(const Duration(seconds: 2));
    expect(c.read(vaultSessionProvider), isA<VaultLocked>());
    expect(k.isDestroyed, isTrue);
    expect(() => session().requireKey(), throwsStateError);
  });

  testWidgets('a touch restarts the idle timer', (t) async {
    await boot(t);
    session().unlocked(generateVaultKey());
    await t.pump(const Duration(seconds: 100));
    session().touch();
    await t.pump(const Duration(seconds: 100));
    expect(c.read(vaultSessionProvider), isA<VaultUnlocked>());
    await t.pump(const Duration(seconds: 21));
    expect(c.read(vaultSessionProvider), isA<VaultLocked>());
  });

  testWidgets('the idle time follows the setting', (t) async {
    await boot(t, autoLockSeconds: 60);
    session().unlocked(generateVaultKey());
    await t.pump(const Duration(seconds: 61));
    expect(c.read(vaultSessionProvider), isA<VaultLocked>());
  });

  testWidgets('lock() wipes the key at once', (t) async {
    await boot(t);
    final k = generateVaultKey();
    session().unlocked(k);
    session().lock();
    expect(c.read(vaultSessionProvider), isA<VaultLocked>());
    expect(k.isDestroyed, isTrue);
  });

  testWidgets('a second unlock wipes the previous key', (t) async {
    await boot(t);
    final a = generateVaultKey();
    session().unlocked(a);
    session().unlocked(generateVaultKey());
    expect(a.isDestroyed, isTrue);
    session().lock();
  });

  testWidgets('fresh auth is needed after 30 s', (t) async {
    await boot(t);
    session().unlocked(generateVaultKey());
    now = now.add(const Duration(seconds: 29));
    expect(session().needsFreshAuth(), isFalse);
    now = now.add(const Duration(seconds: 2));
    expect(session().needsFreshAuth(), isTrue);
    session().freshAuth();
    expect(session().needsFreshAuth(), isFalse);
    session().lock();
    expect(session().needsFreshAuth(), isTrue);
  });

  testWidgets('disposing the container wipes the key', (t) async {
    await boot(t);
    final k = generateVaultKey();
    session().unlocked(k);
    c.dispose();
    expect(k.isDestroyed, isTrue);
    c = ProviderContainer(); // the tear-down disposes this one instead
  });

  test('setVaultAutoLock accepts 1, 2, 5, 10 minutes only', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db
        .into(db.appSettingsTable)
        .insert(const AppSettingsTableCompanion(id: Value(1)), mode: InsertMode.insertOrIgnore);
    final s = SettingsRepository(db);
    await s.setVaultAutoLock(const Duration(minutes: 10));
    expect((await s.get()).vaultAutoLockSeconds, 600);
    expect(() => s.setVaultAutoLock(const Duration(seconds: 45)), throwsArgumentError);
  });

  group('in the running app', () {
    testWidgets('hiding the app locks the vault at once', (t) async {
      final app = await pumpApp(t, overrides: [biometricKeyStoreProvider.overrideWithValue(FakeBiometricKeyStore())]);
      final k = generateVaultKey();
      app.read(vaultSessionProvider.notifier).unlocked(k);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      await t.pump();
      expect(k.isDestroyed, isTrue);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await t.pumpAndSettle();
    });

    testWidgets('the app lock locking also locks the vault', (t) async {
      final app = await pumpApp(t, overrides: [biometricKeyStoreProvider.overrideWithValue(FakeBiometricKeyStore())]);
      final k = generateVaultKey();
      app.read(vaultSessionProvider.notifier).unlocked(k);
      app.read(lockControllerProvider.notifier).lockNow();
      await t.pumpAndSettle();
      expect(k.isDestroyed, isTrue);
    });
  });
}
