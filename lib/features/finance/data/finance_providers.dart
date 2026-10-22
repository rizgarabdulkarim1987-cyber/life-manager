import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/db/app_database.dart';
import '../../../core/money/conversion.dart';
import '../../../core/money/money.dart';
import 'accounts_repository.dart';
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
