import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/ckb_fallback_localizations.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/security/sensitive.dart';
import '../../../core/theme/tokens.dart';
import '../crypto/recovery_key.dart';
import '../crypto/vault_key.dart';
import '../data/vault_key_service.dart';
import '../data/vault_providers.dart';
import '../vault_session.dart';
import 'master_password_form.dart';
import 'recovery_key_view.dart';
import 'vault_ui_common.dart';

enum _Step { intro, password, preparing, recovery, confirm, biometric }

/// First run of the vault (spec §9.1): master password, the recovery key shown
/// once and typed back, then optional fingerprint unlock. Nothing is written
/// until the key has been typed back; leaving earlier wipes everything.
class VaultSetupScreen extends ConsumerStatefulWidget {
  const VaultSetupScreen({super.key});

  @override
  ConsumerState<VaultSetupScreen> createState() => _VaultSetupScreenState();
}

class _VaultSetupScreenState extends ConsumerState<VaultSetupScreen> {
  _Step _step = _Step.intro;
  PendingVault? _pending;
  VaultKey? _committed;
  bool _bioAvailable = false;
  bool _busy = false;
  String? _error;
  final _typed = TextEditingController();

  @override
  void dispose() {
    _pending?.discard();
    _committed?.destroy();
    _typed.clear();
    _typed.dispose();
    super.dispose();
  }

  VaultKeyService get _service => ref.read(vaultKeyServiceProvider);

  Future<void> _prepare(Sensitive<String> password) async {
    setState(() {
      _step = _Step.preparing;
      _error = null;
    });
    try {
      final pending = await _service.prepareSetUp(password);
      if (!mounted) return pending.discard();
      setState(() {
        _pending = pending;
        _step = _Step.recovery;
      });
    } catch (e) {
      AppLogger.error('vault setup failed', e);
      if (mounted) {
        setState(() {
          _step = _Step.password;
          _error = context.l10n.somethingWentWrong;
        });
      }
    }
  }

  bool _typedMatches() {
    final pending = _pending;
    if (pending == null) return false;
    final typed = RecoveryKey.parse(_typed.text);
    if (typed == null) return false;
    try {
      return constantTimeEquals(typed.bytes, pending.recoveryKey.bytes);
    } finally {
      typed.destroy();
    }
  }

  Future<void> _commit() async {
    final pending = _pending;
    if (pending == null || _busy) return;
    if (!_typedMatches()) {
      setState(() => _error = context.l10n.vltRecoveryMismatch);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _service.commitSetUp(pending);
      _bioAvailable = await _service.biometricAvailable();
    } catch (e) {
      AppLogger.error('vault setup commit failed', e);
      if (mounted) {
        setState(() {
          _busy = false;
          _error = context.l10n.somethingWentWrong;
        });
      }
      return;
    }
    pending.recoveryKey.destroy();
    _committed = pending.vaultKey;
    _pending = null;
    _typed.clear();
    if (!mounted) return;
    if (_bioAvailable) {
      setState(() {
        _busy = false;
        _step = _Step.biometric;
      });
    } else {
      _finish();
    }
  }

  Future<void> _enableBio() async {
    final key = _committed;
    if (key == null || _busy) return;
    setState(() => _busy = true);
    try {
      await _service.enableBiometric(key, vaultBioPrompt(context.l10n));
    } catch (e) {
      // Cancelled or unavailable: the vault works without it; settings can try again.
      AppLogger.warn('vault biometric enable failed', e);
    }
    ref.invalidate(vaultBiometricEnabledProvider);
    if (mounted) _finish();
  }

