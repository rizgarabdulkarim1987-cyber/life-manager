import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/providers.dart';

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
    expect(Theme.of(t.element(find.byKey(const ValueKey('settings-screen')))).brightness, Brightness.light);
    await t.scrollUntilVisible(find.byKey(const ValueKey('theme-dark')), 100);
    await t.ensureVisible(find.byKey(const ValueKey('theme-dark')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('theme-dark')));
    await t.pumpAndSettle();
    expect(Theme.of(t.element(find.byKey(const ValueKey('settings-screen')))).brightness, Brightness.dark);
  });

  testWidgets('lock timeout can be changed', (t) async {
    final c = await pumpApp(t, locale: 'en');
    await openSettings(t);
    await t.scrollUntilVisible(find.byKey(const ValueKey('lock-timeout')), 100);
    await t.ensureVisible(find.byKey(const ValueKey('lock-timeout')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('lock-timeout')));
    await t.pumpAndSettle();
    for (final s in [0, 30, 60, 300, 900]) {
      expect(find.byKey(ValueKey('timeout-$s')), findsOneWidget);
    }
    await t.tap(find.byKey(const ValueKey('timeout-30')));
    await t.pumpAndSettle();
    expect((await c.read(settingsRepositoryProvider).get()).lockTimeoutSeconds, 30);
  });

  testWidgets('the lock has no PIN to change and explains face unlock', (t) async {
    await pumpApp(t, locale: 'en');
    await openSettings(t);
    await t.scrollUntilVisible(find.byKey(const ValueKey('face-unlock-note')), 100);
    expect(find.byKey(const ValueKey('change-pin')), findsNothing);
    expect(find.byKey(const ValueKey('bio-switch')), findsNothing);
  });

  testWidgets('never backed up shows a warning subtitle', (t) async {
    await pumpApp(t, locale: 'en');
    await openSettings(t);
    await t.scrollUntilVisible(find.text('Never backed up'), 100);
    await t.ensureVisible(find.text('Never backed up'));
    await t.pumpAndSettle();
    expect(find.text('Never backed up'), findsOneWidget);
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
