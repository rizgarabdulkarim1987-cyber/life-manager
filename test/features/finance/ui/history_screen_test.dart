import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/features/finance/data/accounts_repository.dart';

import '../../../helpers/app_harness.dart';
import '../../../helpers/finance_ui.dart';

void main() {
  Future<(int personal, int buzz, int foodTx)> seed(c) async {
    final p = await accountId(c, 'Personal', 'IQD');
    final b = await accountId(c, 'Buzzify', 'IQD');
    final now = DateTime.now().toUtc();
    final food = await txRepo(c)
        .addSimple(type: 'expense', accountId: p, amountMinor: 5000, occurredAt: now, description: 'أكل');
    await txRepo(c).addSimple(type: 'expense', accountId: b, amountMinor: 70000, occurredAt: now, description: 'Ads');
    return (p, b, food);
  }

  Future<void> openHistory(WidgetTester t) async {
    await openFinance(t);
    final tile = find.byKey(const ValueKey('open-history'));
    await t.scrollUntilVisible(tile, 200, scrollable: find.byType(Scrollable).first);
    await t.tap(tile);
    await t.pumpAndSettle();
  }

  testWidgets('filter by workspace Buzzify hides Personal rows', (t) async {
    final c = await pumpApp(t, locale: 'en');
    await seed(c);
    await openHistory(t);
    expect(find.text('أكل'), findsOneWidget);
    expect(find.text('Ads'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('filter-workspace')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(ValueKey('option-${await workspaceId(c, 'Buzzify')}')));
    await t.pumpAndSettle();
    expect(find.text('أكل'), findsNothing);
    expect(find.text('Ads'), findsOneWidget);
  });

  testWidgets('searching «اكل» matches «أكل»', (t) async {
    final c = await pumpApp(t);
    await seed(c);
    await openHistory(t);
    await t.enterText(find.byKey(const ValueKey('history-search')), 'اكل');
    await t.pumpAndSettle();
    expect(find.text('أكل'), findsOneWidget);
    expect(find.text('Ads'), findsNothing);
  });

  testWidgets('day header shows the day total', (t) async {
    final c = await pumpApp(t, locale: 'en');
    await seed(c);
    await openHistory(t);
    expect(find.text('−75,000 IQD'), findsOneWidget);
  });

  testWidgets('delete then Undo restores the balance', (t) async {
    final c = await pumpApp(t, locale: 'en');
    final (p, _, food) = await seed(c);
    final accounts = AccountsRepository(dbOf(c));
    final before = (await accounts.balanceOf(p)).minor;
    await openHistory(t);
    await t.drag(find.byKey(ValueKey('tx-$food')), const Offset(-600, 0));
    await t.pumpAndSettle();
    expect(find.text('أكل'), findsNothing);
    expect((await accounts.balanceOf(p)).minor, before + 5000);
    await t.tap(find.text('Undo'));
    await t.pumpAndSettle();
    expect((await accounts.balanceOf(p)).minor, before);
    expect(find.text('أكل'), findsOneWidget);
  });

  testWidgets('history fits 320 px in Kurdish', (t) async {
    t.view.physicalSize = const Size(320 * 3, 640 * 3);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    final c = await pumpApp(t, locale: 'ckb');
    final p = await accountId(c, 'Personal', 'IQD');
    await txRepo(c).addSimple(
      type: 'income',
      accountId: p,
      amountMinor: 999999999999,
      occurredAt: DateTime.now().toUtc(),
      description: 'ب' * 80,
    );
    await openHistory(t);
    expect(t.takeException(), isNull);
  });
}
