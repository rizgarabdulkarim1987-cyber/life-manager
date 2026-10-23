import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/ckb_fallback_localizations.dart';
import '../../core/logging/app_logger.dart';
import '../../core/theme/tokens.dart';
import 'lock_controller.dart';

const _intents = MethodChannel('life_manager/intents');

/// Opens Android's security settings so the owner can add a screen lock.
Future<void> openSecuritySettings() async {
  try {
    await _intents.invokeMethod<void>('openSecuritySettings');
  } on PlatformException catch (e) {
    AppLogger.warn('could not open security settings', e.code);
  } on MissingPluginException {
    AppLogger.warn('security settings channel missing');
  }
}

/// Full-screen unlock with face, fingerprint or the phone's screen lock
/// (redesign §8.1). Prompts as soon as it shows.
class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  /// Null until the phone answers whether it has a screen lock.
  bool? _secure;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    final secure = await ref.read(biometricAuthenticatorProvider).deviceSecure();
    if (!mounted) return;
    setState(() => _secure = secure);
    if (secure) await _prompt();
  }

  Future<void> _prompt() async {
    if (_busy) return;
    setState(() => _busy = true);
    final ok = await ref.read(biometricAuthenticatorProvider).authenticate(context.l10n.unlockReason);
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) ref.read(lockControllerProvider.notifier).unlock();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final k = context.tokens;
    final text = Theme.of(context).textTheme;
    final secure = _secure;

    final Widget body;
    if (secure == false) {
      body = Column(
        key: const ValueKey('no-screen-lock'),
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_open_rounded, size: 48, color: k.warning),
          const SizedBox(height: 20),
          Text(l.noScreenLockTitle, textAlign: TextAlign.center, style: text.titleLarge),
          const SizedBox(height: 12),
          Text(
            l.noScreenLockBody,
            textAlign: TextAlign.center,
            style: text.bodyLarge?.copyWith(color: k.textMuted),
          ),
          const SizedBox(height: 28),
          FilledButton.icon(
            key: const ValueKey('open-security-settings'),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            onPressed: openSecuritySettings,
            icon: const Icon(Icons.settings_outlined),
            label: Text(l.openSecuritySettings),
          ),
          const SizedBox(height: 8),
          TextButton(key: const ValueKey('recheck-screen-lock'), onPressed: _start, child: Text(l.unlockButton)),
        ],
      );
    } else {
      body = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(color: k.accent.withValues(alpha: 0.10), shape: BoxShape.circle),
            child: Icon(Icons.face_unlock_outlined, size: 44, color: k.accent),
          ),
          const SizedBox(height: 24),
          Text(l.lockedTitle, textAlign: TextAlign.center, style: text.headlineSmall),
          const SizedBox(height: 8),
          Text(
            l.lockedHint,
            textAlign: TextAlign.center,
            style: text.bodyLarge?.copyWith(color: k.textMuted),
          ),
          const SizedBox(height: 36),
          FilledButton.icon(
            key: const ValueKey('unlock-retry'),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
            onPressed: secure == null || _busy ? null : _prompt,
            icon: const Icon(Icons.fingerprint_rounded),
            label: Text(l.unlockButton),
          ),
        ],
      );
    }

    return Scaffold(
      key: const ValueKey('lock-screen'),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 420), child: body),
          ),
        ),
      ),
    );
  }
}
