import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/core/db/app_database.dart';
import 'package:life_manager/features/finance/data/rates_repository.dart';
import 'package:life_manager/features/finance/ui/widgets/how_converted_sheet.dart';

import '../../../helpers/app_harness.dart';
import '../../../helpers/finance_ui.dart';

Finder inCard(String key, Finder f) => find.descendant(of: find.byKey(ValueKey(key)), matching: f);

void main() {
  testWidgets('month tiles show income, expense and surplus in the base currency', (t) async {
    final c = await pumpApp(t, locale: 'en');
    final p = await accountId(c, 'Personal', 'IQD');
    final now = DateTime.now().toUtc();
    await txRepo(c).addSimple(type: 'income', accountId: p, amountMinor: 1500000, occurredAt: now);
    await txRepo(c).addSimple(type: 'expense', accountId: p, amountMinor: 250000, occurredAt: now);
    await openFinance(t);
    expect(inCard('month-income', find.text('1,500,000 IQD')), findsOneWidget);
    expect(inCard('month-expense', find.text('250,000 IQD')), findsOneWidget);
    expect(inCard('month-surplus', find.text('+1,250,000 IQD')), findsOneWidget);
  });

  testWidgets('without a rate the consolidated card offers "set a rate" and shows subtotals', (t) async {
    final c = await pumpApp(t, locale: 'en');
    final usd = await accountId(c, 'Personal', 'USD');
    final iqd = await accountId(c, 'Personal', 'IQD');
    await (dbOf(c).update(
      dbOf(c).accounts,
    )..where((a) => a.id.equals(usd))).write(const AccountsCompanion(openingBalanceMinor: Value(1000)));
    await (dbOf(c).update(
      dbOf(c).accounts,
    )..where((a) => a.id.equals(iqd))).write(const AccountsCompanion(openingBalanceMinor: Value(50000)));
    await openFinance(t);
    expect(inCard('consolidated-card', find.byKey(const ValueKey('set-rate'))), findsOneWidget);
    expect(inCard('consolidated-card', find.text(r'$10.00')), findsOneWidget);
    expect(inCard('consolidated-card', find.text('50,000 IQD')), findsOneWidget);
  });

  testWidgets('with a rate, tapping the consolidated total explains the conversion', (t) async {
    final c = await pumpApp(t, locale: 'en');
    final usd = await accountId(c, 'Personal', 'USD');
    await (dbOf(c).update(
      dbOf(c).accounts,
    )..where((a) => a.id.equals(usd))).write(const AccountsCompanion(openingBalanceMinor: Value(1000)));
    await RatesRepository(dbOf(c))
        .setRate(base: 'USD', quote: 'IQD', rateE6: 1310000000, effectiveFrom: DateTime.utc(2026, 1, 15));
    await openFinance(t);
    expect(inCard('consolidated-card', find.text('13,100 IQD')), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('consolidated-card')));
    await t.pumpAndSettle();
    expect(find.byType(HowConvertedSheet), findsOneWidget);
    expect(inCard('how-converted', find.textContaining('1,310')), findsWidgets);
    expect(inCard('how-converted', find.textContaining('Jan 15, 2026')), findsWidgets);
  });

  testWidgets('in Arabic a negative balance reads as one LTR run', (t) async {
    final c = await pumpApp(t);
    final p = await accountId(c, 'Personal', 'IQD');
    await txRepo(c).addSimple(type: 'expense', accountId: p, amountMinor: 25000, occurredAt: DateTime.now().toUtc());
    await openFinance(t);
    final money = find.text('−25,000 د.ع');
    await t.scrollUntilVisible(money.first, 200, scrollable: find.byType(Scrollable).first);
    expect(money, findsWidgets);
    final text = t.widget<Text>(money.first);
    expect(text.textDirection, TextDirection.ltr);
  });

  testWidgets('worst case at 320 px in Kurdish: 80-character name, 999,999,999,999 IQD', (t) async {
    t.view.physicalSize = const Size(320 * 3, 640 * 3);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    final c = await pumpApp(t, locale: 'ckb');
    final p = await accountId(c, 'Personal', 'IQD');
    await (dbOf(c).update(dbOf(c).accounts)..where((a) => a.id.equals(p))).write(
      AccountsCompanion(
        name: Value('ب' * 40 + 'Buzzify Studio Account Name Long Text '),
        openingBalanceMinor: const Value(999999999999),
      ),
    );
    await txRepo(c)
        .addSimple(type: 'income', accountId: p, amountMinor: 999999999999, occurredAt: DateTime.now().toUtc());
    await openFinance(t);
    expect(t.takeException(), isNull);
    await pushRoute(t, c, '/finance/accounts');
    expect(t.takeException(), isNull);
    await t.tap(find.byKey(ValueKey('account-row-$p')));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  });

  testWidgets('adjust balance records the difference as an adjustment', (t) async {
    final c = await pumpApp(t, locale: 'en');
    final p = await accountId(c, 'Personal', 'IQD');
    await openFinance(t);
    await pushRoute(t, c, '/finance/accounts');
    await t.tap(find.byKey(ValueKey('account-row-$p')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('adjust-balance')));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const ValueKey('adjust-amount')), '٤٠٬٠٠٠');
    await t.tap(find.byKey(const ValueKey('adjust-save')));
    await t.pumpAndSettle();
    final rows = await dbOf(c).select(dbOf(c).transactions).get();
    expect(rows.single.type, 'adjustment');
    expect(rows.single.amountMinor, 40000);
  });

  testWidgets('add account with a currency picker', (t) async {
    final c = await pumpApp(t, locale: 'en');
    await openFinance(t);
    await pushRoute(t, c, '/finance/accounts');
    await t.tap(find.byKey(const ValueKey('add-account')));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const ValueKey('account-name')), 'Bank EUR');
    await t.tap(find.byKey(const ValueKey('account-currency')));
    await t.pumpAndSettle();
    await t.tap(find.text('EUR').last);
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('account-save')));
    await t.pumpAndSettle();
    final a = await (dbOf(c).select(dbOf(c).accounts)..where((a) => a.name.equals('Bank EUR'))).getSingle();
    expect(a.currencyCode, 'EUR');
  });
}
