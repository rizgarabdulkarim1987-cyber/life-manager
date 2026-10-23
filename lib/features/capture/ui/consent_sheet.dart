import 'package:flutter/material.dart';

import '../../../core/l10n/ckb_fallback_localizations.dart';
import '../../../core/theme/tokens.dart';
import '../ai/ai_config.dart';

String consentText(BuildContext context, AiFeature f) => switch (f) {
  AiFeature.voice => context.l10n.aiConsentVoice,
  AiFeature.parse => context.l10n.aiConsentParse,
  AiFeature.receipt => context.l10n.aiConsentReceipt,
};

/// Asks once, before anything about [f] leaves the phone. Null when dismissed.
Future<ConsentState?> showConsentSheet(BuildContext context, AiFeature f) => showModalBottomSheet<ConsentState>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => ConsentSheet(feature: f),
);

class ConsentSheet extends StatelessWidget {
  const ConsentSheet({super.key, required this.feature});

  final AiFeature feature;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final k = context.tokens;
    final text = Theme.of(context).textTheme;
    Widget point(IconData icon, String s, {Color? color}) => Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color ?? k.textMuted),
          const SizedBox(width: 12),
          Expanded(
            child: Text(s, style: text.bodyMedium?.copyWith(color: k.text)),
          ),
        ],
      ),
    );
    return SafeArea(
      key: const ValueKey('consent-sheet'),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l.consentTitle, style: text.titleLarge?.copyWith(color: k.text)),
              const SizedBox(height: 4),
              point(
                switch (feature) {
                  AiFeature.voice => Icons.mic_none_rounded,
                  AiFeature.parse => Icons.notes_rounded,
                  AiFeature.receipt => Icons.receipt_long_rounded,
                },
                consentText(context, feature),
                color: k.accent,
              ),
              point(Icons.public_rounded, l.consentWho),
              point(Icons.lock_outline_rounded, l.consentNever, color: k.success),
              point(Icons.toggle_off_outlined, l.consentOff),
              const SizedBox(height: 24),
              FilledButton(
                key: const ValueKey('consent-allow'),
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                onPressed: () => Navigator.of(context).pop(ConsentState.granted),
                child: Text(l.consentAllow),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                key: const ValueKey('consent-decline'),
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                onPressed: () => Navigator.of(context).pop(ConsentState.declined),
                child: Text(l.consentDecline, textAlign: TextAlign.center),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
