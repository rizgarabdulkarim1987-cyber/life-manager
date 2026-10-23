import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/ckb_fallback_localizations.dart';
import '../../../core/security/sensitive.dart';
import '../../../core/theme/tokens.dart';
import 'vault_ui_common.dart';

/// The recovery key as eight groups of four, always left to right, wrapping
/// by group so it never breaks inside one.
class RecoveryKeyView extends ConsumerWidget {
  const RecoveryKeyView({super.key, required this.display});

  /// `ABCD-EFGH-…` from `RecoveryKey.display`.
  final String display;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final k = context.tokens;
    final style = Theme.of(context).textTheme.titleLarge?.copyWith(
      color: k.text,
      fontFamily: 'monospace',
      fontFeatures: const [FontFeature.tabularFigures()],
      letterSpacing: 1.5,
    );
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: k.surfaceHigh,
        borderRadius: BorderRadius.circular(AppTokens.radiusSmall),
        border: Border.all(color: k.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Directionality(
            textDirection: TextDirection.ltr,
            child: Semantics(
              label: l.vltRecoveryKey,
              child: Wrap(
                key: const ValueKey('vault-recovery-key'),
                alignment: WrapAlignment.center,
                spacing: 14,
                runSpacing: 10,
                children: [for (final g in display.split('-')) Text(g, style: style)],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Align(
            child: TextButton.icon(
              key: const ValueKey('vault-recovery-copy'),
              icon: const Icon(Icons.copy_rounded, size: 18),
              label: Text(l.vltCopy),
              onPressed: () => copyToClipboard(context, ref, Sensitive(display)),
            ),
          ),
        ],
      ),
    );
  }
}

/// A single-line, left-to-right field for typing a recovery key.
class RecoveryKeyField extends StatelessWidget {
  const RecoveryKeyField({super.key, required this.controller, this.error, this.onChanged, this.onSubmitted});

  final TextEditingController controller;
  final String? error;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return TextField(
      controller: controller,
      textDirection: TextDirection.ltr,
      autocorrect: false,
      enableSuggestions: false,
      enableIMEPersonalizedLearning: false,
      keyboardType: TextInputType.visiblePassword,
      textCapitalization: TextCapitalization.characters,
      style: const TextStyle(fontFamily: 'monospace', letterSpacing: 1),
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        labelText: l.vltRecoveryKey,
        helperText: l.vltRecoveryKeyHint,
        helperMaxLines: 2,
        errorText: error,
        errorMaxLines: 3,
      ),
    );
  }
}
