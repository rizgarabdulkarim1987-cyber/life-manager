import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/ckb_fallback_localizations.dart';
import '../../../core/security/sensitive.dart';
import '../../../core/theme/tokens.dart';
import '../crypto/vault_errors.dart';
import '../data/vault_providers.dart';
import '../domain/password_strength.dart';
import '../platform/biometric_key_store.dart';

String vaultCategoryLabel(AppLocalizations l, String key) => switch (key) {
  'personal' => l.vltCatPersonal,
  'business' => l.vltCatBusiness,
  'social' => l.vltCatSocial,
  'banking' => l.vltCatBanking,
  'hosting' => l.vltCatHosting,
  'domain' => l.vltCatDomain,
  'email' => l.vltCatEmail,
  'marketing' => l.vltCatMarketing,
  'dev' => l.vltCatDev,
  _ => l.vltCatOther,
};

IconData vaultCategoryIcon(String key) => switch (key) {
  'personal' => Icons.person_outline_rounded,
  'business' => Icons.work_outline_rounded,
  'social' => Icons.forum_outlined,
  'banking' => Icons.account_balance_outlined,
  'hosting' => Icons.dns_outlined,
  'domain' => Icons.language_rounded,
  'email' => Icons.mail_outline_rounded,
  'marketing' => Icons.campaign_outlined,
  'dev' => Icons.code_rounded,
  _ => Icons.key_outlined,
};

BioPromptText vaultBioPrompt(AppLocalizations l) =>
    BioPromptText(title: l.vltBioTitle, subtitle: l.vltBioSubtitle, cancel: l.vltUsePassword);

String _clock(Duration d) => '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

/// The owner-facing text for an unlock failure. Never echoes input.
String vaultErrorText(AppLocalizations l, Object e) => switch (e) {
  VaultWrongSecret(:final attemptsLeft?) when attemptsLeft <= 3 =>
    '${l.vltWrongSecret} ${l.vltAttemptsLeft(attemptsLeft)}',
  VaultWrongSecret() => l.vltWrongSecret,
  VaultLockedOut(:final remaining) => l.tryAgainIn(_clock(remaining)),
  VaultCorrupt() => l.vltCorrupt,
  VaultBiometricInvalidated() => l.vltBioInvalidated,
  _ => l.somethingWentWrong,
};

String strengthLabel(AppLocalizations l, Strength s) => switch (s) {
  Strength.weak => l.passwordStrengthWeak,
  Strength.fair => l.passwordStrengthFair,
  Strength.strong => l.passwordStrengthStrong,
  Strength.veryStrong => l.vltStrengthVeryStrong,
};

Color strengthColor(AppTokens k, Strength s) => switch (s) {
  Strength.weak => k.danger,
  Strength.fair => k.warning,
  Strength.strong || Strength.veryStrong => k.success,
};

/// Copies through the sensitive clipboard and says so. [secret] picks the
/// message that promises the 30 s clear.
Future<void> copyToClipboard(BuildContext context, WidgetRef ref, Sensitive<String> value, {bool secret = true}) async {
  final l = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  final ok = await ref.read(secretClipboardProvider).copy(value);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(!ok ? l.vltCopyFailed : (secret ? l.vltCopied : l.vltCopiedPlain))));
}

/// Body padding and width shared by the vault's form-like screens.
class VaultPage extends StatelessWidget {
  const VaultPage({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Align(
      alignment: AlignmentDirectional.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: ListView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 32), children: children),
      ),
    ),
  );
}
