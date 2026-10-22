import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/db/app_database.dart';
import '../../../core/money/money.dart';
import 'accounts_repository.dart';
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

final balancesProvider = StreamProvider<Map<int, Money>>((ref) => ref.watch(accountsRepositoryProvider).watchBalances());
