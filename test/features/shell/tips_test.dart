import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/features/finance/data/buckets_repository.dart';
import 'package:life_manager/features/finance/data/budgets_repository.dart';
import 'package:life_manager/features/finance/data/rates_repository.dart';
import 'package:life_manager/features/finance/data/transactions_repository.dart';
import 'package:life_manager/features/shell/tips.dart';

import '../../helpers/finance_fixtures.dart';

void main() {
  late FinanceFixture f;
  final now = DateTime(2026, 10, 23, 12);

  setUp(() async => f = await financeFixture());
  tearDown(() => f.db.close());

  Future<int> bucket(String key) async =>
      (await (f.db.select(f.db.buckets)..where((b) => b.systemKey.equals(key))).getSingle()).id;

  test('nothing to say → all clear', () async {
    final tips = await computeTips(f.db, now);
    expect(tips.first.kind, TipKind.allClear);
  });

  test('a budget at 80% or more is the tip, named without amounts', () async {
    await BudgetsRepository(
      f.db,
      RatesRepository(f.db),
    ).create(categoryId: f.cat('transport'), amountMinor: 100000, currencyCode: 'IQD');
    await TransactionsRepository(f.db).addSimple(
      type: 'expense',
      accountId: f.personalIqd,
      amountMinor: 85000,
      categoryId: f.cat('transport'),
      occurredAt: now.toUtc(),
    );
    final tip = (await computeTips(f.db, now)).first;
    expect(tip.kind, TipKind.budgetNear);
    expect(tip.args.join(' '), isNot(contains('85')));
    expect(tip.args.single, isNotEmpty);
  });

  test('Emergency below its target', () async {
    await BucketsRepository(f.db, RatesRepository(f.db)).setTarget(await bucket('emergency'), 1000000);
    final tips = await computeTips(f.db, now);
    expect(tips.first.kind, TipKind.emergencyLow);
  });
}
