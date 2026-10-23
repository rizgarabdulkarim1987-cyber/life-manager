import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/core/security/sensitive.dart';
import 'package:life_manager/features/vault/data/vault_items_repository.dart';
import 'package:life_manager/features/vault/data/vault_providers.dart';

import '../helpers/vault_ui.dart';

void main() {
  final title120 = List.filled(12, 'تێبینی درێژ').join(' ').substring(0, 120);

  void small(WidgetTester t, double scale) {
    t.view.physicalSize = const Size(320, 640);
    t.view.devicePixelRatio = 1;
    t.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(() {
      t.view.reset();
      t.platformDispatcher.clearTextScaleFactorTestValue();
    });
  }

  Future<VaultHarness> open(WidgetTester t, double scale, {String locale = 'ckb'}) async {
    small(t, scale);
    final v = await pumpVault(t, locale: locale, bioAvailable: false);
    await v.setUpVault(t);
    await v.unlock(t);
    return v;
  }

  Future<int> add(WidgetTester t, VaultHarness v, VaultItemInput i) async =>
      (await t.runAsync(() => v.app.read(vaultItemsRepositoryProvider).create(v.session.requireKey(), i)))!;

  for (final scale in [1.0, 2.0]) {
    group('vault at 320 dp, Sorani, ${scale}x text', () {
      testWidgets('setup steps', (t) async {
        small(t, scale);
        final v = await pumpVault(t, locale: 'ckb');
        await v.go(t, '/vault');
        expect(t.takeException(), isNull);
        await tapKey(t, 'vault-setup-start');
        await enter(t, 'vault-new-password', kTestMasterPassword);
        await enter(t, 'vault-confirm-password', kTestMasterPassword);
        expect(t.takeException(), isNull);
        await tapKey(t, 'vault-password-submit');
        expect(t.takeException(), isNull);
        final shown = t
            .widgetList<Text>(
              find.descendant(of: find.byKey(const ValueKey('vault-recovery-key')), matching: find.byType(Text)),
            )
            .map((w) => w.data!)
            .join('-');
        await tapKey(t, 'vault-recovery-next');
        await enter(t, 'vault-recovery-typed', shown);
        expect(t.takeException(), isNull);
        await tapKey(t, 'vault-recovery-confirm');
        expect(t.takeException(), isNull);
        await tapKey(t, 'vault-setup-bio-skip');
        v.lock();
      });

      testWidgets('unlock with the lockout message', (t) async {
        small(t, scale);
        final v = await pumpVault(t, locale: 'ckb', bioAvailable: false);
        await v.setUpVault(t);
        await v.go(t, '/vault');
        for (var i = 0; i < 5; i++) {
          await enter(t, 'vault-unlock-password', 'not-the-password');
          await tapKey(t, 'vault-unlock-submit');
        }
        expect(find.byKey(const ValueKey('vault-unlock-error')), findsOneWidget);
        expect(t.takeException(), isNull);
        await tapKey(t, 'vault-unlock-switch');
        expect(t.takeException(), isNull);
        v.lock();
      });

      testWidgets('200 items with 120-character titles', (t) async {
        final v = await open(t, scale);
        await t.runAsync(() async {
          for (var i = 0; i < 200; i++) {
            await v.app
                .read(vaultItemsRepositoryProvider)
                .create(
                  v.session.requireKey(),
                  VaultItemInput(title: '$i ${title120.substring(4)}', username: 'u' * 80, category: 'other'),
                );
          }
        });
        await v.go(t, '/vault');
        expect(t.takeException(), isNull);
        await t.drag(find.byKey(const ValueKey('vault-list')), const Offset(0, -6000));
        await t.pump(const Duration(milliseconds: 300));
        expect(t.takeException(), isNull);
        v.lock();
      });

      testWidgets('detail with a 2000-character URL', (t) async {
        final v = await open(t, scale);
        final id = await add(
          t,
          v,
          VaultItemInput(
            title: title120,
            url: 'https://example.com/${'a' * 1980}',
            username: 'u' * 200,
            email: '${'e' * 100}@example.com',
            category: 'banking',
            password: Sensitive('p' * 300),
            notes: Sensitive(List.filled(60, 'تێبینی درێژ').join('\n')),
            recoveryCodes: Sensitive(List.filled(30, 'ABCD-EFGH-IJKL').join('\n')),
          ),
        );
        await v.go(t, '/vault/item/$id');
        expect(t.takeException(), isNull);
        await tapKey(t, 'vault-reveal-password');
        await t.drag(find.byType(Scrollable).last, const Offset(0, -3000));
        await t.pump(const Duration(milliseconds: 300));
        expect(t.takeException(), isNull);
        v.lock();
      });

      testWidgets('form with the keyboard open', (t) async {
        final v = await open(t, scale);
        await v.go(t, '/vault/new');
        t.view.viewInsets = const FakeViewPadding(bottom: 300);
        await t.pumpAndSettle();
        await enter(t, 'vault-form-title', title120);
        await enter(t, 'vault-form-password', 'p' * 200);
        await enter(t, 'vault-form-url', 'https://example.com/${'a' * 1980}');
        expect(t.takeException(), isNull);
        t.view.resetViewInsets();
        v.lock();
      });

      testWidgets('import with 50 proposals', (t) async {
        final v = await open(t, scale);
        await v.go(t, '/vault/import');
        final text = [for (var i = 0; i < 50; i++) '${title120.substring(0, 60)} $i\nuser: u$i\npass: TEST-ONLY-pw-$i']
            .join('\n\n');
        await enter(t, 'vault-import-paste', text);
        await tapKey(t, 'vault-import-find');
        await t.drag(find.byType(Scrollable).last, const Offset(0, 20000));
        await t.pump(const Duration(milliseconds: 300));
        expect(find.byKey(const ValueKey('vault-proposal-0')), findsOneWidget);
        await t.drag(find.byType(Scrollable).last, const Offset(0, -20000));
        await t.pump(const Duration(milliseconds: 300));
        expect(t.takeException(), isNull);
        v.lock();
      });

      testWidgets('settings', (t) async {
        final v = await open(t, scale);
        await v.go(t, '/vault/settings');
        expect(t.takeException(), isNull);
        await t.drag(find.byType(Scrollable).last, const Offset(0, -3000));
        await t.pump(const Duration(milliseconds: 300));
        expect(t.takeException(), isNull);
        v.lock();
      });
    });
  }

  testWidgets('in Arabic the revealed password renders left to right', (t) async {
    final v = await open(t, 1.0, locale: 'ar');
    final id = await add(
      t,
      v,
      VaultItemInput(title: 'فيسبوك', category: 'social', password: const Sensitive('TEST-ONLY-pw-ltr')),
    );
    await v.go(t, '/vault/item/$id');
    await tapKey(t, 'vault-reveal-password');
    expect(t.widget<Text>(find.text('TEST-ONLY-pw-ltr')).textDirection, TextDirection.ltr);
    v.lock();
  });
}
