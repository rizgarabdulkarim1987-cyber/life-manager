import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/db/app_database.dart';
import '../../../core/money/conversion.dart';
import '../../../core/money/money.dart';
import '../domain/alerts.dart';
import '../domain/buckets_math.dart';
import '../domain/budgets_math.dart';
import '../domain/installments.dart';
import 'accounts_repository.dart';
import 'buckets_repository.dart';
import 'budgets_repository.dart';
import 'debts_repository.dart';
import 'categories_repository.dart';
import 'rates_repository.dart';
import 'transactions_repository.dart';
import 'workspaces_repository.dart';

final workspacesRepositoryProvider = Provider<WorkspacesRepository>(
  (ref) => WorkspacesRepository(ref.watch(appDatabaseProvider)),
);

final accountsRepositoryProvider = Provider<AccountsRepository>(
  (ref) => AccountsRepository(ref.watch(appDatabaseProvider)),
);

final transactionsRepositoryProvider = Provider<TransactionsRepository>(
  (ref) => TransactionsRepository(ref.watch(appDatabaseProvider)),
);

final workspacesProvider = StreamProvider<List<Workspace>>((ref) => ref.watch(workspacesRepositoryProvider).watchAll());

final accountsProvider = StreamProvider<List<Account>>((ref) => ref.watch(accountsRepositoryProvider).watchAll());

final balancesProvider = StreamProvider<Map<int, Money>>(
  (ref) => ref.watch(accountsRepositoryProvider).watchBalances(),
);

final ratesRepositoryProvider = Provider<RatesRepository>((ref) => RatesRepository(ref.watch(appDatabaseProvider)));

final categoriesRepositoryProvider = Provider<CategoriesRepository>(
  (ref) => CategoriesRepository(ref.watch(appDatabaseProvider)),
);

final categoriesProvider = StreamProvider<List<Category>>((ref) => ref.watch(categoriesRepositoryProvider).watch());

/// Refreshes when rates change, so consolidated figures follow a new rate.
final ratesHistoryProvider = StreamProvider<List<RateValue>>(
  (ref) => ref.watch(ratesRepositoryProvider).watchHistory('USD', 'IQD'),
);

/// All balances in the base currency for today (spec §10.2).
final consolidatedProvider = FutureProvider<Consolidated>((ref) async {
  final balances = await ref.watch(balancesProvider.future);
  final settings = await ref.watch(settingsProvider.future);
  ref.watch(ratesHistoryProvider);
  return ref
      .watch(ratesRepositoryProvider)
      .consolidate(balances, base: settings.baseCurrency, day: DateTime.now().toUtc());
});

final bucketsRepositoryProvider = Provider<BucketsRepository>(
  (ref) => BucketsRepository(ref.watch(appDatabaseProvider), ref.watch(ratesRepositoryProvider)),
);

final bucketsProvider = StreamProvider<List<Bucket>>((ref) => ref.watch(bucketsRepositoryProvider).watch());

/// Bucket figures for the current month; recomputed when balances change.
final bucketStatusProvider = FutureProvider<List<BucketStatus>>((ref) async {
  ref.watch(balancesProvider);
  ref.watch(bucketsProvider);
  ref.watch(ratesHistoryProvider);
  return ref.watch(bucketsRepositoryProvider).status(DateTime.now());
});

final budgetsRepositoryProvider = Provider<BudgetsRepository>(
  (ref) => BudgetsRepository(ref.watch(appDatabaseProvider), ref.watch(ratesRepositoryProvider)),
);

final debtsRepositoryProvider = Provider<DebtsRepository>((ref) => DebtsRepository(ref.watch(appDatabaseProvider)));

final budgetsProvider = StreamProvider<List<Budget>>((ref) => ref.watch(budgetsRepositoryProvider).watch());

final budgetProgressProvider = FutureProvider<List<BudgetProgress>>((ref) async {
  ref.watch(balancesProvider);
  ref.watch(budgetsProvider);
  ref.watch(ratesHistoryProvider);
  return ref.watch(budgetsRepositoryProvider).progress(DateTime.now());
});

final debtSummariesProvider = StreamProvider<List<DebtSummary>>(
  (ref) => ref.watch(debtsRepositoryProvider).watchSummaries(),
);

final financeAlertsProvider = FutureProvider<List<FinanceAlert>>((ref) async {
  final buckets = await ref.watch(bucketStatusProvider.future);
  final budgets = await ref.watch(budgetProgressProvider.future);
  final debts = await ref.watch(debtSummariesProvider.future);
  final settings = await ref.watch(settingsProvider.future);
  final unallocated = settings.unallocatedIncomeAlert
      ? await ref.watch(bucketsRepositoryProvider).unallocatedIncomeCount(DateTime.now())
      : 0;
  return evaluateAlerts(
    buckets: buckets,
    budgets: budgets,
    debts: debts,
    unallocatedIncomeCount: unallocated,
    unallocatedAlertOn: settings.unallocatedIncomeAlert,
    now: DateTime.now(),
  );
});
