import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/ckb_fallback_localizations.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/security/sensitive.dart';
import '../../../core/theme/tokens.dart';
import '../crypto/vault_errors.dart';
import '../crypto/vault_key.dart';
import '../data/vault_providers.dart';
import '../vault_session.dart';
import 'recovery_key_view.dart';
import 'secret_field.dart';
import 'vault_ui_common.dart';

/// The locked vault: master password, fingerprint when this phone has it on,
/// or the recovery key, which then forces a new master password.
class VaultUnlockScreen extends ConsumerStatefulWidget {
  const VaultUnlockScreen({super.key});

  @override
  ConsumerState<VaultUnlockScreen> createState() => _VaultUnlockScreenState();
}

class _VaultUnlockScreenState extends ConsumerState<VaultUnlockScreen> {
  final _password = TextEditingController();
  final _recovery = TextEditingController();
  bool _useRecovery = false;
  bool _busy = false;
  String? _error;
  DateTime? _lockedUntil;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoPrompt());
  }

  @override
  void dispose() {
    _tick?.cancel();
    _password.clear();
    _recovery.clear();
    _password.dispose();
    _recovery.dispose();
    super.dispose();
  }

  DateTime _now() => ref.read(vaultClockProvider)();

  Duration? get _lockRemaining {
    final until = _lockedUntil;
    if (until == null) return null;
    final left = until.difference(_now());
    return left > Duration.zero ? left : null;
  }

  Future<void> _autoPrompt() async {
    if (!mounted || WidgetsBinding.instance.lifecycleState == AppLifecycleState.paused) return;
    if (await ref.read(vaultBiometricEnabledProvider.future) && mounted) await _biometric();
  }

  Future<void> _run(Future<VaultKey> Function() unlock, {bool recovery = false}) async {
    if (_busy || _lockRemaining != null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final key = await unlock();
      _password.clear();
      _recovery.clear();
      if (!mounted) return key.destroy();
      ref.read(vaultSessionProvider.notifier).unlocked(key, mustChangePassword: recovery);
    } on VaultBiometricCancelled {
      if (mounted) setState(() => _busy = false);
    } on VaultUnlockError catch (e) {
      if (e is VaultBiometricInvalidated) ref.invalidate(vaultBiometricEnabledProvider);
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      setState(() {
        _busy = false;
        _error = e is VaultBiometricUnavailable ? null : vaultErrorText(context.l10n, e);
        if (e is VaultLockedOut) _startCountdown(e.remaining);
      });
    } catch (e) {
      AppLogger.error('vault unlock failed', e.runtimeType);
      if (mounted) {
        setState(() {
          _busy = false;
          _error = context.l10n.somethingWentWrong;
        });
      }
    }
  }

  void _startCountdown(Duration remaining) {
    _lockedUntil = _now().add(remaining);
    _tick?.cancel();
    _tick = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      final left = _lockRemaining;
      setState(() {
        if (left == null) {
          t.cancel();
          _lockedUntil = null;
          _error = null;
        } else {
          _error = vaultErrorText(context.l10n, VaultLockedOut(left));
        }
      });
    });
  }

  Future<void> _submit() {
    final service = ref.read(vaultKeyServiceProvider);
    if (_useRecovery) {
      final typed = _recovery.text;
      return _run(() => service.unlockWithRecovery(typed), recovery: true);
    }
    final pw = Sensitive(_password.text);
    return _run(() => service.unlockWithPassword(pw));
  }

  Future<void> _biometric() {
    final prompt = vaultBioPrompt(context.l10n);
    return _run(() => ref.read(vaultKeyServiceProvider).unlockWithBiometric(prompt));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final k = context.tokens;
    final text = Theme.of(context).textTheme;
    final bio = ref.watch(vaultBiometricEnabledProvider).value ?? false;
    final locked = _lockRemaining != null;
    final canSubmit = !_busy && !locked && (_useRecovery ? _recovery.text.trim() : _password.text).isNotEmpty;
    return Scaffold(
      appBar: AppBar(title: Text(l.navVault)),
      body: VaultPage(
        children: [
          const SizedBox(height: 16),
          Icon(Icons.lock_outline_rounded, size: 44, color: k.accent),
          const SizedBox(height: 16),
          Text(
            l.vltLocked,
            key: const ValueKey('vault-locked-title'),
            textAlign: TextAlign.center,
            style: text.headlineSmall?.copyWith(color: k.text),
          ),
          const SizedBox(height: 8),
          Text(
            _useRecovery ? l.vltRecoveryKeyHint : l.vltLockedBody,
            textAlign: TextAlign.center,
            style: text.bodyMedium?.copyWith(color: k.textMuted),
          ),
          const SizedBox(height: 28),
          if (_useRecovery)
            RecoveryKeyField(
              key: const ValueKey('vault-unlock-recovery'),
              controller: _recovery,
              onChanged: (_) => setState(() => _error = null),
              onSubmitted: (_) => _submit(),
            )
          else
            SecretField(
              key: const ValueKey('vault-unlock-password'),
              controller: _password,
              label: l.vltMasterPassword,
              enabled: !_busy,
              textInputAction: TextInputAction.done,
              onChanged: (_) => setState(() => _error = null),
              onSubmitted: (_) => _submit(),
            ),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            child: _error == null
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      _error!,
                      key: const ValueKey('vault-unlock-error'),
                      style: text.bodyMedium?.copyWith(color: locked ? k.warning : k.danger),
                    ),
                  ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            key: const ValueKey('vault-unlock-submit'),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            onPressed: canSubmit ? _submit : null,
            child: _busy
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: k.onAccent),
                      ),
                      const SizedBox(width: 12),
                      Flexible(child: Text(l.vltUnlocking, overflow: TextOverflow.ellipsis)),
                    ],
                  )
                : Text(l.vltUnlock),
          ),
          if (bio && !_useRecovery) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              key: const ValueKey('vault-unlock-bio'),
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              onPressed: _busy || locked ? null : _biometric,
              icon: const Icon(Icons.fingerprint_rounded),
              label: Text(l.vltUseFingerprint),
            ),
          ],
          const SizedBox(height: 16),
          TextButton(
            key: const ValueKey('vault-unlock-switch'),
            onPressed: _busy
                ? null
                : () => setState(() {
                    _useRecovery = !_useRecovery;
                    _error = locked ? _error : null;
                  }),
            child: Text(_useRecovery ? l.vltUsePassword : l.vltUseRecoveryKey),
          ),
        ],
      ),
    );
  }
}
