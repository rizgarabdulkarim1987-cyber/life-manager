import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/features/finance/data/accounts_repository.dart';
import 'package:life_manager/features/finance/data/rates_repository.dart';
import 'package:life_manager/features/finance/data/reports_query.dart';
import 'package:life_manager/features/finance/data/transactions_repository.dart';
import 'package:life_manager/features/finance/domain/reports.dart';

import '../../../helpers/finance_fixtures.dart';

void main() {
  test('balanceOverTime from the db matches AccountsRepository.balanceOf', () async {
    final f = await financeFixture();
    addTearDown(f.db.close);
    final tx = TransactionsRepository(f.db);
    final rates = RatesRepository(f.db);
    await rates.setRate(base: 'USD', quote: 'IQD', rateE6: 1310000000, effectiveFrom: DateTime.utc(2026, 1, 1));
    await f.setOpening(f.personalIqd, 5000);
    await tx.addSimple(
      type: 'income',
      accountId: f.personalIqd,
      amountMinor: 100000,
      occurredAt: DateTime.utc(2026, 9, 2, 9),
    );
    await tx.addTransfer(
      fromAccountId: f.personalIqd,
      toAccountId: f.personalUsd,
      amountMinor: 13100,
      toAmountMinor: 1000,
      rateE6: 1310000000,
      occurredAt: DateTime.utc(2026, 9, 3, 9),
    );
    final data = await ReportsQuery(f.db, rates).load(to: DateTime(2026, 10));
    final s = balanceOverTime(
      data.transactions,
      data.openingByAccount,
      {f.personalIqd, f.personalUsd},
      ReportScope(from: DateTime(2026, 9, 1), to: DateTime(2026, 10), currency: 'IQD'),
      data.context,
    );
    final acc = AccountsRepository(f.db);
    final iqd = (await acc.balanceOf(f.personalIqd)).minor;
    final usd = (await acc.balanceOf(f.personalUsd)).minor;
    expect(s.data.points.last.$2, iqd + usd * 131 ~/ 10);
    expect(s.data.points.first.$2, 5000);
  });
}
