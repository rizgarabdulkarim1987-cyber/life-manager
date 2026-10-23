import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../ui/consent_sheet.dart';
import 'ai_config.dart';

/// True when the owner allows sending [f] to Groq. Asks once with the consent
/// sheet; a "no" is stored and never asked again (Settings → Online AI resets it).
/// Dismissing the sheet decides nothing and counts as no for this time.
Future<bool> ensureConsent(BuildContext c, AiFeature f) async {
  final container = ProviderScope.containerOf(c, listen: false);
  final s = await container.read(settingsProvider.future);
  final current = consentOf(f, s);
  if (current != null) return current == ConsentState.granted.name;
  if (!c.mounted) return false;
  final answer = await showConsentSheet(c, f);
  if (answer == null) return false;
  await container.read(settingsRepositoryProvider).setConsent(f, answer);
  return answer == ConsentState.granted;
}
