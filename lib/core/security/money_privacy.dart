import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/ckb_fallback_localizations.dart';

/// Shown in place of every amount until the owner taps the eye (redesign §8.3).
const kMaskedMoney = '•••••';

/// Whether amounts are visible right now. Starts hidden, and goes back to
/// hidden on any navigation and whenever the app leaves the screen.
class MoneyReveal extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;

  void hide() {
    if (state) state = false;
  }
}

final moneyRevealedProvider = NotifierProvider<MoneyReveal, bool>(MoneyReveal.new);

/// Test seam: older widget tests that check figures turn masking off.
final alwaysRevealMoneyProvider = Provider<bool>((ref) => false);

/// Masks amounts again on every push, pop and replace.
class MoneyHideObserver extends NavigatorObserver {
  MoneyHideObserver(this._onChange);

  final void Function() _onChange;

  // After the frame: a provider must not change while the navigator builds.
  void _hide() => Future.microtask(_onChange);

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => _hide();

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => _hide();

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) => _hide();
}

class RevealMoneyButton extends ConsumerWidget {
  const RevealMoneyButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shown = ref.watch(moneyRevealedProvider);
    final l = context.l10n;
    return IconButton(
      key: const ValueKey('reveal-money'),
      tooltip: shown ? l.hideAmounts : l.showAmounts,
      icon: Icon(shown ? Icons.visibility_off_outlined : Icons.visibility_outlined),
      onPressed: () => ref.read(moneyRevealedProvider.notifier).toggle(),
    );
  }
}
