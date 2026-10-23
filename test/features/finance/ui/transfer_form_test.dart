import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/app_harness.dart';
import '../../../helpers/finance_ui.dart';

void main() {
  testWidgets('IQD → USD: 131000 and 100.00 show rate 1,310 and save both legs', (t) async {
    final c = await pumpApp(t, locale: 'en');
    final iqd = await accountId(c, 'Personal', 'IQD');
    final usd = await accountId(c, 'Personal', 'USD');
    await pushRoute(t, c, '/finance/transfer/new');
    await pickAccount(t, 'tr-from', iqd);
    await pickAccount(t, 'tr-to', usd);
    await t.enterText(find.byKey(const ValueKey('tr-amount')), '131000');
    await t.enterText(find.byKey(const ValueKey('tr-to-amount')), '100.00');
    await settle(t);
    final rate = t.widget<TextField>(find.byKey(const ValueKey('tr-rate')));
    expect(rate.controller!.text, '1,310');
    expect(rate.readOnly, isTrue);
    await t.tap(find.byKey(const ValueKey('tr-save')));
    await settle(t);
    final row = (await t.runAsync(() => dbOf(c).select(dbOf(c).transactions).get()))!.single;
    expect(
      (row.type, row.accountId, row.amountMinor, row.toAccountId, row.toAmountMinor, row.rateE6),
      ('transfer', iqd, 131000, usd, 10000, 1310000000),
    );
  });

  testWidgets('rate and one amount fill the other', (t) async {
    final c = await pumpApp(t, locale: 'en');
    await pushRoute(t, c, '/finance/transfer/new');
    await pickAccount(t, 'tr-from', await accountId(c, 'Personal', 'USD'));
    await pickAccount(t, 'tr-to', await accountId(c, 'Personal', 'IQD'));
    await t.enterText(find.byKey(const ValueKey('tr-amount')), '50');
    await t.enterText(find.byKey(const ValueKey('tr-rate')), '1310');
    await settle(t);
    final to = t.widget<TextField>(find.byKey(const ValueKey('tr-to-amount')));
    expect(to.controller!.text, '65500');
    expect(to.readOnly, isTrue);
  });

  testWidgets('owner draw switch shows only across workspaces', (t) async {
    final c = await pumpApp(t, locale: 'en');
    await pushRoute(t, c, '/finance/transfer/new');
    await pickAccount(t, 'tr-from', await accountId(c, 'Personal', 'IQD'));
    await pickAccount(t, 'tr-to', await accountId(c, 'Personal', 'USD'));
    expect(find.byKey(const ValueKey('tr-owner-draw')), findsNothing);
    await pickAccount(t, 'tr-from', await accountId(c, 'Buzzify', 'IQD'));
    await pickAccount(t, 'tr-to', await accountId(c, 'Personal', 'IQD'));
    expect(find.byKey(const ValueKey('tr-owner-draw')), findsOneWidget);
  });

  testWidgets('same-currency transfer stores one amount', (t) async {
    final c = await pumpApp(t, locale: 'en');
    final b = await accountId(c, 'Buzzify', 'IQD');
    final p = await accountId(c, 'Personal', 'IQD');
    await pushRoute(t, c, '/finance/transfer/new');
    await pickAccount(t, 'tr-from', b);
    await pickAccount(t, 'tr-to', p);
    expect(find.byKey(const ValueKey('tr-to-amount')), findsNothing);
    await t.enterText(find.byKey(const ValueKey('tr-amount')), '500000');
    await t.tap(find.byKey(const ValueKey('tr-owner-draw')));
    await settle(t);
    await t.tap(find.byKey(const ValueKey('tr-save')));
    await settle(t);
    final row = (await t.runAsync(() => dbOf(c).select(dbOf(c).transactions).get()))!.single;
    expect((row.amountMinor, row.transferKind), (500000, 'owner_draw'));
  });
}
