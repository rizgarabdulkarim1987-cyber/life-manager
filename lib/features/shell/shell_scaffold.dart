import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/ckb_fallback_localizations.dart';
import '../../core/theme/motion.dart';
import '../../core/theme/tokens.dart';

/// Bottom bar with four destinations around a notched, centred mic button.
class ShellScaffold extends StatelessWidget {
  const ShellScaffold({super.key, required this.shell});

  final StatefulNavigationShell shell;

  static const double _fabSize = 64;

  void _openCapture(BuildContext context) {
    final k = context.tokens;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
          child: Row(
            children: [
              Icon(Icons.mic_none_rounded, color: k.accent, size: 28),
              const SizedBox(width: 16),
              Expanded(child: Text(context.l10n.micSoon, style: Theme.of(context).textTheme.titleMedium)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final k = context.tokens;
    final items = [
      (Icons.home_outlined, Icons.home_rounded, l10n.navHome),
      (Icons.account_balance_wallet_outlined, Icons.account_balance_wallet_rounded, l10n.navFinance),
      (Icons.task_alt_outlined, Icons.task_alt_rounded, l10n.navTasks),
      (Icons.shield_outlined, Icons.shield_rounded, l10n.navVault),
    ];
    Widget item(int i) => Expanded(
      child: _NavItem(
        key: ValueKey('nav-$i'),
        icon: items[i].$1,
        selectedIcon: items[i].$2,
        label: items[i].$3,
        selected: shell.currentIndex == i,
        onTap: () => shell.goBranch(i, initialLocation: i == shell.currentIndex),
      ),
    );

    return Scaffold(
      body: shell,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: SizedBox.square(
        dimension: _fabSize,
        child: FloatingActionButton(
          key: const ValueKey('mic-fab'),
          onPressed: () => _openCapture(context),
          shape: const CircleBorder(),
          backgroundColor: k.accent,
          foregroundColor: k.onAccent,
          elevation: 2,
          tooltip: l10n.micSoon,
          child: const Icon(Icons.mic_rounded, size: 30),
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 6,
        color: k.surface,
        surfaceTintColor: Colors.transparent,
        padding: EdgeInsets.zero,
        height: 72,
        child: Row(
          children: [
            item(0),
            item(1),
            const SizedBox(width: _fabSize + 16),
            item(2),
            item(3),
          ],
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
