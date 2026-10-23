import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/features/finance/data/budgets_repository.dart';
import 'package:life_manager/features/finance/data/debts_repository.dart';
import 'package:life_manager/features/finance/data/rates_repository.dart';
import 'package:life_manager/core/security/money_privacy.dart';

import '../helpers/app_harness.dart';
import '../helpers/finance_ui.dart';

/// Review Focus 1: no figure shows anywhere until the owner taps the eye.
void main() {
  testWidgets('finance screens show no amount until revealed', (t) async {
    final c = await pumpApp(t, locale: 'en', revealMoney: false);
    final acc = await accountId(c, 'Personal', 'IQD');
    await dbWrite(
      t,
      () =>
          txRepo(c).addSimple(type: 'expense', accountId: acc, amountMinor: 987654, occurredAt: DateTime.now().toUtc()),
    );
    final amount = find.textContaining(RegExp(r'987|654'));
    for (final route in [
      '/finance',
      '/finance/accounts',
      '/finance/accounts/$acc',
      '/finance/history',
      '/finance/buckets',
      '/finance/debts',
      '/finance/reports',
      '/home',
    ]) {
      await pushRoute(t, c, route);
      expect(amount, findsNothing, reason: route);
    }
    await pushRoute(t, c, '/finance/history');
    c.read(moneyRevealedProvider.notifier).toggle();
    await settle(t);
    expect(amount, findsWidgets, reason: 'the test must see the figure once revealed');
  });

  testWidgets('debt detail, budgets and the report charts hide their figures too', (t) async {
    t.view.physicalSize = const Size(800, 1600);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final c = await pumpApp(t, locale: 'en', revealMoney: false);
    final acc = await accountId(c, 'Personal', 'IQD');
    final ws = await workspaceId(c, 'Personal');
    final debtId = await DebtsRepository(dbOf(c)).create(
      direction: 'owed_by_me',
      counterparty: 'Ahmed',
      workspaceId: ws,
      principalMinor: 1234567,
      currencyCode: 'IQD',
      startDate: DateTime.now(),
    );
    final repo = txRepo(c);
    await repo.addSimple(
      type: 'expense',
      accountId: acc,
      amountMinor: 765432,
      bucketTag: 'emergency',
      occurredAt: DateTime.now().toUtc(),
    );
    await repo.addSimple(type: 'expense', accountId: acc, amountMinor: 888000, occurredAt: DateTime.now().toUtc());
    await BudgetsRepository(
      dbOf(c),
      RatesRepository(dbOf(c)),
    ).create(workspaceId: ws, amountMinor: 5550000, currencyCode: 'IQD');
    await settle(t);
    final figure = find.textContaining(RegExp(r'\d,\d{3}|\d+(\.\d+)?\s?[KM]'));
    for (final route in ['/finance/debts/$debtId', '/finance/budgets', '/finance/reports']) {
      await pushRoute(t, c, route);
      expect(figure, findsNothing, reason: route);
    }
    for (final tab in ['Balance over time', 'Buckets', 'Income vs expenses']) {
      final label = find.text(tab);
      if (label.evaluate().isEmpty) continue;
      await t.ensureVisible(label.first);
      await t.tap(label.first);
      await settle(t);
      expect(figure, findsNothing, reason: 'reports tab $tab');
    }
  });
}
