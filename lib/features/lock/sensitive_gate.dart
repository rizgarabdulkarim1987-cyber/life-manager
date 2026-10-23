import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/ckb_fallback_localizations.dart';
import '../../core/theme/tokens.dart';
import 'lock_controller.dart';

/// Finance, the vault and project costs ask for face or fingerprint again
/// unless the owner unlocked within the last minute (redesign §8.2).
class SensitiveGate extends ConsumerStatefulWidget {
  const SensitiveGate({super.key, required this.child, this.fullScreen = false});

  final Widget child;

  /// A whole tab: the locked view gets its own page.
  final bool fullScreen;

  @override
  ConsumerState<SensitiveGate> createState() => _SensitiveGateState();
}

class _SensitiveGateState extends ConsumerState<SensitiveGate> {
  late bool _open = ref.read(lockControllerProvider.notifier).authFresh(DateTime.now());
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (!_open) WidgetsBinding.instance.addPostFrameCallback((_) => _ask());
  }

  Future<void> _ask() async {
    if (_busy) return;
    setState(() => _busy = true);
    final ok = await ref.read(biometricAuthenticatorProvider).authenticate(context.l10n.unlockReason);
    if (!mounted) return;
    if (ok) ref.read(lockControllerProvider.notifier).unlock();
    setState(() {
      _busy = false;
      _open = ok;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Locking the whole app closes every gate again.
    ref.listen(lockControllerProvider, (_, s) {
      if (s == LockStatus.locked && _open) setState(() => _open = false);
    });
    if (_open) return widget.child;
    final k = context.tokens;
    final text = Theme.of(context).textTheme;
    final locked = Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline_rounded, size: 40, color: k.textMuted),
            const SizedBox(height: 16),
            Text(context.l10n.sensitiveLocked, textAlign: TextAlign.center, style: text.bodyLarge),
            const SizedBox(height: 20),
            FilledButton.icon(
              key: const ValueKey('sensitive-unlock'),
              onPressed: _busy ? null : _ask,
              icon: const Icon(Icons.fingerprint_rounded),
              label: Text(context.l10n.unlockButton),
            ),
          ],
        ),
      ),
    );
    return widget.fullScreen ? Scaffold(appBar: AppBar(), body: locked) : locked;
  }
}
