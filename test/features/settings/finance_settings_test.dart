import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/app_harness.dart';
import '../../helpers/finance_ui.dart';

void main() {
  testWidgets('entering rate ١٣١٠ stores 1310000000 today and lists it first', (t) async {
    final c = await pumpApp(t, locale: 'en');
    await pushRoute(t, c, '/settings/finance');
    await t.enterText(find.byKey(const ValueKey('rate-field')), '١٣١٠');
    await settle(t);
    await t.tap(find.byKey(const ValueKey('rate-save')));
    await settle(t);
    final rows = (await t.runAsync(() => dbOf(c).select(dbOf(c).exchangeRates).get()))!;
    final now = DateTime.now();
    expect(rows.single.rateE6, 1310000000);
    expect(rows.single.effectiveFrom.toUtc(), DateTime.utc(now.year, now.month, now.day));
    expect(
      find.descendant(of: find.byKey(const ValueKey('rate-history-0')), matching: find.textContaining('1,310')),
      findsOneWidget,
    );
  });

  testWidgets('the unallocated income alert is off by default and can be turned on', (t) async {
    final c = await pumpApp(t, locale: 'en');
    await pushRoute(t, c, '/settings/finance');
    final sw = find.byKey(const ValueKey('unallocated-alert'));
    await t.scrollUntilVisible(sw, 200, scrollable: find.byType(Scrollable).last);
    expect(t.widget<SwitchListTile>(sw).value, isFalse);
    await t.tap(sw);
    await settle(t);
    final s = await t.runAsync(() => dbOf(c).select(dbOf(c).appSettingsTable).getSingle());
    expect(s!.unallocatedIncomeAlert, isTrue);
  });

  testWidgets('settings lists the finance links', (t) async {
    final c = await pumpApp(t, locale: 'en');
    await pushRoute(t, c, '/settings');
    for (final key in ['settings-finance', 'settings-categories', 'settings-workspaces']) {
      await t.scrollUntilVisible(find.byKey(ValueKey(key)), 200, scrollable: find.byType(Scrollable).last);
      expect(find.byKey(ValueKey(key)), findsOneWidget);
    }
  });
}
