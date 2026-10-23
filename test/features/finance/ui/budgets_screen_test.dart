import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/core/theme/tokens.dart';
import 'package:life_manager/features/finance/data/budgets_repository.dart';
import 'package:life_manager/features/finance/data/rates_repository.dart';

import '../../../helpers/app_harness.dart';
import '../../../helpers/finance_ui.dart';

void main() {
  Future<int> foodId(c) async {
    final db = dbOf(c);
    return (await (db.select(db.categories)..where((x) => x.systemKey.equals('food'))).getSingle()).id;
  }

  testWidgets('budget at 100% shows remaining and the danger colour', (t) async {
    final c = await pumpApp(t, locale: 'en');
    final db = dbOf(c);
    final p = await accountId(c, 'Personal', 'IQD');
    final food = await foodId(c);
    final id = await BudgetsRepository(
      db,
      RatesRepository(db),
    ).create(categoryId: food, amountMinor: 100000, currencyCode: 'IQD');
    await txRepo(c).addSimple(
      type: 'expense',
      accountId: p,
      amountMinor: 120000,
      occurredAt: DateTime.now().toUtc(),
      categoryId: food,
    );
    await pushRoute(t, c, '/finance/budgets');
    expect(find.text('−20,000 IQD'), findsOneWidget);
    final bar = find.byKey(ValueKey('budget-bar-$id'));
    expect(t.widget<LinearProgressIndicator>(bar).color, Theme.of(t.element(bar)).extension<AppTokens>()!.danger);
  });

  testWidgets('add a budget for a category', (t) async {
    final c = await pumpApp(t, locale: 'en');
    final food = await foodId(c);
    await pushRoute(t, c, '/finance/budgets');
    await t.tap(find.byKey(const ValueKey('add-budget')));
    await settle(t);
    await t.tap(find.byKey(const ValueKey('budget-category')));
    await settle(t);
    await t.tap(find.text('Food').last);
    await settle(t);
    await t.enterText(find.byKey(const ValueKey('budget-amount')), '250000');
    await settle(t);
    await t.tap(find.byKey(const ValueKey('budget-save')));
    await settle(t);
    final b = (await t.runAsync(() => dbOf(c).select(dbOf(c).budgets).get()))!.single;
    expect((b.categoryId, b.amountMinor, b.currencyCode), (food, 250000, 'IQD'));
  });
}
