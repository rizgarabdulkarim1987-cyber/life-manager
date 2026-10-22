import 'package:flutter/material.dart';

import '../../core/l10n/ckb_fallback_localizations.dart';
import '../../core/theme/tokens.dart';

/// Stand-in for a section that lands in a later phase.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({super.key, required this.title, required this.phase, required this.icon});

  final String title;
  final int phase;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final k = context.tokens;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 48, color: k.textMuted),
              const SizedBox(height: 16),
              Text(
                context.l10n.comingInPhase(phase),
                textAlign: TextAlign.center,
                style: text.titleMedium?.copyWith(color: k.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
