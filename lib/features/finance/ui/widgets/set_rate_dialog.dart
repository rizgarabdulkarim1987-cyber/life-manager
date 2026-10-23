import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/ckb_fallback_localizations.dart';
import '../../data/finance_providers.dart';
import '../../data/rates_repository.dart';
import 'text_prompt_dialog.dart';

/// Asks for today's USD → IQD rate and stores it (one rate per day).
Future<void> showSetRateDialog(BuildContext context, WidgetRef ref) async {
  final l = context.l10n;
  final rateE6 = await showDialog<int>(
    context: context,
    builder: (_) => TextPromptDialog<int>(
      title: l.finRateTitle,
      label: l.finRateLabel,
      parse: parseRateE6,
      invalidText: l.finRateInvalid,
      numeric: true,
      fieldKey: const ValueKey('rate-input'),
      saveKey: const ValueKey('rate-save'),
    ),
  );
  if (rateE6 == null) return;
  final now = DateTime.now();
  await ref
      .read(ratesRepositoryProvider)
      .setRate(base: 'USD', quote: 'IQD', rateE6: rateE6, effectiveFrom: DateTime.utc(now.year, now.month, now.day));
}
