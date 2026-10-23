import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/backup/backup_screen.dart';
import '../features/capture/domain/proposal.dart';
import '../features/capture/ui/capture_review_screen.dart';
import '../features/capture/ui/inbox_screen.dart';
import '../features/finance/ui/account_detail_screen.dart';
import '../features/finance/ui/accounts_screen.dart';
import '../features/finance/ui/buckets_screen.dart';
import '../features/finance/ui/budgets_screen.dart';
import '../features/finance/ui/debt_detail_screen.dart';
import '../features/finance/ui/debts_screen.dart';
import '../features/finance/ui/finance_overview_screen.dart';
import '../features/finance/import/ui/import_wizard_screen.dart';
import '../features/finance/ui/history_screen.dart';
import '../features/finance/ui/reports_screen.dart';
import '../features/finance/ui/transaction_form_screen.dart';
import '../features/finance/ui/transfer_form_screen.dart';
import '../features/settings/ai_settings_screen.dart';
import '../features/settings/categories_screen.dart';
import '../features/settings/finance_settings_screen.dart';
import '../core/security/money_privacy.dart';
import '../features/lock/sensitive_gate.dart';
import '../features/settings/settings_screen.dart';
import '../features/settings/workspaces_screen.dart';
import '../features/setup/setup_flow.dart';
import '../features/setup/splash_screen.dart';
import '../features/shell/home_screen.dart';
import '../features/tasks/ui/task_form_screen.dart';
import '../features/projects/ui/project_detail_screen.dart';
import '../features/projects/ui/projects_screen.dart';
import '../features/tasks/ui/tasks_screen.dart';
import '../features/shell/shell_scaffold.dart';
import '../features/vault/ui/vault_gate.dart';
import '../features/vault/ui/vault_import_screen.dart';
import '../features/vault/ui/vault_item_form_screen.dart';
import '../features/vault/ui/vault_item_screen.dart';
import '../features/vault/ui/vault_list_screen.dart';
import '../features/vault/ui/vault_settings_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final router = buildRouter(onNavigate: () => ref.read(moneyRevealedProvider.notifier).hide());
  ref.onDispose(router.dispose);
  return router;
});

final _rootKey = GlobalKey<NavigatorState>();

