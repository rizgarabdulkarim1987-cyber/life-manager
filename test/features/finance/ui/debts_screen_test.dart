import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/features/finance/data/debts_repository.dart';

import '../../../helpers/app_harness.dart';
import '../../../helpers/finance_ui.dart';

void main() {
  testWidgets('in Arabic "owed to me" stays first in reading order', (t) async {
    final c = await pumpApp(t);
    await pushRoute(t, c, '/finance/debts');
    final toMe = t.getCenter(find.byKey(const ValueKey('tab-owed-to-me')));
    final byMe = t.getCenter(find.byKey(const ValueKey('tab-owed-by-me')));
    expect(toMe.dx, greaterThan(byMe.dx));
  });

  testWidgets('a repayment equal to the remaining closes the debt', (t) async {
    final c = await pumpApp(t, locale: 'en');
    final p = await accountId(c, 'Personal', 'IQD');
    final ws = await workspaceId(c, 'Personal');
    final id = await DebtsRepository(dbOf(c)).create(
      direction: 'owed_to_me',
      counterparty: 'Ahmed',
      workspaceId: ws,
      principalMinor: 300000,
      currencyCode: 'IQD',
      startDate: DateTime.now().toUtc(),
      recordPrincipalFromAccountId: p,
    );
    await pushRoute(t, c, '/finance/debts');
    expect(find.text('Ahmed'), findsOneWidget);
    await t.tap(find.byKey(ValueKey('debt-$id')));
    await settle(t);
    await t.tap(find.byKey(const ValueKey('record-repayment')));
    await settle(t);
    await pickAccount(t, 'repay-account', p);
    await t.enterText(find.byKey(const ValueKey('repay-amount')), '300000');
    await settle(t);
    await t.tap(find.byKey(const ValueKey('repay-save')));
    await settle(t);
    await t.pageBack();
    await settle(t);
    expect(find.text('Ahmed'), findsNothing);
  });

  testWidgets('add a debt with installments', (t) async {
    final c = await pumpApp(t, locale: 'en');
    await pushRoute(t, c, '/finance/debts');
    await t.tap(find.byKey(const ValueKey('add-debt')));
    await settle(t);
    await t.enterText(find.byKey(const ValueKey('debt-counterparty')), 'Bank loan');
    await t.enterText(find.byKey(const ValueKey('debt-amount')), '1000000');
    await t.enterText(find.byKey(const ValueKey('debt-installments')), '3');
    await settle(t);
    await t.ensureVisible(find.byKey(const ValueKey('debt-save')));
    await settle(t);
    await t.tap(find.byKey(const ValueKey('debt-save')));
    await settle(t);
    final rows = (await t.runAsync(() => dbOf(c).select(dbOf(c).installments).get()))!;
    expect(rows.map((r) => r.amountMinor), [333333, 333333, 333334]);
  });
}
