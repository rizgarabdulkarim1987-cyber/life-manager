import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/features/lock/lock_controller.dart';

import '../../helpers/app_harness.dart';
import '../../helpers/fakes.dart';

void main() {
  testWidgets('shell shows four destinations and the composer', (t) async {
    await pumpApp(t);
    for (var i = 0; i < 4; i++) {
      expect(find.byKey(ValueKey('nav-$i')), findsOneWidget);
    }
    expect(find.byKey(const ValueKey('composer-field')), findsWidgets);
  });

  testWidgets('in Arabic, Home is the rightmost destination', (t) async {
    await pumpApp(t);
    final home = t.getCenter(find.byKey(const ValueKey('nav-0')));
    final projects = t.getCenter(find.byKey(const ValueKey('nav-3')));
    expect(home.dx, greaterThan(projects.dx));
  });

  testWidgets('the Projects tab opens the projects screen', (t) async {
    await pumpApp(t, locale: 'en');
    await t.tap(find.byKey(const ValueKey('nav-3')));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('projects-empty')), findsOneWidget);
  });

  testWidgets('settings icon opens settings', (t) async {
    await pumpApp(t, locale: 'en');
    await t.tap(find.byKey(const ValueKey('open-settings')));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('settings-screen')), findsOneWidget);
  });

  testWidgets('locked app shows the lock screen over the shell', (t) async {
    final c = await pumpApp(t, bio: FakeBiometric(result: false));
    c.read(lockControllerProvider.notifier).lockNow();
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('lock-screen')), findsOneWidget);
    expect(find.byKey(const ValueKey('nav-0')), findsNothing);
  });

  testWidgets('home fits a small phone in Kurdish', (t) async {
    t.view.physicalSize = const Size(320 * 3, 568 * 3);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    await pumpApp(t, locale: 'ckb');
    expect(t.takeException(), isNull);
  });
}
