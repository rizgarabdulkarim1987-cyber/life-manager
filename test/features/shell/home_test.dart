import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/features/capture/ui/composer.dart';
import 'package:life_manager/features/finance/ui/widgets/money_text.dart';

import '../../helpers/app_harness.dart';
import '../../helpers/finance_ui.dart';

void main() {
  testWidgets('home shows no money digits', (t) async {
    final c = await pumpApp(t, locale: 'en');
    final p = await accountId(c, 'Personal', 'IQD');
    await txRepo(c).addSimple(
      type: 'expense',
      accountId: p,
      amountMinor: 250000,
      description: 'lunch',
      occurredAt: DateTime.now().toUtc(),
    );
    await settle(t);
    expect(find.byType(MoneyText), findsNothing);
    expect(find.textContaining('250'), findsNothing);
    expect(find.text('lunch'), findsOneWidget, reason: 'the entry shows by its words');
  });

  testWidgets('home shows the large composer and no second one', (t) async {
    await pumpApp(t, locale: 'en');
    expect(find.byType(Composer), findsOneWidget);
    expect(t.widget<Composer>(find.byType(Composer)).large, isTrue);
    expect(find.byKey(const ValueKey('home-tip')), findsOneWidget);
  });

  testWidgets('recent entry swipe deletes with undo', (t) async {
    final c = await pumpApp(t, locale: 'en');
    final p = await accountId(c, 'Personal', 'IQD');
    final id = await txRepo(c).addSimple(
      type: 'expense',
      accountId: p,
      amountMinor: 40000,
      description: 'taxi',
      occurredAt: DateTime.now().toUtc(),
    );
    await settle(t);
    final row = find.byKey(ValueKey('recent-$id'));
    await t.scrollUntilVisible(row, 200, scrollable: find.byType(Scrollable).first);
    await t.drag(row, const Offset(-600, 0));
    await settle(t);
    expect(await t.runAsync(() => txRepo(c).get(id)), isNull);
    await t.tap(find.text('Undo'));
    await settle(t);
    expect((await t.runAsync(() => txRepo(c).get(id)))!.amountMinor, 40000);
  });
}
