import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/db/app_database.dart';
import '../../../core/money/conversion.dart';
import '../../../core/money/money.dart';
import '../domain/alerts.dart';
import '../domain/buckets_math.dart';
import '../domain/budgets_math.dart';
import '../domain/installments.dart';
import '../domain/reports.dart';
import 'accounts_repository.dart';
import 'buckets_repository.dart';
import 'budgets_repository.dart';
import 'debts_repository.dart';
import 'categories_repository.dart';
import 'rates_repository.dart';
import 'reports_query.dart';
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

final reportsQueryProvider = Provider<ReportsQuery>(
  (ref) => ReportsQuery(ref.watch(appDatabaseProvider), ref.watch(ratesRepositoryProvider)),
);

/// Everything booked before [to], reloaded whenever money or rates change.
final reportDataProvider = FutureProvider.family<ReportData, DateTime>((ref, to) async {
  ref.watch(balancesProvider);
  ref.watch(ratesHistoryProvider);
  return ref.watch(reportsQueryProvider).load(to: to);
});

/// This month's income, expense and surplus in the base currency.
final monthSummaryProvider = FutureProvider<ReportResult<IncomeExpense>>((ref) async {
  ref.watch(balancesProvider);
  ref.watch(ratesHistoryProvider);
  final settings = await ref.watch(settingsProvider.future);
  final now = DateTime.now();
  final from = DateTime(now.year, now.month);
  final to = DateTime(now.year, now.month + 1);
  final data = await ref.watch(reportsQueryProvider).load(to: to);
  final r = incomeVsExpense(
    data.transactions,
    ReportScope(from: from, to: to, currency: settings.baseCurrency),
    Period.month,
    data.context,
  );
  return ReportResult(r.data.single, skippedCount: r.skippedCount, missingRates: r.missingRates);
});

/// Income and expense for the last six months (this one included) in the base currency, oldest first.
final lastSixMonthsProvider = FutureProvider<ReportResult<List<IncomeExpense>>>((ref) async {
  ref.watch(balancesProvider);
  ref.watch(ratesHistoryProvider);
  final settings = await ref.watch(settingsProvider.future);
  final now = DateTime.now();
  final from = DateTime(now.year, now.month - 5);
  final to = DateTime(now.year, now.month + 1);
  final data = await ref.watch(reportsQueryProvider).load(to: to);
  return incomeVsExpense(
    data.transactions,
    ReportScope(from: from, to: to, currency: settings.baseCurrency),
    Period.month,
    data.context,
  );
});

/// Active accounts grouped under their workspace, in workspace order.
final accountGroupsProvider = Provider<AsyncValue<List<(Workspace, List<Account>)>>>((ref) {
  final ws = ref.watch(workspacesProvider);
  final accounts = ref.watch(accountsProvider);
  if (ws.value == null || accounts.value == null) {
    return ws.hasError ? AsyncError(ws.error!, ws.stackTrace!) : const AsyncLoading();
  }
  return AsyncData([
    for (final w in ws.value!)
      if (accounts.value!.any((a) => a.workspaceId == w.id))
        (w, accounts.value!.where((a) => a.workspaceId == w.id).toList()),
  ]);
});

/// Debt id → direction, for signing debt payments in lists.
final debtDirectionsProvider = Provider<Map<int, String>>(
  (ref) => {
    for (final d in ref.watch(debtSummariesProvider).value ?? const <DebtSummary>[]) d.debt.id: d.debt.direction,
  },
);

/// Bucket figures for any month (the screen's month switcher). Keyed by the month's first day.
final bucketStatusForMonthProvider = FutureProvider.family<List<BucketStatus>, DateTime>((ref, month) async {
  ref.watch(balancesProvider);
  ref.watch(bucketsProvider);
  ref.watch(ratesHistoryProvider);
  return ref.watch(bucketsRepositoryProvider).status(month);
});

final budgetProgressForMonthProvider = FutureProvider.family<List<BudgetProgress>, DateTime>((ref, month) async {
  ref.watch(balancesProvider);
  ref.watch(budgetsProvider);
  ref.watch(ratesHistoryProvider);
  return ref.watch(budgetsRepositoryProvider).progress(month);
});

/// Open and settled debts, for the detail screen (a settled debt stays readable).
final allDebtSummariesProvider = StreamProvider<List<DebtSummary>>(
  (ref) => ref.watch(debtsRepositoryProvider).watchSummaries(includeClosed: true),
);

final debtPaymentsProvider = StreamProvider.family<List<Transaction>, int>(
  (ref, debtId) => ref.watch(debtsRepositoryProvider).watchPayments(debtId),
);

final debtInstallmentsProvider = FutureProvider.family<List<InstallmentState>, int>((ref, debtId) async {
  await ref.watch(debtPaymentsProvider(debtId).future);
  return ref.watch(debtsRepositoryProvider).installments(debtId);
});
