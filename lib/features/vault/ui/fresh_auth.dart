import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/ckb_fallback_localizations.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/security/sensitive.dart';
import '../../../core/theme/tokens.dart';
import '../crypto/vault_errors.dart';
import '../data/vault_providers.dart';
import '../vault_session.dart';
import 'secret_field.dart';
import 'vault_ui_common.dart';

/// Reveal and copy need an auth from the last 30 s (plan Decision 14): a
/// fingerprint when this phone has it on, else the master password. Returns
/// whether the owner proved it is them.
Future<bool> ensureFreshAuth(BuildContext context, WidgetRef ref) async {
  final session = ref.read(vaultSessionProvider.notifier);
  if (!session.isUnlocked) return false;
  if (!session.needsFreshAuth()) return true;
  final l = context.l10n;
  if (await ref.read(vaultBiometricEnabledProvider.future)) {
    try {
      final same = await ref
          .read(vaultKeyServiceProvider)
          .confirmWithBiometric(session.requireKey(), vaultBioPrompt(l));
      if (same) {
        session.freshAuth();
        return true;
      }
    } on VaultBiometricInvalidated {
      ref.invalidate(vaultBiometricEnabledProvider);
    } on VaultUnlockError {
      // Cancelled, lockout or unavailable: fall back to the master password.
    } on StateError {
      return false; // Locked meanwhile.
    }
  }
  if (!context.mounted) return false;
  final ok = await showDialog<bool>(context: context, builder: (_) => const _ConfirmPasswordDialog()) ?? false;
  if (ok) session.freshAuth();
  return ok;
}

class _ConfirmPasswordDialog extends ConsumerStatefulWidget {
  const _ConfirmPasswordDialog();

  @override
  ConsumerState<_ConfirmPasswordDialog> createState() => _ConfirmPasswordDialogState();
}

class _ConfirmPasswordDialogState extends ConsumerState<_ConfirmPasswordDialog> {
  final _pw = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _pw.clear();
    _pw.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    if (_busy || _pw.text.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final pw = Sensitive(_pw.text);
    try {
      final session = ref.read(vaultSessionProvider.notifier);
      final k = await ref.read(vaultKeyServiceProvider).unlockWithPassword(pw);
      final bool same;
      try {
        same = k.sameAs(session.requireKey());
      } finally {
        k.destroy();
      }
      if (mounted) Navigator.of(context).pop(same);
    } on VaultUnlockError catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = vaultErrorText(context.l10n, e);
        });
      }
    } catch (e) {
      AppLogger.error('vault fresh auth failed', e.runtimeType);
      if (mounted) Navigator.of(context).pop(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final k = context.tokens;
    return AlertDialog(
      key: const ValueKey('vault-fresh-auth'),
      title: Text(l.vltConfirmIdentity),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.vltConfirmIdentityBody, style: TextStyle(color: k.textMuted)),
            const SizedBox(height: 16),
            SecretField(
              key: const ValueKey('vault-fresh-auth-password'),
              controller: _pw,
              label: l.vltMasterPassword,
              autofocus: true,
              enabled: !_busy,
              error: _error,
              textInputAction: TextInputAction.done,
              onChanged: (_) => setState(() => _error = null),
              onSubmitted: (_) => _confirm(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.of(context).pop(false), child: Text(l.cancel)),
        FilledButton(
          key: const ValueKey('vault-fresh-auth-confirm'),
          onPressed: _busy || _pw.text.isEmpty ? null : _confirm,
          child: Text(l.vltConfirm),
        ),
      ],
    );
  }
}
