import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/providers.dart';
import 'package:life_manager/app/router.dart';
import 'package:life_manager/core/crypto/kdf.dart';
import 'package:life_manager/core/security/sensitive.dart';
import 'package:life_manager/core/storage/secure_store.dart';
import 'package:life_manager/features/vault/data/vault_providers.dart';
import 'package:life_manager/features/vault/platform/secret_clipboard.dart';
import 'package:life_manager/features/vault/vault_session.dart';

import 'app_harness.dart';
import 'fakes.dart';
import 'finance_ui.dart';

export 'finance_ui.dart' show dbOf, settle;

const kTestMasterPassword = 'TEST-ONLY-master-77';

class FakeSecretClipboard implements SecretClipboard {
  final copies = <String>[];

  @override
  Future<bool> copy(Sensitive<String> value, {Duration clearAfter = kClipboardClear}) async {
    copies.add(value.value);
    return true;
  }
}

/// A running app whose vault uses fast fakes and a clock the test moves.
class VaultHarness {
  VaultHarness(this.app, this.bio, this.clipboard, this._advance);

  final ProviderContainer app;
  final FakeBiometricKeyStore bio;
  final FakeSecretClipboard clipboard;
  final void Function(Duration) _advance;

  void advance(Duration d) => _advance(d);

  VaultSession get session => app.read(vaultSessionProvider.notifier);

  /// Writes a vault with [kTestMasterPassword]; returns the recovery key's display string.
  Future<String> setUpVault(WidgetTester t) async {
    final service = app.read(vaultKeyServiceProvider);
    final display = await t.runAsync(() async {
      final p = await service.prepareSetUp(const Sensitive(kTestMasterPassword), params: kDefaultKdfParams);
      final d = p.recoveryKey.display;
      await service.commitSetUp(p);
      p.discard();
      return d;
    });
    await t.runAsync(session.refresh);
    await settle(t);
    return display!;
  }

  Future<void> unlock(WidgetTester t, [String pw = kTestMasterPassword]) async {
    final k = await t.runAsync(() => app.read(vaultKeyServiceProvider).unlockWithPassword(Sensitive(pw)));
    session.unlocked(k!);
    await settle(t);
  }

  Future<void> go(WidgetTester t, String location) async {
    app.read(routerProvider).go(location);
    await settle(t);
  }

  /// Ends the idle timer so no timer outlives the test.
  void lock() => session.lock();
}

Future<VaultHarness> pumpVault(WidgetTester t, {String locale = 'en', bool bioAvailable = true}) async {
  var now = DateTime.utc(2026, 10, 23, 9);
  final bio = FakeBiometricKeyStore(available: bioAvailable);
  final clipboard = FakeSecretClipboard();
  final app = await pumpApp(
    t,
    locale: locale,
    overrides: [
      secureStoreProvider.overrideWithValue(InMemorySecureStore()),
      kdfProvider.overrideWithValue(FakeKdf()),
      biometricKeyStoreProvider.overrideWithValue(bio),
      secretClipboardProvider.overrideWithValue(clipboard),
      vaultClockProvider.overrideWithValue(() => now),
    ],
  );
  addTearDown(() => app.read(vaultSessionProvider.notifier).lock());
  return VaultHarness(app, bio, clipboard, (d) => now = now.add(d));
}

/// The text field inside a keyed field widget (SecretField, RecoveryKeyField, TextField).
Finder fieldIn(String key) =>
    find.descendant(of: find.byKey(ValueKey(key)), matching: find.byType(EditableText), matchRoot: true);

/// Builds [f] when a small screen keeps it below the visible part of a lazy list.
Future<void> _build(WidgetTester t, Finder f) async {
  if (f.evaluate().isNotEmpty) return;
  final page = find.byWidgetPredicate((w) => w is Scrollable && w.axis == Axis.vertical).first;
  for (final step in [150.0, -150.0]) {
    try {
      await t.scrollUntilVisible(f, step, scrollable: page, maxScrolls: 400);
      return;
    } on StateError {
      // Not that way; try the other.
    }
  }
}

Future<void> enter(WidgetTester t, String key, String text) async {
  final f = fieldIn(key);
  await _build(t, f);
  await t.ensureVisible(f.first);
  await t.enterText(f.first, text);
  await settle(t);
}

Future<void> tapKey(WidgetTester t, String key) async {
  final f = find.byKey(ValueKey(key));
  await _build(t, f);
  await t.ensureVisible(f.first);
  await t.pumpAndSettle();
  await t.tap(f.first);
  await settle(t);
}

bool enabled(WidgetTester t, String key) {
  final w = t.widget(find.byKey(ValueKey(key)));
  return switch (w) {
    ButtonStyleButton() => w.onPressed != null,
    IconButton() => w.onPressed != null,
    _ => throw StateError('not a button: $key'),
  };
}
