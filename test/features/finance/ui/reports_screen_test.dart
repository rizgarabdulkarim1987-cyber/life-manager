import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/features/finance/ui/widgets/money_text.dart';

import '../../../helpers/app_harness.dart';
import '../../../helpers/finance_ui.dart';

MoneyText _total(WidgetTester t, String key) =>
    t.widget<MoneyText>(find.descendant(of: find.byKey(ValueKey(key)), matching: find.byType(MoneyText)).first);

void main() {
  testWidgets('switching to USD scope relabels totals and shows skipped note when no rate', (t) async {
    final c = await pumpApp(t, locale: 'en');
    final p = await accountId(c, 'Personal', 'IQD');
    await txRepo(c).addSimple(type: 'income', accountId: p, amountMinor: 250000, occurredAt: DateTime.now().toUtc());
    await pushRoute(t, c, '/finance/reports');
    expect(_total(t, 'total-income').m.currency, 'IQD');
    expect(_total(t, 'total-income').m.minor, 250000);
    expect(find.byKey(const ValueKey('report-skipped')), findsNothing);

    await t.tap(find.byKey(const ValueKey('report-currency')));
    await settle(t);
    await t.tap(find.byKey(const ValueKey('option-USD')));
    await settle(t);
    expect(_total(t, 'total-income').m.currency, 'USD');
    expect(_total(t, 'total-income').m.minor, 0);
    expect(find.byKey(const ValueKey('report-skipped')), findsOneWidget);
  });

  testWidgets('data table toggle lists the same numbers as the chart', (t) async {
    final c = await pumpApp(t, locale: 'en');
    final p = await accountId(c, 'Personal', 'IQD');
    final now = DateTime.now().toUtc();
    await txRepo(c).addSimple(type: 'income', accountId: p, amountMinor: 250000, occurredAt: now);
    await txRepo(c).addSimple(type: 'expense', accountId: p, amountMinor: 100000, occurredAt: now);
    await pushRoute(t, c, '/finance/reports');

    final chart = t.widget<BarChart>(find.byType(BarChart));
    final rods = chart.data.barGroups.single.barRods;
    expect(rods.map((r) => r.toY), [250000, 100000]);

    await t.tap(find.byKey(const ValueKey('table-toggle')));
    await settle(t);
    final table = find.byKey(const ValueKey('report-table'));
    expect(table, findsOneWidget);
    expect(find.descendant(of: table, matching: find.text('250,000 IQD')), findsOneWidget);
    expect(find.descendant(of: table, matching: find.text('100,000 IQD')), findsOneWidget);
    expect(find.descendant(of: table, matching: find.text('150,000 IQD')), findsOneWidget);
  });

  testWidgets('every tab renders in Arabic at phone width with huge amounts', (t) async {
    t.view.physicalSize = const Size(360, 760);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final c = await pumpApp(t);
    final p = await accountId(c, 'Personal', 'IQD');
    final now = DateTime.now().toUtc();
    await txRepo(c).addSimple(type: 'income', accountId: p, amountMinor: 987654321012, occurredAt: now);
    await txRepo(c).addSimple(
      type: 'expense',
      accountId: p,
      amountMinor: 123456789012,
      occurredAt: now,
      description: 'وصف طويل جداً ' * 10,
    );
    await pushRoute(t, c, '/finance/reports');
    for (var i = 0; i < 7; i++) {
      await t.tap(find.byType(Tab).at(i));
      await settle(t);
      await t.tap(find.byKey(const ValueKey('table-toggle')).hitTestable(), warnIfMissed: false);
      await settle(t);
    }
    expect(t.takeException(), isNull);
  });
}
