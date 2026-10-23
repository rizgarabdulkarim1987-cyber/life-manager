import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/ckb_fallback_localizations.dart';
import '../../core/theme/motion.dart';
import '../../core/theme/tokens.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/security/money_privacy.dart';
import '../capture/ui/composer.dart';

/// Four destinations, with the composer above the bar on every tab (redesign §9.1).
class ShellScaffold extends StatelessWidget {
  const ShellScaffold({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final k = context.tokens;
    final items = [
      (Icons.home_outlined, Icons.home_rounded, l10n.navHome),
      (Icons.account_balance_wallet_outlined, Icons.account_balance_wallet_rounded, l10n.navFinance),
      (Icons.task_alt_outlined, Icons.task_alt_rounded, l10n.navTasks),
      (Icons.rocket_launch_outlined, Icons.rocket_launch_rounded, l10n.navProjects),
    ];
    Widget item(int i) => Expanded(
      child: _NavItem(
        key: ValueKey('nav-$i'),
        icon: items[i].$1,
        selectedIcon: items[i].$2,
        label: items[i].$3,
        selected: shell.currentIndex == i,
        onTap: () {
          // Amounts hide again whenever the owner changes tab.
          ProviderScope.containerOf(context, listen: false).read(moneyRevealedProvider.notifier).hide();
          shell.goBranch(i, initialLocation: i == shell.currentIndex);
        },
      ),
    );

    return Scaffold(
      body: Column(
        children: [
          Expanded(child: shell),
          // Home has its own, larger box.
          if (shell.currentIndex != 0)
            Padding(padding: const EdgeInsets.fromLTRB(12, 6, 12, 8), child: const Composer()),
        ],
      ),
      bottomNavigationBar: Material(
        color: k.surface,
        child: SafeArea(
          top: false,
          child: SizedBox(height: 68, child: Row(children: [for (var i = 0; i < items.length; i++) item(i)])),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    super.key,
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final k = context.tokens;
    final color = selected ? k.accent : k.textMuted;
    return Semantics(
      selected: selected,
      button: true,
      label: label,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        containedInkWell: true,
        highlightShape: BoxShape.rectangle,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: reduceMotion(context) ? Duration.zero : kDurationBase,
              curve: kEaseOut,
              width: 56,
              height: 30,
              decoration: BoxDecoration(
                color: selected ? k.accent.withValues(alpha: 0.16) : Colors.transparent,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(selected ? selectedIcon : icon, color: color, size: 22),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(color: color, fontWeight: selected ? FontWeight.w600 : FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}
