import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/l10n/ckb_fallback_localizations.dart';
import '../features/backup/backup_screen.dart';
import '../features/capture/domain/proposal.dart';
import '../features/finance/ui/account_detail_screen.dart';
import '../features/finance/ui/accounts_screen.dart';
import '../features/finance/ui/buckets_screen.dart';
import '../features/finance/ui/budgets_screen.dart';
import '../features/finance/ui/debt_detail_screen.dart';
import '../features/finance/ui/debts_screen.dart';
import '../features/finance/ui/finance_overview_screen.dart';
import '../features/finance/ui/history_screen.dart';
import '../features/finance/ui/reports_screen.dart';
import '../features/finance/ui/transaction_form_screen.dart';
import '../features/finance/ui/transfer_form_screen.dart';
import '../features/settings/categories_screen.dart';
import '../features/settings/finance_settings_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/settings/workspaces_screen.dart';
import '../features/setup/setup_flow.dart';
import '../features/setup/splash_screen.dart';
import '../features/shell/home_screen.dart';
import '../features/shell/placeholder_screen.dart';
import '../features/shell/shell_scaffold.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final router = buildRouter();
  ref.onDispose(router.dispose);
  return router;
});

final _rootKey = GlobalKey<NavigatorState>();

GoRouter buildRouter() => GoRouter(
  navigatorKey: _rootKey,
  initialLocation: '/splash',
  routes: [
    GoRoute(
      path: '/splash',
      builder: (context, _) => SplashScreen(onResolved: (done) => context.go(done ? '/home' : '/setup')),
    ),
    GoRoute(
      path: '/setup',
      builder: (context, _) => SetupFlow(onDone: () => context.go('/home')),
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => ShellScaffold(shell: shell),
      branches: [
        StatefulShellBranch(
          routes: [GoRoute(path: '/home', builder: (_, _) => const HomeScreen())],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/finance',
              builder: (_, _) => const FinanceOverviewScreen(),
              routes: [
                // Forms cover the shell (no bottom bar or mic over the Save button).
                GoRoute(
                  path: 'tx/new',
                  parentNavigatorKey: _rootKey,
                  builder: (_, state) {
                    final draft = state.extra is TransactionDraft ? state.extra! as TransactionDraft : null;
                    final type = state.uri.queryParameters['type'];
                    return TransactionFormScreen(
                      initial: type == null || draft?.type != null
                          ? draft
                          : TransactionDraft(
                              type: type,
                              accountId: draft?.accountId,
                              amountMinor: draft?.amountMinor,
                              categoryId: draft?.categoryId,
                              occurredAt: draft?.occurredAt,
                              description: draft?.description,
                              bucketTag: draft?.bucketTag,
                            ),
                    );
                  },
                ),
                GoRoute(
                  path: 'tx/:id',
                  parentNavigatorKey: _rootKey,
                  builder: (_, state) => TransactionFormScreen(editId: int.parse(state.pathParameters['id']!)),
                ),
                GoRoute(
                  path: 'transfer/new',
                  parentNavigatorKey: _rootKey,
                  builder: (_, state) =>
                      TransferFormScreen(initial: state.extra is TransferDraft ? state.extra! as TransferDraft : null),
                ),
                GoRoute(
                  path: 'transfer/:id',
                  parentNavigatorKey: _rootKey,
                  builder: (_, state) => TransferFormScreen(editId: int.parse(state.pathParameters['id']!)),
                ),
                GoRoute(
                  path: 'accounts',
                  builder: (_, _) => const AccountsScreen(),
                  routes: [
                    GoRoute(
                      path: ':id',
                      builder: (_, state) => AccountDetailScreen(accountId: int.parse(state.pathParameters['id']!)),
                    ),
                  ],
                ),
                GoRoute(path: 'reports', builder: (_, _) => const ReportsScreen()),
                GoRoute(path: 'buckets', builder: (_, _) => const BucketsScreen()),
                GoRoute(path: 'budgets', builder: (_, _) => const BudgetsScreen()),
                GoRoute(
                  path: 'debts',
                  builder: (_, _) => const DebtsScreen(),
                  routes: [
                    GoRoute(
                      path: ':id',
                      builder: (_, state) => DebtDetailScreen(debtId: int.parse(state.pathParameters['id']!)),
                    ),
                  ],
                ),
                GoRoute(
                  path: 'history',
                  builder: (_, state) {
                    final q = state.uri.queryParameters;
                    return HistoryScreen(
                      accountId: int.tryParse(q['account'] ?? ''),
                      workspaceId: int.tryParse(q['workspace'] ?? ''),
                      categoryId: int.tryParse(q['category'] ?? ''),
                      type: q['type'],
                    );
                  },
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/tasks',
              builder: (context, _) =>
                  PlaceholderScreen(title: context.l10n.navTasks, phase: 4, icon: Icons.task_alt_outlined),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/vault',
              builder: (context, _) =>
                  PlaceholderScreen(title: context.l10n.navVault, phase: 3, icon: Icons.shield_outlined),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: '/settings',
      builder: (_, _) => const SettingsScreen(),
      routes: [
        GoRoute(path: 'backup', builder: (_, _) => const BackupScreen()),
        GoRoute(path: 'finance', builder: (_, _) => const FinanceSettingsScreen()),
        GoRoute(path: 'categories', builder: (_, _) => const CategoriesScreen()),
        GoRoute(path: 'workspaces', builder: (_, _) => const WorkspacesScreen()),
      ],
    ),
  ],
);
