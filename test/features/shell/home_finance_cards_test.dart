import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/features/finance/ui/widgets/money_text.dart';

import '../../helpers/app_harness.dart';
import '../../helpers/finance_ui.dart';

void main() {
  void tall(WidgetTester t, {double w = 400}) {
    t.view.physicalSize = Size(w, 3000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
  }

  testWidgets('Home shows this month, the six-month chart with exact values and the Expenses bucket bar', (t) async {
    tall(t);
    final c = await pumpApp(t, locale: 'en');
    final p = await accountId(c, 'Personal', 'IQD');
    final now = DateTime.now();
    await txRepo(c).addSimple(type: 'income', accountId: p, amountMinor: 900000, occurredAt: now.toUtc());
    await txRepo(c).addSimple(type: 'expense', accountId: p, amountMinor: 250000, occurredAt: now.toUtc());
    await txRepo(c).addSimple(
      type: 'expense',
      accountId: p,
      amountMinor: 70000,
      occurredAt: DateTime(now.year, now.month - 2, 15, 12).toUtc(),
    );
    await settle(t);

    MoneyText money(String key) =>
        t.widget<MoneyText>(find.descendant(of: find.byKey(ValueKey(key)), matching: find.byType(MoneyText)).first);
    expect(money('home-month-income').m.minor, 900000);
    expect(money('home-month-expense').m.minor, 250000);
    expect(money('home-month-surplus').m.minor, 650000);

    final groups = t.widget<BarChart>(find.byType(BarChart)).data.barGroups;
    expect(groups, hasLength(6));
    expect(
      [for (final g in groups) g.barRods.map((r) => r.toY).toList()],
      [
        [0, 0],
        [0, 0],
        [0, 0],
        [0, 70000],
        [0, 0],
        [900000, 250000],
      ],
    );

    final expensesBar = find.byWidgetPredicate(
      (w) => w.key is ValueKey<String> && (w.key! as ValueKey<String>).value.startsWith('home-bucket-bar-'),
    );
    expect(expensesBar, findsWidgets);
    expect(find.byKey(const ValueKey('home-consolidated')), findsOneWidget);
  });

  testWidgets('Home fits 320 px in Kurdish with a 999,999,999,999 IQD month', (t) async {
    t.view.physicalSize = const Size(320, 2400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final c = await pumpApp(t, locale: 'ckb');
    final p = await accountId(c, 'Personal', 'IQD');
    await txRepo(c)
        .addSimple(type: 'income', accountId: p, amountMinor: 999999999999, occurredAt: DateTime.now().toUtc());
    await settle(t);
    expect(find.byKey(const ValueKey('home-month-income')), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