/// [onNavigate] runs on every push and pop, on the root and in each tab.
GoRouter buildRouter({void Function()? onNavigate}) => GoRouter(
  navigatorKey: _rootKey,
  observers: [if (onNavigate != null) MoneyHideObserver(onNavigate)],
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
          observers: [if (onNavigate != null) MoneyHideObserver(onNavigate)],
          routes: [GoRoute(path: '/home', builder: (_, _) => const HomeScreen())],
        ),
        StatefulShellBranch(
          observers: [if (onNavigate != null) MoneyHideObserver(onNavigate)],
          routes: [
            GoRoute(
              path: '/finance',
              builder: (_, _) => const SensitiveGate(fullScreen: true, child: FinanceOverviewScreen()),
              routes: [
                // Forms cover the shell (no bottom bar or mic over the Save button).
                _financeRoute(
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
                _financeRoute(
                  path: 'tx/:id',
                  parentNavigatorKey: _rootKey,
                  builder: (_, state) => TransactionFormScreen(editId: int.parse(state.pathParameters['id']!)),
                ),
                _financeRoute(
                  path: 'transfer/new',
                  parentNavigatorKey: _rootKey,
                  builder: (_, state) =>
                      TransferFormScreen(initial: state.extra is TransferDraft ? state.extra! as TransferDraft : null),
                ),
                _financeRoute(
                  path: 'import',
                  parentNavigatorKey: _rootKey,
                  builder: (_, _) => const ImportWizardScreen(),
                ),
                _financeRoute(
                  path: 'transfer/:id',
                  parentNavigatorKey: _rootKey,
                  builder: (_, state) => TransferFormScreen(editId: int.parse(state.pathParameters['id']!)),
                ),
                _financeRoute(
                  path: 'accounts',
                  builder: (_, _) => const AccountsScreen(),
                  routes: [
                    _financeRoute(
                      path: ':id',
                      builder: (_, state) => AccountDetailScreen(accountId: int.parse(state.pathParameters['id']!)),
                    ),
                  ],
                ),
                _financeRoute(path: 'reports', builder: (_, _) => const ReportsScreen()),
                _financeRoute(path: 'buckets', builder: (_, _) => const BucketsScreen()),
                _financeRoute(path: 'budgets', builder: (_, _) => const BudgetsScreen()),
                _financeRoute(
                  path: 'debts',
                  builder: (_, _) => const DebtsScreen(),
                  routes: [
                    _financeRoute(
                      path: ':id',
                      builder: (_, state) => DebtDetailScreen(debtId: int.parse(state.pathParameters['id']!)),
                    ),
                  ],
                ),
                _financeRoute(
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
          observers: [if (onNavigate != null) MoneyHideObserver(onNavigate)],
          routes: [
            _financeRoute(
              path: '/tasks',
              builder: (_, _) => const TasksScreen(),
              routes: [
                GoRoute(path: 'new', parentNavigatorKey: _rootKey, builder: (_, _) => const TaskFormScreen()),
                GoRoute(
                  path: ':id',
                  parentNavigatorKey: _rootKey,
                  builder: (_, state) => TaskFormScreen(editId: int.parse(state.pathParameters['id']!)),
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          observers: [if (onNavigate != null) MoneyHideObserver(onNavigate)],
          routes: [
            // Every vault route renders through VaultGate; forms and details cover the shell.
            GoRoute(
              path: '/projects',
              builder: (_, _) => const ProjectsScreen(),
              routes: [
                GoRoute(
                  path: ':id',
                  parentNavigatorKey: _rootKey,
                  builder: (_, state) => ProjectDetailScreen(projectId: int.parse(state.pathParameters['id']!)),
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          observers: [if (onNavigate != null) MoneyHideObserver(onNavigate)],
          routes: [
            // Every vault route renders through VaultGate; forms and details cover the shell.
            GoRoute(
              path: '/vault',
              builder: (_, _) => VaultGate(builder: (_) => const VaultListScreen()),
              routes: [
                GoRoute(
                  path: 'new',
                  parentNavigatorKey: _rootKey,
                  builder: (_, _) => VaultGate(builder: (_) => const VaultItemFormScreen()),
                ),
                GoRoute(
                  path: 'item/:id',
                  parentNavigatorKey: _rootKey,
                  builder: (_, state) =>
                      VaultGate(builder: (_) => VaultItemScreen(itemId: int.parse(state.pathParameters['id']!))),
                  routes: [
                    GoRoute(
                      path: 'edit',
                      parentNavigatorKey: _rootKey,
                      builder: (_, state) => VaultGate(
                        builder: (_) => VaultItemFormScreen(editId: int.parse(state.pathParameters['id']!)),
                      ),
                    ),
                  ],
                ),
                GoRoute(
                  path: 'import',
                  parentNavigatorKey: _rootKey,
                  builder: (_, _) => VaultGate(builder: (_) => const VaultImportScreen()),
                ),
                GoRoute(
                  path: 'settings',
                  parentNavigatorKey: _rootKey,
                  builder: (_, _) => VaultGate(builder: (_) => const VaultSettingsScreen()),
                ),
              ],
            ),
          ],
        ),
      ],
    ),
    GoRoute(path: '/inbox', builder: (_, _) => const InboxScreen()),
    GoRoute(
      path: '/capture/:id',
      builder: (_, state) => CaptureReviewScreen(captureId: int.parse(state.pathParameters['id']!)),
    ),
    GoRoute(
      path: '/settings',
      builder: (_, _) => const SettingsScreen(),
      routes: [
        GoRoute(path: 'backup', builder: (_, _) => const BackupScreen()),
        GoRoute(path: 'finance', builder: (_, _) => const FinanceSettingsScreen()),
        GoRoute(path: 'categories', builder: (_, _) => const CategoriesScreen()),
        GoRoute(path: 'workspaces', builder: (_, _) => const WorkspacesScreen()),
        GoRoute(path: 'ai', builder: (_, _) => const AiSettingsScreen()),
      ],
    ),
  ],
);

/// A page under /finance. go_router stacks these over the overview instead of inside it, so each one
/// carries its own biometric gate (the Global Constraint: Finance asks again after a minute).
GoRoute _financeRoute({
  required String path,
  required GoRouterWidgetBuilder builder,
  GlobalKey<NavigatorState>? parentNavigatorKey,
  List<RouteBase> routes = const [],
}) => GoRoute(
  path: path,
  parentNavigatorKey: parentNavigatorKey,
  routes: routes,
  builder: (context, state) => SensitiveGate(fullScreen: true, child: builder(context, state)),
);
