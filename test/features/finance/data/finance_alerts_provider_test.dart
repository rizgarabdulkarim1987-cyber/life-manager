import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/providers.dart';
import 'package:life_manager/features/finance/data/finance_providers.dart';
import 'package:life_manager/features/finance/domain/alerts.dart';

import '../../../helpers/finance_fixtures.dart';

void main() {
  test('alerts include a budget at 100% and an overdue debt', () async {
    final f = await financeFixture();
    final c = ProviderContainer(overrides: [appDatabaseProvider.overrideWithValue(f.db)]);
    addTearDown(() async {
      c.dispose();
      await f.db.close();
    });
    final budgetId = await c
        .read(budgetsRepositoryProvider)
        .create(categoryId: f.cat('food'), amountMinor: 1000, currencyCode: 'IQD');
    await c
        .read(transactionsRepositoryProvider)
        .addSimple(
          type: 'expense',
          accountId: f.personalIqd,
          amountMinor: 1000,
          occurredAt: DateTime.now().toUtc(),
          categoryId: f.cat('food'),
        );
    final debtId = await c
        .read(debtsRepositoryProvider)
        .create(
          direction: 'owed_to_me',
          counterparty: 'Sara',
          workspaceId: f.personalWs,
          principalMinor: 5000,
          currencyCode: 'IQD',
          startDate: DateTime.utc(2019),
          dueDate: DateTime.utc(2020, 1, 1),
        );
    final alerts = await c.read(financeAlertsProvider.future);
    expect(alerts.whereType<BudgetUsed>().single.budgetId, budgetId);
    expect(alerts.whereType<BudgetUsed>().single.percentBp, 10000);
    expect(alerts.whereType<DebtOverdue>().single.debtId, debtId);
  });
}