  void _finish() {
    final key = _committed;
    if (key == null) return;
    _committed = null;
    ref.read(vaultSessionProvider.notifier).unlocked(key);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final k = context.tokens;
    final text = Theme.of(context).textTheme;
    Widget heading(String s) => Text(s, style: text.headlineSmall?.copyWith(color: k.text));
    Widget body(String s) => Text(s, style: text.bodyLarge?.copyWith(color: k.textMuted, height: 1.5));
    Widget primary(Key key, String label, VoidCallback? onPressed) => FilledButton(
      key: key,
      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
      onPressed: onPressed,
      child: _busy
          ? SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2, color: k.onAccent))
          : Text(label),
    );
    Widget error() => _error == null
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(_error!, style: text.bodyMedium?.copyWith(color: k.danger)),
          );

    final children = switch (_step) {
      _Step.intro => [
        Icon(Icons.shield_outlined, size: 48, color: k.accent),
        const SizedBox(height: 16),
        heading(l.vltSetupTitle),
        const SizedBox(height: 12),
        body(l.vltSetupIntro),
        const SizedBox(height: 16),
        _Notice(text: l.vltSetupTestFirst),
        const SizedBox(height: 32),
        primary(const ValueKey('vault-setup-start'), l.vltSetupStart, () => setState(() => _step = _Step.password)),
      ],
      _Step.password => [
        heading(l.vltMasterPassword),
        const SizedBox(height: 12),
        body(l.vltSetupPasswordBody),
        const SizedBox(height: 24),
        MasterPasswordForm(submitLabel: l.continueLabel, onSubmit: _prepare),
        error(),
      ],
      _Step.preparing => [
        const SizedBox(height: 48),
        const Center(child: CircularProgressIndicator()),
        const SizedBox(height: 24),
        Text(
          l.vltPreparing,
          textAlign: TextAlign.center,
          style: text.bodyLarge?.copyWith(color: k.textMuted),
        ),
      ],
      _Step.recovery => [
        heading(l.vltRecoveryTitle),
        const SizedBox(height: 12),
        body(l.vltRecoveryBody),
        const SizedBox(height: 24),
        RecoveryKeyView(display: _pending!.recoveryKey.display),
        const SizedBox(height: 32),
        primary(const ValueKey('vault-recovery-next'), l.continueLabel, () => setState(() => _step = _Step.confirm)),
      ],
      _Step.confirm => [
        heading(l.vltRecoveryConfirmTitle),
        const SizedBox(height: 12),
        body(l.vltRecoveryConfirmBody),
        const SizedBox(height: 24),
        RecoveryKeyField(
          key: const ValueKey('vault-recovery-typed'),
          controller: _typed,
          error: _error,
          onChanged: (_) => setState(() => _error = null),
          onSubmitted: (_) => _commit(),
        ),
        const SizedBox(height: 24),
        primary(const ValueKey('vault-recovery-confirm'), l.continueLabel, _typed.text.trim().isEmpty ? null : _commit),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _busy ? null : () => setState(() => _step = _Step.recovery),
          child: Text(l.vltRecoveryTitle),
        ),
      ],
      _Step.biometric => [
        Icon(Icons.fingerprint_rounded, size: 48, color: k.accent),
        const SizedBox(height: 16),
        heading(l.vltSetupBioTitle),
        const SizedBox(height: 12),
        body(l.vltSetupBioBody),
        const SizedBox(height: 32),
        primary(const ValueKey('vault-setup-bio-enable'), l.enable, _busy ? null : _enableBio),
        const SizedBox(height: 8),
        TextButton(
          key: const ValueKey('vault-setup-bio-skip'),
          onPressed: _busy ? null : _finish,
          child: Text(l.vltNotNow),
        ),
      ],
    };

    return PopScope(
      // Going back from a later step returns to the previous one instead of leaving.
      canPop: _step == _Step.intro || _step == _Step.password,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || _busy) return;
        setState(() {
          _error = null;
          if (_step == _Step.confirm) _step = _Step.recovery;
        });
      },
      child: Scaffold(
        appBar: AppBar(title: Text(l.navVault)),
        body: VaultPage(children: children),
      ),
    );
  }
}

/// A quiet warning line with an icon, not a card.
class _Notice extends StatelessWidget {
  const _Notice({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final k = context.tokens;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.info_outline_rounded, size: 20, color: k.warning),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: k.warning)),
        ),
      ],
    );
  }
}
