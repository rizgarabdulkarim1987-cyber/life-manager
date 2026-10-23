import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/core/security/sensitive.dart';
import 'package:life_manager/features/vault/crypto/vault_errors.dart';
import 'package:life_manager/features/vault/data/vault_providers.dart';
import 'package:life_manager/features/vault/platform/biometric_key_store.dart';
import 'package:life_manager/features/vault/vault_session.dart';

import '../../../helpers/vault_ui.dart';

String _displayedRecoveryKey(WidgetTester t) => t
    .widgetList<Text>(
      find.descendant(of: find.byKey(const ValueKey('vault-recovery-key')), matching: find.byType(Text)),
    )
    .map((w) => w.data!)
    .join('-');

void main() {
  testWidgets('setup: length rule, mismatch, recovery key typed back, then the vault opens', (t) async {
    final v = await pumpVault(t);
    await v.go(t, '/vault');
    await tapKey(t, 'vault-setup-start');

    await enter(t, 'vault-new-password', 'short-pw9');
    await enter(t, 'vault-confirm-password', 'short-pw9');
    expect(enabled(t, 'vault-password-submit'), isFalse);

    await enter(t, 'vault-new-password', kTestMasterPassword);
    await enter(t, 'vault-confirm-password', '${kTestMasterPassword}x');
    await tapKey(t, 'vault-password-submit');
    expect(find.text('Passwords don\'t match'), findsOneWidget);

    await enter(t, 'vault-confirm-password', kTestMasterPassword);
    await tapKey(t, 'vault-password-submit');
    final shown = _displayedRecoveryKey(t);
    expect(shown, matches(RegExp(r'^([A-Z2-7]{4}-){7}[A-Z2-7]{4}$')));
    expect(await t.runAsync(() => v.app.read(vaultKeyServiceProvider).isSetUp()), isFalse);

    await tapKey(t, 'vault-recovery-next');
    await enter(t, 'vault-recovery-typed', 'AAAA-AAAA-AAAA-AAAA-AAAA-AAAA-AAAA-AAAA');
    await tapKey(t, 'vault-recovery-confirm');
    expect(find.text('That doesn\'t match the key shown before.'), findsOneWidget);
    expect(await t.runAsync(() => v.app.read(vaultKeyServiceProvider).isSetUp()), isFalse);

    // Lower case and no dashes are fine.
    await enter(t, 'vault-recovery-typed', shown.replaceAll('-', '').toLowerCase());
    await tapKey(t, 'vault-recovery-confirm');
    expect(find.byKey(const ValueKey('vault-setup-bio-enable')), findsOneWidget);
    await tapKey(t, 'vault-setup-bio-skip');

    expect(v.app.read(vaultSessionProvider), isA<VaultUnlocked>());
    expect(find.byKey(const ValueKey('vault-empty')), findsOneWidget);
    // Both secrets open the stored vault.
    final service = v.app.read(vaultKeyServiceProvider);
    (await t.runAsync(() => service.unlockWithPassword(const Sensitive(kTestMasterPassword))))!.destroy();
    (await t.runAsync(() => service.unlockWithRecovery(shown)))!.destroy();
    v.lock();
  });

  testWidgets('setup can turn on fingerprint unlock', (t) async {
    final v = await pumpVault(t);
    await v.go(t, '/vault');
    await tapKey(t, 'vault-setup-start');
    await enter(t, 'vault-new-password', kTestMasterPassword);
    await enter(t, 'vault-confirm-password', kTestMasterPassword);
    await tapKey(t, 'vault-password-submit');
    final shown = _displayedRecoveryKey(t);
    await tapKey(t, 'vault-recovery-next');
    await enter(t, 'vault-recovery-typed', shown);
    await tapKey(t, 'vault-recovery-confirm');
    await tapKey(t, 'vault-setup-bio-enable');
    expect(v.bio.prompts, 1);
    expect(await t.runAsync(() => v.app.read(vaultKeyServiceProvider).biometricEnabled()), isTrue);
    expect(v.app.read(vaultSessionProvider), isA<VaultUnlocked>());
    v.lock();
  });

  testWidgets('in Arabic the recovery key still reads left to right', (t) async {
    final v = await pumpVault(t, locale: 'ar');
    await v.go(t, '/vault');
    await tapKey(t, 'vault-setup-start');
    await enter(t, 'vault-new-password', kTestMasterPassword);
    await enter(t, 'vault-confirm-password', kTestMasterPassword);
    await tapKey(t, 'vault-password-submit');
    final view = t.element(find.byKey(const ValueKey('vault-recovery-key')));
    expect(Directionality.of(view), TextDirection.ltr);
    expect(Directionality.of(t.element(find.byKey(const ValueKey('vault-recovery-next')))), TextDirection.rtl);
  });

  testWidgets('wrong master password: generic error, then a lockout countdown on the 5th', (t) async {
    final v = await pumpVault(t, bioAvailable: false);
    await v.setUpVault(t);
    await v.go(t, '/vault');
    expect(find.byKey(const ValueKey('vault-locked-title')), findsOneWidget);

    await enter(t, 'vault-unlock-password', 'not-the-password');
    await tapKey(t, 'vault-unlock-submit');
    expect(find.textContaining('That doesn\'t open the vault.'), findsOneWidget);
    for (var i = 0; i < 4; i++) {
      await enter(t, 'vault-unlock-password', 'not-the-password');
      await tapKey(t, 'vault-unlock-submit');
    }
    expect(find.textContaining('Too many attempts. Try again in 0:30'), findsOneWidget);
    // Even the right password waits out the lockout.
    await enter(t, 'vault-unlock-password', kTestMasterPassword);
    expect(enabled(t, 'vault-unlock-submit'), isFalse);
    v.advance(const Duration(seconds: 31));
    await t.pump(const Duration(seconds: 1));
    await settle(t);
    await tapKey(t, 'vault-unlock-submit');
    expect(v.app.read(vaultSessionProvider), isA<VaultUnlocked>());
    v.lock();
  });

  testWidgets('recovery-key unlock forces a new master password that Back cannot skip', (t) async {
    final v = await pumpVault(t, bioAvailable: false);
    final recovery = await v.setUpVault(t);
    await v.go(t, '/vault');
    await tapKey(t, 'vault-unlock-switch');
    await enter(t, 'vault-unlock-recovery', recovery);
    await tapKey(t, 'vault-unlock-submit');
    expect(find.byKey(const ValueKey('vault-forced-title')), findsOneWidget);

    await t.binding.handlePopRoute();
    await settle(t);
    expect(find.byKey(const ValueKey('vault-forced-title')), findsOneWidget);

    await enter(t, 'vault-new-password', 'TEST-ONLY-brand-new-9');
    await enter(t, 'vault-confirm-password', 'TEST-ONLY-brand-new-9');
    await tapKey(t, 'vault-password-submit');
    expect(find.byKey(const ValueKey('vault-empty')), findsOneWidget);

    final service = v.app.read(vaultKeyServiceProvider);
    (await t.runAsync(() => service.unlockWithPassword(const Sensitive('TEST-ONLY-brand-new-9'))))!.destroy();
    final old = await t.runAsync(() async {
      try {
        await service.unlockWithPassword(const Sensitive(kTestMasterPassword));
        return null;
      } on VaultUnlockError catch (e) {
        return e;
      }
    });
    expect(old, isA<VaultWrongSecret>());
    v.lock();
  });

  testWidgets('a locked vault on a deep route shows the unlock screen, not the item', (t) async {
    final v = await pumpVault(t, bioAvailable: false);
    await v.setUpVault(t);
    await v.go(t, '/vault/item/1');
    expect(find.byKey(const ValueKey('vault-locked-title')), findsOneWidget);
    await v.go(t, '/vault/settings');
    expect(find.byKey(const ValueKey('vault-locked-title')), findsOneWidget);
    expect(find.byKey(const ValueKey('vault-how-protected')), findsNothing);
  });

  testWidgets('fingerprint unlock opens the vault; an invalidated key falls back with a notice', (t) async {
    final v = await pumpVault(t);
    await v.setUpVault(t);
    await v.unlock(t);
    await t.runAsync(
      () => v.app
          .read(vaultKeyServiceProvider)
          .enableBiometric(v.session.requireKey(), const BioPromptText(title: 't', subtitle: 's', cancel: 'c')),
    );
    v.app.invalidate(vaultBiometricEnabledProvider);
    v.lock();
    await v.go(t, '/vault');
    // The screen prompts once by itself.
    expect(v.app.read(vaultSessionProvider), isA<VaultUnlocked>());

    // Locking again: the next automatic prompt finds the Keystore key invalidated.
    v.bio.failNext = const VaultBiometricInvalidated();
    v.lock();
    await settle(t);
    expect(find.textContaining('Fingerprint unlock was turned off'), findsOneWidget);
    expect(find.byKey(const ValueKey('vault-unlock-bio')), findsNothing);
  });
}
