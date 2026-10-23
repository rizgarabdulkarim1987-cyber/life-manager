import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/l10n/ckb_fallback_localizations.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/security/sensitive.dart';
import '../../../core/theme/tokens.dart';
import '../../settings/settings_repository.dart';
import '../../settings/settings_section.dart';
import '../crypto/recovery_key.dart';
import '../crypto/vault_errors.dart';
import '../crypto/vault_key.dart';
import '../data/vault_providers.dart';
import '../vault_session.dart';
import 'fresh_auth.dart';
import 'master_password_form.dart';
import 'recovery_key_view.dart';
import 'secret_field.dart';
import 'vault_gate.dart';
import 'vault_ui_common.dart';

class VaultSettingsScreen extends ConsumerWidget {
  const VaultSettingsScreen({super.key});

  Future<void> _pickAutoLock(BuildContext context, WidgetRef ref, int current) async {
    final picked = await showDialog<int>(
      context: context,
      builder: (c) => SimpleDialog(
        title: Text(c.l10n.vltAutoLock),
        children: [
          RadioGroup<int>(
            groupValue: current,
            onChanged: (v) => Navigator.of(c).pop(v),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final d in kVaultAutoLockChoices)
                  RadioListTile<int>(
                    key: ValueKey('vault-autolock-${d.inSeconds}'),
                    value: d.inSeconds,
                    title: Text(c.l10n.vltAutoLockAfter(d.inMinutes)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
    if (picked != null) await ref.read(settingsRepositoryProvider).setVaultAutoLock(Duration(seconds: picked));
  }

  Future<void> _toggleBio(BuildContext context, WidgetRef ref, bool on) async {
    final service = ref.read(vaultKeyServiceProvider);
    final prompt = vaultBioPrompt(context.l10n);
    try {
      if (on) {
        await service.enableBiometric(ref.read(vaultSessionProvider.notifier).requireKey(), prompt);
      } else {
        await service.disableBiometric();
      }
    } on VaultUnlockError {
      // Cancelled or unavailable: the switch stays as it was.
    } catch (e) {
      AppLogger.warn('vault biometric toggle failed', e);
    }
    ref.invalidate(vaultBiometricEnabledProvider);
  }

  Future<void> _push(BuildContext context, Widget page) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => VaultGate(builder: (_) => page)));

  Future<void> _newRecoveryKey(BuildContext context, WidgetRef ref) async {
    if (!await ensureFreshAuth(context, ref) || !context.mounted) return;
    await _push(context, const _NewRecoveryKeyScreen());
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final k = context.tokens;
    final seconds = ref.watch(settingsProvider).value?.vaultAutoLockSeconds ?? 120;
    final bioAvailable = ref.watch(vaultBiometricAvailableProvider).value ?? false;
    final bioOn = ref.watch(vaultBiometricEnabledProvider).value ?? false;
    return Scaffold(
      appBar: AppBar(title: Text(l.vltSettings)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          children: [
            SettingsSection(
              title: l.vltAutoLock,
              children: [
                ListTile(
                  key: const ValueKey('vault-autolock'),
                  leading: const Icon(Icons.timer_outlined),
                  title: Text(l.vltAutoLock),
                  subtitle: Text('${l.vltAutoLockAfter(seconds ~/ 60)}\n${l.vltAutoLockNote}'),
                  isThreeLine: true,
                  onTap: () => _pickAutoLock(context, ref, seconds),
                ),
              ],
            ),
            SettingsSection(
              title: l.vltMasterPassword,
              children: [
                SwitchListTile(
                  key: const ValueKey('vault-bio-switch'),
                  secondary: const Icon(Icons.fingerprint_rounded),
                  title: Text(l.vltFingerprint),
                  subtitle: bioAvailable ? null : Text(l.vltFingerprintUnavailable),
                  value: bioOn,
                  onChanged: bioAvailable || bioOn ? (v) => _toggleBio(context, ref, v) : null,
                ),
                ListTile(
                  key: const ValueKey('vault-change-password'),
                  leading: const Icon(Icons.password_rounded),
                  title: Text(l.vltChangePassword),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _push(context, const _ChangeMasterPasswordScreen()),
                ),
                ListTile(
                  key: const ValueKey('vault-new-recovery'),
                  leading: const Icon(Icons.key_rounded),
                  title: Text(l.vltNewRecoveryKey),
                  subtitle: Text(l.vltNewRecoveryKeyBody),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _newRecoveryKey(context, ref),
                ),
              ],
            ),
            SettingsSection(
              title: l.vltHowProtected,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    l.vltHowProtectedBody,
                    key: const ValueKey('vault-how-protected'),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: k.textMuted, height: 1.6),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ChangeMasterPasswordScreen extends ConsumerStatefulWidget {
  const _ChangeMasterPasswordScreen();

  @override
  ConsumerState<_ChangeMasterPasswordScreen> createState() => _ChangeMasterPasswordScreenState();
}

class _ChangeMasterPasswordScreenState extends ConsumerState<_ChangeMasterPasswordScreen> {
  final _current = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _current.clear();
    _current.dispose();
    super.dispose();
  }

  Future<void> _save(Sensitive<String> next) async {
    if (_current.text.isEmpty) {
      setState(() => _error = context.l10n.vltFillIn);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final service = ref.read(vaultKeyServiceProvider);
    final session = ref.read(vaultSessionProvider.notifier);
    try {
      final VaultKey checked = await service.unlockWithPassword(Sensitive(_current.text));
      final bool same;
      try {
        same = checked.sameAs(session.requireKey());
      } finally {
        checked.destroy();
      }
      if (!same) throw const VaultWrongSecret();
      await service.changeMasterPassword(session.requireKey(), next);
      session.freshAuth();
      messenger.showSnackBar(SnackBar(content: Text(l.vltPasswordChangedOk)));
      navigator.pop();
    } on VaultUnlockError catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = vaultErrorText(l, e);
        });
      }
    } catch (e) {
      AppLogger.error('vault password change failed', e);
      if (mounted) {
        setState(() {
          _busy = false;
          _error = l.somethingWentWrong;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.vltChangePassword)),
      body: VaultPage(
        children: [
          SecretField(
            key: const ValueKey('vault-current-password'),
            controller: _current,
            label: l.vltCurrentPassword,
            enabled: !_busy,
            error: _error,
            textInputAction: TextInputAction.next,
            onChanged: (_) => setState(() => _error = null),
          ),
          const SizedBox(height: 24),
          MasterPasswordForm(submitLabel: l.save, busy: _busy, onSubmit: _save),
        ],
      ),
    );
  }
}

class _NewRecoveryKeyScreen extends ConsumerStatefulWidget {
  const _NewRecoveryKeyScreen();

  @override
  ConsumerState<_NewRecoveryKeyScreen> createState() => _NewRecoveryKeyScreenState();
}

class _NewRecoveryKeyScreenState extends ConsumerState<_NewRecoveryKeyScreen> {
  final RecoveryKey _key = RecoveryKey.generate();
  final _typed = TextEditingController();
  bool _confirming = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _key.destroy();
    _typed.clear();
    _typed.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    final typed = RecoveryKey.parse(_typed.text);
    final matches = typed != null && constantTimeEquals(typed.bytes, _key.bytes);
    typed?.destroy();
    if (!matches) {
      setState(() => _error = context.l10n.vltRecoveryMismatch);
      return;
    }
    setState(() => _busy = true);
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await ref
          .read(vaultKeyServiceProvider)
          .replaceRecoveryKey(ref.read(vaultSessionProvider.notifier).requireKey(), _key);
      messenger.showSnackBar(SnackBar(content: Text(l.vltRecoveryReplaced)));
      navigator.pop();
    } catch (e) {
      AppLogger.error('vault recovery replace failed', e);
      if (mounted) {
        setState(() {
          _busy = false;
          _error = l.somethingWentWrong;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final k = context.tokens;
    final text = Theme.of(context).textTheme;
    Widget body(String s) => Text(s, style: text.bodyLarge?.copyWith(color: k.textMuted, height: 1.5));
    Widget button(Key key, String label, VoidCallback? onPressed) => FilledButton(
      key: key,
      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
      onPressed: onPressed,
      child: Text(label),
    );
    return Scaffold(
      appBar: AppBar(title: Text(l.vltNewRecoveryKey)),
      body: VaultPage(
        children: _confirming
            ? [
                body(l.vltRecoveryConfirmBody),
                const SizedBox(height: 24),
                RecoveryKeyField(
                  key: const ValueKey('vault-recovery-typed'),
                  controller: _typed,
                  error: _error,
                  onChanged: (_) => setState(() => _error = null),
                  onSubmitted: (_) => _confirm(),
                ),
                const SizedBox(height: 24),
                button(
                  const ValueKey('vault-recovery-confirm'),
                  l.save,
                  _busy || _typed.text.trim().isEmpty ? null : _confirm,
                ),
              ]
            : [
                body(l.vltRecoveryBody),
                const SizedBox(height: 8),
                body(l.vltNewRecoveryKeyBody),
                const SizedBox(height: 24),
                RecoveryKeyView(display: _key.display),
                const SizedBox(height: 32),
                button(
                  const ValueKey('vault-recovery-next'),
                  l.continueLabel,
                  () => setState(() => _confirming = true),
                ),
              ],
      ),
    );
  }
}
