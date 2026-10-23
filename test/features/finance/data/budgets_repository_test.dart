import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/features/finance/data/budgets_repository.dart';
import 'package:life_manager/features/finance/data/rates_repository.dart';
import 'package:life_manager/features/finance/data/transactions_repository.dart';

import '../../../helpers/finance_fixtures.dart';

void main() {
  late FinanceFixture f;
  late BudgetsRepository budgets;
  late TransactionsRepository tx;
  late RatesRepository rates;
  final oct = DateTime(2026, 10, 5);

  setUp(() async {
    f = await financeFixture();
    rates = RatesRepository(f.db);
    budgets = BudgetsRepository(f.db, rates);
    tx = TransactionsRepository(f.db);
  });
  tearDown(() => f.db.close());

  Future<void> spend(int minor, {int? account, String cat = 'food', DateTime? at}) => tx.addSimple(
    type: 'expense',
    accountId: account ?? f.personalIqd,
    amountMinor: minor,
    occurredAt: at ?? oct,
    categoryId: f.cat(cat),
  );

  test('budget per category: 80000 of 100000 → 8000 bp, remaining 20000', () async {
    await budgets.create(categoryId: f.cat('food'), amountMinor: 100000, currencyCode: 'IQD');
    await spend(50000);
    await spend(30000, account: f.buzzIqd);
    await spend(99999, cat: 'transport');
    await spend(70000, at: DateTime(2026, 9, 30));
    final p = (await budgets.progress(DateTime(2026, 10))).single;
    expect((p.actualMinor, p.remainingMinor, p.percentBp), (80000, 20000, 8000));
  });

  test('budget per workspace in USD converts IQD expenses at their date rate', () async {
    await rates.setRate(base: 'USD', quote: 'IQD', rateE6: 1310000000, effectiveFrom: DateTime.utc(2026, 1, 1));
    await budgets.create(workspaceId: f.buzzWs, amountMinor: 10000, currencyCode: 'USD');
    await spend(131000, account: f.buzzIqd);
    await spend(2500, account: f.buzzUsd);
    await spend(500000);
    final p = (await budgets.progress(DateTime(2026, 10))).single;
    expect((p.actualMinor, p.percentBp), (12500, 12500));
    expect(p.missingRates, isEmpty);
  });

  test('budget skips a currency with no rate and lists it', () async {
    await budgets.create(workspaceId: f.personalWs, amountMinor: 100000, currencyCode: 'IQD');
    await spend(1000);
    await spend(500, account: f.personalUsd);
    final p = (await budgets.progress(DateTime(2026, 10))).single;
    expect(p.actualMinor, 1000);
    expect(p.missingRates, ['USD']);
  });

  test('refund reduces budget actual', () async {
    await budgets.create(categoryId: f.cat('food'), amountMinor: 100000, currencyCode: 'IQD');
    await spend(50000);
    await tx.addSimple(
      type: 'refund',
      accountId: f.personalIqd,
      amountMinor: 10000,
      occurredAt: oct,
      categoryId: f.cat('food'),
    );
    expect((await budgets.progress(DateTime(2026, 10))).single.actualMinor, 40000);
  });

  test('a budget needs a category or a workspace and a positive amount', () async {
    await expectLater(budgets.create(amountMinor: 1, currencyCode: 'IQD'), throwsArgumentError);
    await expectLater(
      budgets.create(categoryId: f.cat('food'), amountMinor: 0, currencyCode: 'IQD'),
      throwsArgumentError,
    );
  });

  test('archived budgets are not listed', () async {
    final id = await budgets.create(categoryId: f.cat('food'), amountMinor: 1, currencyCode: 'IQD');
    await budgets.archive(id);
    expect(await budgets.progress(DateTime(2026, 10)), isEmpty);
  });
}
