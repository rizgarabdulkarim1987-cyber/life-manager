import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/core/theme/tokens.dart';
import 'package:life_manager/features/finance/data/buckets_repository.dart';
import 'package:life_manager/features/finance/data/rates_repository.dart';

import '../../../helpers/app_harness.dart';
import '../../../helpers/finance_ui.dart';

void main() {
  Future<List<int>> bucketIds(c) async {
    final db = dbOf(c);
    return [
      for (final b in await (db.select(db.buckets)..orderBy([(b) => OrderingTerm.asc(b.sortOrder)])).get()) b.id,
    ];
  }

  testWidgets('percentages 70/20/5 keep Save disabled; 70/20/10 enables it', (t) async {
    final c = await pumpApp(t, locale: 'en');
    final ids = await bucketIds(c);
    await pushRoute(t, c, '/finance/buckets');
    expect(find.byKey(const ValueKey('buckets-unconfirmed')), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('edit-percentages')));
    await settle(t);
    // Nothing is suggested before the owner sets their own split.
    for (final id in ids) {
      expect(t.widget<TextField>(find.byKey(ValueKey('pct-$id'))).controller!.text, isEmpty);
    }
    await t.enterText(find.byKey(ValueKey('pct-${ids[0]}')), '70');
    await t.enterText(find.byKey(ValueKey('pct-${ids[1]}')), '20');
    await t.enterText(find.byKey(ValueKey('pct-${ids[2]}')), '5');
    await settle(t);
    expect(saveEnabled(t, 'pct-save'), isFalse);
    await t.enterText(find.byKey(ValueKey('pct-${ids[2]}')), '10');
    await settle(t);
    expect(saveEnabled(t, 'pct-save'), isTrue);
    await t.tap(find.byKey(const ValueKey('pct-save')));
    await settle(t);
    final s = await t.runAsync(() => dbOf(c).select(dbOf(c).appSettingsTable).getSingle());
    expect(s!.bucketsConfirmed, isTrue);
    expect(find.byKey(const ValueKey('buckets-unconfirmed')), findsNothing);
  });

  testWidgets('at 85% spent the Expenses bar uses the warning colour', (t) async {
    final c = await pumpApp(t, locale: 'en');
    final db = dbOf(c);
    final p = await accountId(c, 'Personal', 'IQD');
    final now = DateTime.now().toUtc();
    final income = await txRepo(c).addSimple(type: 'income', accountId: p, amountMinor: 100000, occurredAt: now);
    final ids = await bucketIds(c);
    await BucketsRepository(db, RatesRepository(db)).allocate(income, {ids[0]: 100000});
    await txRepo(c).addSimple(type: 'expense', accountId: p, amountMinor: 85000, occurredAt: now);
    await pushRoute(t, c, '/finance/buckets');
    final bar = find.byKey(ValueKey('bucket-bar-${ids[0]}'));
    final indicator = t.widget<LinearProgressIndicator>(bar);
    expect(indicator.color, Theme.of(t.element(bar)).extension<AppTokens>()!.warning);
  });

  testWidgets('before confirming, the allocation toggle asks for percentages first', (t) async {
    final c = await pumpApp(t, locale: 'en');
    await pushRoute(t, c, '/finance/tx/new?type=income');
    await t.enterText(find.byKey(const ValueKey('amount')), '1000');
    await settle(t);
    await revealInForm(t, find.byKey(const ValueKey('tx-allocate')));
    await t.tap(find.byKey(const ValueKey('tx-allocate')));
    await settle(t);
    expect(find.byKey(const ValueKey('pct-save')), findsOneWidget);
    expect(t.widget<SwitchListTile>(find.byKey(const ValueKey('tx-allocate'))).value, isFalse);
  });
}
