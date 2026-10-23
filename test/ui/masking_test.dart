import 'package:flutter_test/flutter_test.dart';
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
}
