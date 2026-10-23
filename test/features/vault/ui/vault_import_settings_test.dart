import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/core/security/sensitive.dart';
import 'package:life_manager/features/vault/crypto/vault_errors.dart';
import 'package:life_manager/features/vault/crypto/vault_key.dart';
import 'package:life_manager/features/vault/data/vault_providers.dart';
import 'package:life_manager/features/vault/platform/biometric_key_store.dart';

import '../../../helpers/vault_ui.dart';

const _bio = BioPromptText(title: 't', subtitle: 's', cancel: 'c');

void main() {
  Future<VaultHarness> openVault(WidgetTester t, {bool bio = false}) async {
    final v = await pumpVault(t, bioAvailable: bio);
    await v.setUpVault(t);
    await v.unlock(t);
    return v;
  }

  /// The unlock error [run] throws, or null when it opened the vault.
  Future<Object?> unlockError(WidgetTester t, VaultHarness v, Future<VaultKey> Function() run) =>
      t.runAsync<Object?>(() async {
        try {
          (await run()).destroy();
          return null;
        } on VaultUnlockError catch (e) {
          return e;
        }
      });

  testWidgets('import: two blocks give two cards; dropping one saves one and shows the reminder', (t) async {
    final v = await openVault(t);
    await v.go(t, '/vault/import');
    await enter(
      t,
      'vault-import-paste',
      'Facebook\nuser: ahmed\npass: TEST-ONLY-fb-1\n\nGitHub\nuser: octo\npass: TEST-ONLY-gh-2',
    );
    await tapKey(t, 'vault-import-find');
    expect(find.byKey(const ValueKey('vault-proposal-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('vault-proposal-1')), findsOneWidget);
    expect(find.textContaining('TEST-ONLY'), findsNothing);

    await t.tap(
      find.descendant(
        of: find.byKey(const ValueKey('vault-proposal-1')),
        matching: find.byKey(const ValueKey('vault-proposal-keep')),
      ),
    );
    await settle(t);
    await tapKey(t, 'vault-import-save');
    expect(find.byKey(const ValueKey('vault-import-reminder')), findsOneWidget);
    await t.tap(find.text('OK'));
    await settle(t);

    final rows = await t.runAsync(() => dbOf(v.app).select(dbOf(v.app).vaultItems).get());
    expect(rows!.single.title, 'Facebook');
    expect(rows.single.category, 'social');
    v.lock();
  });

  testWidgets('import: text without passwords says so', (t) async {
    final v = await openVault(t);
    await v.go(t, '/vault/import');
    await enter(t, 'vault-import-paste', 'milk\nbread');
    await tapKey(t, 'vault-import-find');
    expect(find.text('No passwords found in this text.'), findsOneWidget);
    v.lock();
  });

  testWidgets('change master password: a wrong current one fails; the right one switches', (t) async {
    final v = await openVault(t);
    await v.go(t, '/vault/settings');
    await tapKey(t, 'vault-change-password');
    await enter(t, 'vault-current-password', 'TEST-ONLY-not-it');
    await enter(t, 'vault-new-password', 'TEST-ONLY-next-master');
    await enter(t, 'vault-confirm-password', 'TEST-ONLY-next-master');
    await tapKey(t, 'vault-password-submit');
    expect(find.textContaining('That doesn\'t open the vault.'), findsOneWidget);

    await enter(t, 'vault-current-password', kTestMasterPassword);
    await tapKey(t, 'vault-password-submit');
    expect(find.text('Master password changed'), findsOneWidget);
    final service = v.app.read(vaultKeyServiceProvider);
    expect(await unlockError(t, v, () => service.unlockWithPassword(const Sensitive('TEST-ONLY-next-master'))), isNull);
    expect(
      await unlockError(t, v, () => service.unlockWithPassword(const Sensitive(kTestMasterPassword))),
      isA<VaultWrongSecret>(),
    );
    v.lock();
  });

  testWidgets('new recovery key must be typed back; then the old one stops working', (t) async {
    final v = await openVault(t);
    final service = v.app.read(vaultKeyServiceProvider);
    await v.go(t, '/vault/settings');
    await tapKey(t, 'vault-new-recovery');
    final shown = t
        .widgetList<Text>(
          find.descendant(of: find.byKey(const ValueKey('vault-recovery-key')), matching: find.byType(Text)),
        )
        .map((w) => w.data!)
        .join('-');
    await tapKey(t, 'vault-recovery-next');
    await enter(t, 'vault-recovery-typed', 'AAAA');
    await tapKey(t, 'vault-recovery-confirm');
    expect(find.text('That doesn\'t match the key shown before.'), findsOneWidget);
    await enter(t, 'vault-recovery-typed', shown);
    await tapKey(t, 'vault-recovery-confirm');
    expect(find.text('New recovery key saved'), findsOneWidget);
    expect(await unlockError(t, v, () => service.unlockWithRecovery(shown)), isNull);
    v.lock();
  });

  testWidgets('the old recovery key fails after a replacement', (t) async {
    final v = await pumpVault(t, bioAvailable: false);
    final oldKey = await v.setUpVault(t);
    await v.unlock(t);
    await v.go(t, '/vault/settings');
    await tapKey(t, 'vault-new-recovery');
    final shown = t
        .widgetList<Text>(
          find.descendant(of: find.byKey(const ValueKey('vault-recovery-key')), matching: find.byType(Text)),
        )
        .map((w) => w.data!)
        .join('-');
    await tapKey(t, 'vault-recovery-next');
    await enter(t, 'vault-recovery-typed', shown);
    await tapKey(t, 'vault-recovery-confirm');
    final service = v.app.read(vaultKeyServiceProvider);
    expect(await unlockError(t, v, () => service.unlockWithRecovery(oldKey)), isA<VaultWrongSecret>());
    v.lock();
  });

  testWidgets('switching fingerprint off clears the wrap and the Keystore key', (t) async {
    final v = await openVault(t, bio: true);
    final service = v.app.read(vaultKeyServiceProvider);
    await t.runAsync(() => service.enableBiometric(v.session.requireKey(), _bio));
    v.app.invalidate(vaultBiometricEnabledProvider);
    await v.go(t, '/vault/settings');
    expect(t.widget<SwitchListTile>(find.byKey(const ValueKey('vault-bio-switch'))).value, isTrue);
    await tapKey(t, 'vault-bio-switch');
    expect(await t.runAsync(service.biometricEnabled), isFalse);
    expect(v.bio.deletes, greaterThan(0));
    expect(t.widget<SwitchListTile>(find.byKey(const ValueKey('vault-bio-switch'))).value, isFalse);
    v.lock();
  });

  testWidgets('auto-lock choice is saved', (t) async {
    final v = await openVault(t);
    await v.go(t, '/vault/settings');
    await tapKey(t, 'vault-autolock');
    await tapKey(t, 'vault-autolock-600');
    final s = await t.runAsync(() => dbOf(v.app).select(dbOf(v.app).appSettingsTable).getSingle());
    expect(s!.vaultAutoLockSeconds, 600);
    v.lock();
  });

  testWidgets('settings has a vault row leading to vault settings', (t) async {
    final v = await openVault(t);
    await v.go(t, '/settings');
    await t.scrollUntilVisible(find.byKey(const ValueKey('settings-vault')), 200);
    await tapKey(t, 'settings-vault');
    expect(find.byKey(const ValueKey('vault-how-protected')), findsOneWidget);
    v.lock();
  });
}
