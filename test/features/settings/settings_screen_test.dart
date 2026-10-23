import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/providers.dart';
import 'package:life_manager/features/lock/lock_controller.dart';
import 'package:life_manager/features/lock/pin_service.dart';

import '../../helpers/app_harness.dart';

void main() {
  Future<void> openSettings(WidgetTester t) async {
    await t.tap(find.byKey(const ValueKey('open-settings')));
    await t.pumpAndSettle();
  }

  testWidgets('switching language to English updates the app live', (t) async {
    final c = await pumpApp(t);
    await openSettings(t);
    await t.tap(find.byKey(const ValueKey('locale-en')));
    await t.pumpAndSettle();
    expect((await c.read(settingsRepositoryProvider).get()).localeCode, 'en');
    expect(find.text('Settings'), findsWidgets);
    await t.pageBack();
    await t.pumpAndSettle();
    expect(find.text('Home'), findsOneWidget);
  });

  testWidgets('theme choice changes brightness', (t) async {
    await pumpApp(t, locale: 'en');
    await openSettings(t);
    expect(Theme.of(t.element(find.byKey(const ValueKey('settings-screen')))).brightness, Brightness.dark);
    await t.scrollUntilVisible(find.byKey(const ValueKey('theme-light')), 100);
    await t.ensureVisible(find.byKey(const ValueKey('theme-light')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('theme-light')));
    await t.pumpAndSettle();
    expect(Theme.of(t.element(find.byKey(const ValueKey('settings-screen')))).brightness, Brightness.light);
  });

  testWidgets('biometric switch is disabled when unavailable', (t) async {
    await pumpApp(t, locale: 'en');
    await openSettings(t);
    await t.scrollUntilVisible(find.byKey(const ValueKey('bio-switch')), 100);
    await t.ensureVisible(find.byKey(const ValueKey('bio-switch')));
    await t.pumpAndSettle();
    final tile = t.widget<SwitchListTile>(find.byKey(const ValueKey('bio-switch')));
    expect(tile.onChanged, isNull);
    expect(find.text('No fingerprint or face unlock is set up on this phone'), findsOneWidget);
  });

  testWidgets('lock timeout can be changed', (t) async {
    final c = await pumpApp(t, locale: 'en');
    await openSettings(t);
    await t.scrollUntilVisible(find.byKey(const ValueKey('lock-timeout')), 100);
    await t.ensureVisible(find.byKey(const ValueKey('lock-timeout')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('lock-timeout')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('timeout-900')));
    await t.pumpAndSettle();
    expect((await c.read(settingsRepositoryProvider).get()).lockTimeoutSeconds, 900);
  });

  testWidgets('never backed up shows a warning subtitle', (t) async {
    await pumpApp(t, locale: 'en');
    await openSettings(t);
    await t.scrollUntilVisible(find.text('Never backed up'), 100);
    await t.ensureVisible(find.text('Never backed up'));
    await t.pumpAndSettle();
    expect(find.text('Never backed up'), findsOneWidget);
  });

  testWidgets('change PIN needs the current PIN', (t) async {
    final c = await pumpApp(t, locale: 'en');
    await openSettings(t);
    await t.scrollUntilVisible(find.byKey(const ValueKey('change-pin')), 100);
    await t.ensureVisible(find.byKey(const ValueKey('change-pin')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('change-pin')));
    await t.pumpAndSettle();
    Future<void> enter(String pin) async {
      for (final d in pin.split('')) {
        await t.tap(find.byKey(ValueKey('pin-key-$d')));
        await t.pump();
      }
      await t.pumpAndSettle();
    }

    await enter('123456');
    await enter('111111');
    await enter('111111');
    expect(find.text('PIN changed'), findsOneWidget);
    expect(await c.read(pinServiceProvider).verify('111111'), isA<PinOk>());
  });

  testWidgets('settings fits a small phone in Kurdish', (t) async {
    t.view.physicalSize = const Size(320 * 3, 568 * 3);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    await pumpApp(t, locale: 'ckb');
    await openSettings(t);
    expect(t.takeException(), isNull);
    await t.drag(find.byType(ListView), const Offset(0, -2000));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  });
}
