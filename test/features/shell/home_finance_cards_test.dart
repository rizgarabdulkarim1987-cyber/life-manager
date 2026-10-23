import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/app_harness.dart';
import '../../helpers/finance_ui.dart';

void main() {
  void tall(WidgetTester t, {double w = 400}) {
    t.view.physicalSize = Size(w, 3000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
  }

  testWidgets('Finance shows the six-month chart with exact values and the Expenses bucket bar', (t) async {
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
    await openFinance(t);

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
      (w) => w.key is ValueKey<String> && (w.key! as ValueKey<String>).value.startsWith('fin-bucket-bar-'),
    );
    expect(expensesBar, findsWidgets);
  });

  testWidgets('Finance fits 320 px in Kurdish with a 999,999,999,999 IQD month', (t) async {
    t.view.physicalSize = const Size(320, 2400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final c = await pumpApp(t, locale: 'ckb');
    final p = await accountId(c, 'Personal', 'IQD');
    await txRepo(c)
        .addSimple(type: 'income', accountId: p, amountMinor: 999999999999, occurredAt: DateTime.now().toUtc());
    await openFinance(t);
    expect(find.byType(BarChart), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
