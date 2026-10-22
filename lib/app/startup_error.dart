import 'package:flutter/material.dart';

import '../core/l10n/ckb_fallback_localizations.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/tokens.dart';

/// Shown when the database can't be opened at launch. The saved language isn't
/// readable yet, so it follows the phone's language.
class StartupErrorScreen extends StatelessWidget {
  const StartupErrorScreen({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: buildAppTheme(Brightness.dark),
    supportedLocales: kSupportedLocales,
    localizationsDelegates: appLocalizationDelegates,
    home: Builder(
      builder: (context) {
        final k = context.tokens;
        final text = Theme.of(context).textTheme;
        return Scaffold(
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline_rounded, size: 48, color: k.warning),
                    const SizedBox(height: 16),
                    Text(
                      context.l10n.startupFailed,
                      textAlign: TextAlign.center,
                      style: text.titleMedium?.copyWith(color: k.text),
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      key: const ValueKey('startup-retry'),
                      onPressed: onRetry,
                      child: Text(context.l10n.retry),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}
