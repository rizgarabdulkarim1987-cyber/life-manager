import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/ckb_fallback_localizations.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/security/sensitive.dart';
import '../../../core/theme/tokens.dart';
import '../data/vault_providers.dart';
import '../vault_session.dart';
import 'master_password_form.dart';
import 'vault_setup_screen.dart';
import 'vault_ui_common.dart';
import 'vault_unlock_screen.dart';

/// Every vault route renders through this (plan Global Constraints): unless
/// the vault is open, the route's content is never built.
class VaultGate extends ConsumerWidget {
  const VaultGate({super.key, required this.builder});

  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) => switch (ref.watch(vaultSessionProvider)) {
    VaultChecking() => const Scaffold(body: Center(child: CircularProgressIndicator())),
    VaultNotSetUp() => const VaultSetupScreen(),
    VaultLocked() => const VaultUnlockScreen(),
    VaultUnlocked(mustChangePassword: true) => const _ForcedNewPassword(),
    VaultUnlocked() => Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => ref.read(vaultSessionProvider.notifier).touch(),
      child: builder(context),
    ),
  };
}

/// After a recovery-key unlock: a new master password, with no way around it
/// (plan Decision 9). Locking is still possible; the next unlock asks again.
class _ForcedNewPassword extends ConsumerStatefulWidget {
  const _ForcedNewPassword();

  @override
  ConsumerState<_ForcedNewPassword> createState() => _ForcedNewPasswordState();
}

class _ForcedNewPasswordState extends ConsumerState<_ForcedNewPassword> {
  bool _busy = false;
  String? _error;

  Future<void> _save(Sensitive<String> pw) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final session = ref.read(vaultSessionProvider.notifier);
    try {
      await ref.read(vaultKeyServiceProvider).changeMasterPassword(session.requireKey(), pw);
      session.passwordReplaced();
    } catch (e) {
      AppLogger.error('vault forced password change failed', e);
      if (mounted) {
        setState(() {
          _busy = false;
          _error = context.l10n.somethingWentWrong;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final k = context.tokens;
    final text = Theme.of(context).textTheme;
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Text(l.navVault),
          actions: [
            IconButton(
              tooltip: l.vltLock,
              icon: const Icon(Icons.lock_outline_rounded),
              onPressed: () => ref.read(vaultSessionProvider.notifier).lock(),
            ),
          ],
        ),
        body: VaultPage(
          children: [
            Text(
              l.vltNewPasswordTitle,
              key: const ValueKey('vault-forced-title'),
              style: text.headlineSmall?.copyWith(color: k.text),
            ),
            const SizedBox(height: 12),
            Text(l.vltNewPasswordBody, style: text.bodyLarge?.copyWith(color: k.textMuted, height: 1.5)),
            const SizedBox(height: 24),
            MasterPasswordForm(submitLabel: l.save, busy: _busy, onSubmit: _save),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: text.bodyMedium?.copyWith(color: k.danger)),
            ],
          ],
        ),
      ),
    );
  }
}
