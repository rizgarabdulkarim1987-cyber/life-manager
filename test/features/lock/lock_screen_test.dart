import 'package:drift/drift.dart' show Value;
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/providers.dart';
import 'package:life_manager/core/crypto/kdf.dart';
import 'package:life_manager/core/db/app_database.dart';
import 'package:life_manager/core/l10n/ckb_fallback_localizations.dart';
import 'package:life_manager/core/storage/secure_store.dart';
import 'package:life_manager/core/theme/app_theme.dart';
import 'package:life_manager/features/lock/biometric_authenticator.dart';
import 'package:life_manager/features/lock/lock_controller.dart';
import 'package:life_manager/features/lock/lock_screen.dart';
import 'package:life_manager/features/lock/pin_service.dart';

/// Fast deterministic stand-in so widget tests don't wait on a real KDF isolate.
class FakeKdf implements Kdf {
  @override
  Future<Uint8List> derive({
    required Uint8List password,
    required Uint8List salt,
    required KdfParams params,
    int length = 32,
  }) async =>
      Uint8List.fromList(List.generate(length, (i) => (password[i % password.length] * 31 + salt[i % salt.length] + i) & 0xff));
}

class FakeBiometric implements BiometricAuthenticator {
  FakeBiometric({required this.available, required this.result});
  final bool available;
  final bool result;
  int prompts = 0;
  @override
  Future<bool> isAvailable() async => available;
  @override
  Future<bool> authenticate(String reason) async {
    prompts++;
    return result;
  }
}

void main() {
  late AppDatabase db;
  late PinService pins;
  late ProviderContainer container;

  Future<void> pump(WidgetTester t, {required FakeBiometric bio, bool biometricEnabled = true, Locale locale = const Locale('en')}) async {
    db = AppDatabase(NativeDatabase.memory());
    await db.update(db.appSettingsTable).write(AppSettingsTableCompanion(biometricEnabled: Value(biometricEnabled)));
    pins = PinService(InMemorySecureStore(), FakeKdf());
    await pins.setPin('123456');
    container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      pinServiceProvider.overrideWithValue(pins),
      biometricAuthenticatorProvider.overrideWithValue(bio),
    ]);
    await t.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: buildAppTheme(Brightness.dark),
        locale: locale,
        supportedLocales: kSupportedLocales,
        localizationsDelegates: appLocalizationDelegates,
        home: const LockScreen(),
      ),
    ));
    await t.pumpAndSettle();
  }

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<void> enter(WidgetTester t, String digits) async {
    for (final d in digits.split('')) {
      await t.tap(find.byKey(ValueKey('pin-key-$d')));
      await t.pump();
    }
    await t.pumpAndSettle();
  }

  testWidgets('biometric success unlocks without a PIN', (t) async {
    final bio = FakeBiometric(available: true, result: true);
    await pump(t, bio: bio);
    expect(bio.prompts, 1);
    expect(container.read(lockControllerProvider), LockStatus.unlocked);
  });

  testWidgets('LockScreen falls back to PIN when biometrics fail', (t) async {
    await pump(t, bio: FakeBiometric(available: true, result: false));
    expect(container.read(lockControllerProvider), LockStatus.locked);
    await enter(t, '123456');
    expect(container.read(lockControllerProvider), LockStatus.unlocked);
  });

  testWidgets('no biometric prompt when the setting is off', (t) async {
    final bio = FakeBiometric(available: true, result: true);
    await pump(t, bio: bio, biometricEnabled: false);
    expect(bio.prompts, 0);
    expect(find.byKey(const ValueKey('pin-key-bio')), findsNothing);
  });

  testWidgets('wrong PIN shows an error and stays locked', (t) async {
    await pump(t, bio: FakeBiometric(available: false, result: false));
    await enter(t, '000000');
    expect(find.text('Wrong PIN'), findsOneWidget);
    expect(container.read(lockControllerProvider), LockStatus.locked);
  });

  testWidgets('keypad stays 1-2-3 left to right in Arabic', (t) async {
    await pump(t, bio: FakeBiometric(available: false, result: false), locale: const Locale('ar'));
    final one = t.getCenter(find.byKey(const ValueKey('pin-key-1')));
    final three = t.getCenter(find.byKey(const ValueKey('pin-key-3')));
    expect(one.dx, lessThan(three.dx));
    expect(t.takeException(), isNull);
  });

  testWidgets('small phone does not overflow', (t) async {
    t.view.physicalSize = const Size(320 * 3, 568 * 3);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    await pump(t, bio: FakeBiometric(available: false, result: false), locale: const Locale('ckb'));
    expect(t.takeException(), isNull);
  });
}
