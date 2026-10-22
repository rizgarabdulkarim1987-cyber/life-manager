import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/l10n/ckb_fallback_localizations.dart';
import '../features/settings/settings_screen.dart';
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

GoRouter buildRouter() => GoRouter(
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
              builder: (context, _) => PlaceholderScreen(
                title: context.l10n.navFinance,
                phase: 2,
                icon: Icons.account_balance_wallet_outlined,
              ),
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
        // Replaced by the real backup screen in Task 13.
        GoRoute(
          path: 'backup',
          builder: (context, _) =>
              PlaceholderScreen(title: context.l10n.backupRestore, phase: 1, icon: Icons.save_alt_rounded),
        ),
      ],
    ),
  ],
);
