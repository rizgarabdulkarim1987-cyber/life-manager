import 'package:flutter/material.dart';

import '../../../core/l10n/ckb_fallback_localizations.dart';
import '../../../core/security/sensitive.dart';
import '../../../core/text/digits.dart';
import '../../../core/theme/tokens.dart';
import '../data/vault_key_service.dart';
import '../domain/password_strength.dart';
import 'secret_field.dart';
import 'vault_ui_common.dart';

/// New master password twice, with the length hint (plan Decision 6). Used by
/// setup, the forced change after a recovery-key unlock, and vault settings.
class MasterPasswordForm extends StatefulWidget {
  const MasterPasswordForm({super.key, required this.submitLabel, required this.onSubmit, this.busy = false});

  final String submitLabel;
  final bool busy;
  final Future<void> Function(Sensitive<String> password) onSubmit;

  @override
  State<MasterPasswordForm> createState() => _MasterPasswordFormState();
}

class _MasterPasswordFormState extends State<MasterPasswordForm> {
  final _pw = TextEditingController();
  final _confirm = TextEditingController();
  String? _mismatch;

  @override
  void dispose() {
    _pw.clear();
    _confirm.clear();
    _pw.dispose();
    _confirm.dispose();
    super.dispose();
  }

  bool get _ready => masterPasswordLongEnough(_pw.text) && _confirm.text.isNotEmpty && !widget.busy;

  Future<void> _submit() async {
    if (!_ready) return;
    if (normalizeDigits(_pw.text) != normalizeDigits(_confirm.text)) {
      setState(() => _mismatch = context.l10n.passwordsDontMatch);
      return;
    }
    await widget.onSubmit(Sensitive(_pw.text));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final k = context.tokens;
    final strength = masterPasswordStrength(normalizeDigits(_pw.text));
    final tooShort = _pw.text.isNotEmpty && !masterPasswordLongEnough(_pw.text);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SecretField(
          key: const ValueKey('vault-new-password'),
          controller: _pw,
          label: l.vltNewPassword,
          autofocus: true,
          enabled: !widget.busy,
          textInputAction: TextInputAction.next,
          helper: tooShort ? l.vltPasswordTooShort(kMinMasterPasswordLength) : null,
          onChanged: (_) => setState(() => _mismatch = null),
        ),
        const SizedBox(height: 8),
        if (_pw.text.isNotEmpty)
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (strength.index + 1) / Strength.values.length,
                    minHeight: 6,
                    color: strengthColor(k, strength),
                    backgroundColor: k.surfaceHigh,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  strengthLabel(l, strength),
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(color: strengthColor(k, strength)),
                ),
              ),
            ],
          ),
        const SizedBox(height: 16),
        SecretField(
          key: const ValueKey('vault-confirm-password'),
          controller: _confirm,
          label: l.confirmPassword,
          enabled: !widget.busy,
          error: _mismatch,
          textInputAction: TextInputAction.done,
          onChanged: (_) => setState(() => _mismatch = null),
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: 24),
        FilledButton(
          key: const ValueKey('vault-password-submit'),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          onPressed: _ready ? _submit : null,
          child: widget.busy
              ? SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2, color: k.onAccent))
              : Text(widget.submitLabel),
        ),
      ],
    );
  }
}
