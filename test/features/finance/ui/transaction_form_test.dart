import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/features/finance/data/buckets_repository.dart';
import 'package:life_manager/features/finance/data/rates_repository.dart';
import 'package:life_manager/features/settings/settings_repository.dart';

import '../../../helpers/app_harness.dart';
import '../../../helpers/finance_ui.dart';

void main() {
  testWidgets('typing ٢٥٠٠٠ in an IQD expense stores 25000', (t) async {
    final c = await pumpApp(t, locale: 'ar');
    final p = await accountId(c, 'Personal', 'IQD');
    await pushRoute(t, c, '/finance/tx/new?type=expense');
    await pickAccount(t, 'tx-account', p);
    await t.enterText(find.byKey(const ValueKey('amount')), '٢٥٠٠٠');
    await settle(t);
    await t.tap(find.byKey(const ValueKey('tx-save')));
    await settle(t);
    final row = (await t.runAsync(() => dbOf(c).select(dbOf(c).transactions).get()))!.single;
    expect((row.type, row.amountMinor, row.accountId, row.currencyCode), ('expense', 25000, p, 'IQD'));
  });

  Future<List<int>> bucketIds(c) async {
    final db = dbOf(c);
    return [
      for (final b in await (db.select(db.buckets)..orderBy([(b) => OrderingTerm.asc(b.sortOrder)])).get()) b.id,
    ];
  }

  Future<void> usdIncomeWithAllocation(WidgetTester t, c) async {
    await SettingsRepository(dbOf(c)).setBucketsConfirmed();
    await RatesRepository(dbOf(c))
        .setRate(base: 'USD', quote: 'IQD', rateE6: 1310000000, effectiveFrom: DateTime.utc(2026, 1, 1));
    await pushRoute(t, c, '/finance/tx/new?type=income');
    await pickAccount(t, 'tx-account', await accountId(c, 'Personal', 'USD'));
    await t.enterText(find.byKey(const ValueKey('amount')), '100.00');
    await settle(t);
    await revealInForm(t, find.byKey(const ValueKey('tx-allocate')));
    // On by default for a new income once the percentages are confirmed.
    expect(t.widget<SwitchListTile>(find.byKey(const ValueKey('tx-allocate'))).value, isTrue);
  }

  testWidgets('switching the split off keeps it off', (t) async {
    final c = await pumpApp(t, locale: 'en');
    await usdIncomeWithAllocation(t, c);
    await t.tap(find.byKey(const ValueKey('tx-allocate')));
    await settle(t);
    await t.enterText(find.byKey(const ValueKey('amount')), '120.00');
    await settle(t);
    expect(t.widget<SwitchListTile>(find.byKey(const ValueKey('tx-allocate'))).value, isFalse);
  });

  testWidgets('USD income with allocation pre-fills 91700 / 26200 / 13100 IQD and saves three rows', (t) async {
    final c = await pumpApp(t, locale: 'en');
    await usdIncomeWithAllocation(t, c);
    final ids = await bucketIds(c);
    String fieldText(int id) => t.widget<TextField>(find.byKey(ValueKey('alloc-$id'))).controller!.text;
    expect([for (final id in ids) fieldText(id)], ['91700', '26200', '13100']);
    await t.tap(find.byKey(const ValueKey('tx-save')));
    await settle(t);
    final rows = (await t.runAsync(() => dbOf(c).select(dbOf(c).bucketAllocations).get()))!;
    expect(rows.map((r) => r.amountBaseMinor).toList()..sort(), [13100, 26200, 91700]);
  });

  testWidgets('allocation above the total disables Save', (t) async {
    final c = await pumpApp(t, locale: 'en');
    await usdIncomeWithAllocation(t, c);
    final ids = await bucketIds(c);
    expect(saveEnabled(t, 'tx-save'), isTrue);
    await t.enterText(find.byKey(ValueKey('alloc-${ids.first}')), '200000');
    await settle(t);
    expect(saveEnabled(t, 'tx-save'), isFalse);
  });

  testWidgets('allocation is disabled with a hint when a foreign income has no rate', (t) async {
    final c = await pumpApp(t, locale: 'en');
    await pushRoute(t, c, '/finance/tx/new?type=income');
    await pickAccount(t, 'tx-account', await accountId(c, 'Personal', 'USD'));
    await t.enterText(find.byKey(const ValueKey('amount')), '10');
    await settle(t);
    await revealInForm(t, find.byKey(const ValueKey('tx-allocate')));
    final sw = t.widget<SwitchListTile>(find.byKey(const ValueKey('tx-allocate')));
    expect(sw.onChanged, isNull);
  });

  testWidgets('editing an allocated income asks to clear its allocations', (t) async {
    final c = await pumpApp(t, locale: 'en');
    final p = await accountId(c, 'Personal', 'IQD');
    final id = await txRepo(c)
        .addSimple(type: 'income', accountId: p, amountMinor: 100000, occurredAt: DateTime.now().toUtc());
    final ids = await bucketIds(c);
    await BucketsRepository(dbOf(c), RatesRepository(dbOf(c))).allocate(id, {ids.first: 100000});
    await pushRoute(t, c, '/finance/tx/$id');
    await t.enterText(find.byKey(const ValueKey('amount')), '50000');
    await settle(t);
    await t.tap(find.byKey(const ValueKey('tx-save')));
    await settle(t);
    expect(find.byKey(const ValueKey('clear-allocations-dialog')), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('clear-allocations')));
    await settle(t);
    expect((await t.runAsync(() => txRepo(c).get(id)))!.amountMinor, 50000);
    expect(await t.runAsync(() => dbOf(c).select(dbOf(c).bucketAllocations).get()), isEmpty);
  });

  testWidgets('an open expense deletes from its own screen, with undo', (t) async {
    final c = await pumpApp(t, locale: 'en');
    final acc = await accountId(c, 'Personal', 'IQD');
    final id = await txRepo(c).addSimple(
      type: 'expense',
      accountId: acc,
      amountMinor: 4000,
      occurredAt: DateTime.now().toUtc(),
      description: 'Taxi',
    );
    await pushRoute(t, c, '/finance/tx/$id');
    await t.tap(find.byKey(const ValueKey('tx-delete')));
    await settle(t);
    expect(find.byKey(const ValueKey('tx-save')), findsNothing, reason: 'the form closes');
    expect(await txRepo(c).get(id), isNull);
    await t.tap(find.text('Undo'));
    await settle(t);
    expect(await txRepo(c).get(id), isNotNull);
  });

  testWidgets('a new transaction has no delete button', (t) async {
    final c = await pumpApp(t, locale: 'en');
    await pushRoute(t, c, '/finance/tx/new?type=expense');
    expect(find.byKey(const ValueKey('tx-delete')), findsNothing);
  });

  testWidgets('expense form fits 320 px in Kurdish', (t) async {
    t.view.physicalSize = const Size(320 * 3, 640 * 3);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    final c = await pumpApp(t, locale: 'ckb');
    await pushRoute(t, c, '/finance/tx/new?type=income');
    expect(t.takeException(), isNull);
  });
}
