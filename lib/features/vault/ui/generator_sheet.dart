import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/ckb_fallback_localizations.dart';
import '../../../core/security/sensitive.dart';
import '../../../core/theme/tokens.dart';
import '../domain/password_generator.dart';
import 'vault_ui_common.dart';

/// Opens the generator. With [onUse] (the item form) it offers "use this
/// password"; without it, only copy.
Future<void> showGeneratorSheet(BuildContext context, {ValueChanged<Sensitive<String>>? onUse}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => GeneratorSheet(onUse: onUse),
    );

class GeneratorSheet extends ConsumerStatefulWidget {
  const GeneratorSheet({super.key, this.onUse});

  final ValueChanged<Sensitive<String>>? onUse;

  @override
  ConsumerState<GeneratorSheet> createState() => _GeneratorSheetState();
}

class _GeneratorSheetState extends ConsumerState<GeneratorSheet> {
  GeneratorOptions _o = const GeneratorOptions();
  late Sensitive<String> _pw = generatePassword(_o);

  void _set(GeneratorOptions next) {
    if (!next.anyClass) return; // The last class can't be switched off.
    setState(() {
      _o = next;
      _pw = generatePassword(next);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final k = context.tokens;
    final text = Theme.of(context).textTheme;
    Widget toggle(Key key, String label, bool value, GeneratorOptions Function(bool) apply) => SwitchListTile(
      key: key,
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      value: value,
      onChanged: (v) => _set(apply(v)),
    );
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          key: const ValueKey('vault-generator'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.vltGenerator, style: text.titleLarge?.copyWith(color: k.text)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: k.surfaceHigh,
                borderRadius: BorderRadius.circular(AppTokens.radiusSmall),
                border: Border.all(color: k.border),
              ),
              child: Text(
                _pw.value,
                key: const ValueKey('vault-generator-value'),
                textDirection: TextDirection.ltr,
                textAlign: TextAlign.center,
                style: text.titleMedium?.copyWith(color: k.text, fontFamily: 'monospace', height: 1.4),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l.vltEntropy(estimateEntropyBits(_o).round()),
              textAlign: TextAlign.center,
              style: text.bodySmall?.copyWith(color: k.textMuted),
            ),
            const SizedBox(height: 12),
            Text(l.vltLength(_o.length), style: text.labelLarge?.copyWith(color: k.text)),
            Slider(
              key: const ValueKey('vault-generator-length'),
              min: kGeneratorMinLength.toDouble(),
              max: kGeneratorMaxLength.toDouble(),
              divisions: kGeneratorMaxLength - kGeneratorMinLength,
              value: _o.length.toDouble(),
              label: '${_o.length}',
              onChanged: (v) => _set(_o.copyWith(length: v.round())),
            ),
            toggle(const ValueKey('gen-lower'), l.vltLower, _o.lower, (v) => _o.copyWith(lower: v)),
            toggle(const ValueKey('gen-upper'), l.vltUpper, _o.upper, (v) => _o.copyWith(upper: v)),
            toggle(const ValueKey('gen-digits'), l.vltDigits, _o.digits, (v) => _o.copyWith(digits: v)),
            toggle(const ValueKey('gen-symbols'), l.vltSymbols, _o.symbols, (v) => _o.copyWith(symbols: v)),
            toggle(
              const ValueKey('gen-lookalikes'),
              l.vltAvoidLookAlikes,
              _o.avoidLookAlikes,
              (v) => _o.copyWith(avoidLookAlikes: v),
            ),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  key: const ValueKey('vault-generator-again'),
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(l.vltRegenerate),
                  onPressed: () => setState(() => _pw = generatePassword(_o)),
                ),
                OutlinedButton.icon(
                  key: const ValueKey('vault-generator-copy'),
                  icon: const Icon(Icons.copy_rounded),
                  label: Text(l.vltCopy),
                  onPressed: () => copyToClipboard(context, ref, _pw),
                ),
              ],
            ),
            if (widget.onUse != null) ...[
              const SizedBox(height: 12),
              FilledButton(
                key: const ValueKey('vault-generator-use'),
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                onPressed: () {
                  widget.onUse!(_pw);
                  Navigator.of(context).pop();
                },
                child: Text(l.vltUseThis),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
