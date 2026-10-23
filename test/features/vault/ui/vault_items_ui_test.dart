import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/core/logging/app_logger.dart';
import 'package:life_manager/core/security/sensitive.dart';
import 'package:life_manager/features/vault/data/vault_items_repository.dart';
import 'package:life_manager/features/vault/data/vault_providers.dart';

import '../../../helpers/vault_ui.dart';

const _marker = 'TEST-ONLY-pw-marker-31';

void main() {
  late List<String> logs;
  setUp(() {
    logs = [];
    AppLogger.sink = logs.add;
  });

  Future<VaultHarness> openVault(WidgetTester t) async {
    final v = await pumpVault(t, bioAvailable: false);
    await v.setUpVault(t);
    await v.unlock(t);
    return v;
  }

  Future<int> addItem(WidgetTester t, VaultHarness v, {String title = 'Facebook', String username = 'أحمد'}) async =>
      (await t.runAsync(
        () => v.app
            .read(vaultItemsRepositoryProvider)
            .create(
              v.session.requireKey(),
              VaultItemInput(
                title: title,
                username: username,
                category: 'social',
                password: const Sensitive(_marker),
                notes: const Sensitive('TEST-ONLY-note'),
              ),
            ),
      ))!;

  testWidgets('create through the form; the list shows it; the row holds no plaintext password', (t) async {
    final v = await openVault(t);
    await v.go(t, '/vault');
    await tapKey(t, 'vault-add');
    expect(enabled(t, 'vault-form-save'), isFalse);
    await enter(t, 'vault-form-title', 'Instagram');
    await enter(t, 'vault-form-username', 'ahmed.k');
    await enter(t, 'vault-form-password', _marker);
    await tapKey(t, 'vault-form-save');

    expect(find.text('Instagram'), findsOneWidget);
    final rows = await t.runAsync(() => dbOf(v.app).select(dbOf(v.app).vaultItems).get());
    expect(rows!.single.username, 'ahmed.k');
    final blob = rows.single.passwordBlob!;
    expect(latin1.decode(blob, allowInvalid: true), isNot(contains(_marker)));
    expect(logs.join(), isNot(contains(_marker)));
    v.lock();
  });

  testWidgets('search matches folded Arabic in usernames and never the password', (t) async {
    final v = await openVault(t);
    await addItem(t, v);
    await addItem(t, v, title: 'Bank', username: 'other');
    await v.go(t, '/vault');
    await enter(t, 'vault-search', 'احمد');
    expect(find.text('Facebook'), findsOneWidget);
    expect(find.text('Bank'), findsNothing);
    await enter(t, 'vault-search', _marker);
    expect(find.text('Nothing matches'), findsOneWidget);
    v.lock();
  });

  testWidgets('reveal within 30 s of unlock needs nothing more; after that the master password', (t) async {
    final v = await openVault(t);
    final id = await addItem(t, v);
    await v.go(t, '/vault/item/$id');
    await tapKey(t, 'vault-reveal-password');
    expect(find.byKey(const ValueKey('vault-fresh-auth')), findsNothing);
    expect(find.text(_marker), findsOneWidget);
    await tapKey(t, 'vault-reveal-password');
    expect(find.text(_marker), findsNothing);

    v.advance(const Duration(seconds: 31));
    await tapKey(t, 'vault-reveal-password');
    expect(find.byKey(const ValueKey('vault-fresh-auth')), findsOneWidget);
    await enter(t, 'vault-fresh-auth-password', 'TEST-ONLY-wrong-pw');
    await tapKey(t, 'vault-fresh-auth-confirm');
    expect(find.textContaining('That doesn\'t open the vault.'), findsOneWidget);
    await enter(t, 'vault-fresh-auth-password', kTestMasterPassword);
    await tapKey(t, 'vault-fresh-auth-confirm');
    expect(find.text(_marker), findsOneWidget);

    // Revealed values hide again after 30 s.
    await t.pump(const Duration(seconds: 31));
    await settle(t);
    expect(find.text(_marker), findsNothing);
    expect(logs.join(), isNot(contains(_marker)));
    v.lock();
  });

  testWidgets('locking drops the revealed value and shows the unlock screen', (t) async {
    final v = await openVault(t);
    final id = await addItem(t, v);
    await v.go(t, '/vault/item/$id');
    await tapKey(t, 'vault-reveal-password');
    expect(find.text(_marker), findsOneWidget);
    v.lock();
    await settle(t);
    expect(find.text(_marker), findsNothing);
    expect(find.byKey(const ValueKey('vault-locked-title')), findsOneWidget);
  });

  testWidgets('copy password goes through the secret clipboard once and logs nothing', (t) async {
    final v = await openVault(t);
    final id = await addItem(t, v);
    await v.go(t, '/vault/item/$id');
    await tapKey(t, 'vault-copy-password');
    expect(v.clipboard.copies, [_marker]);
    expect(find.textContaining('Cleared from the clipboard after 30 seconds'), findsOneWidget);
    expect(logs.join(), isNot(contains(_marker)));
    v.lock();
  });

  testWidgets('delete asks first, then the item is gone', (t) async {
    final v = await openVault(t);
    final id = await addItem(t, v);
    await v.go(t, '/vault/item/$id');
    await tapKey(t, 'vault-item-delete');
    await tapKey(t, 'vault-delete-confirm');
    final rows = await t.runAsync(() => dbOf(v.app).select(dbOf(v.app).vaultItems).get());
    expect(rows, isEmpty);
    v.lock();
  });

  testWidgets('edit loads the secrets and saves changes', (t) async {
    final v = await openVault(t);
    final id = await addItem(t, v);
    await v.go(t, '/vault/item/$id');
    await tapKey(t, 'vault-item-edit');
    expect(t.widget<EditableText>(fieldIn('vault-form-password')).controller.text, _marker);
    await enter(t, 'vault-form-title', 'Facebook main');
    await tapKey(t, 'vault-form-save');
    expect(find.text('Facebook main'), findsOneWidget);
    v.lock();
  });

  testWidgets('leaving the form with changes asks to discard', (t) async {
    final v = await openVault(t);
    await v.go(t, '/vault');
    await tapKey(t, 'vault-add');
    await enter(t, 'vault-form-title', 'Draft');
    await t.binding.handlePopRoute();
    await settle(t);
    expect(find.text('Discard changes?'), findsOneWidget);
    await tapKey(t, 'vault-discard-confirm');
    expect(find.byKey(const ValueKey('vault-empty')), findsOneWidget);
    v.lock();
  });

  testWidgets('generator "use this password" fills the form field', (t) async {
    final v = await openVault(t);
    await v.go(t, '/vault/new');
    await tapKey(t, 'vault-form-generate');
    final generated = t.widget<Text>(find.byKey(const ValueKey('vault-generator-value'))).data!;
    expect(generated.length, 20);
    await tapKey(t, 'vault-generator-use');
    expect(t.widget<EditableText>(fieldIn('vault-form-password')).controller.text, generated);
    v.lock();
  });
}
