import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';

/// Colour for a share used, in basis points: warning from 80%, danger from 100%.
Color usageColor(AppTokens k, int? usedBp) => usedBp == null || usedBp < 8000
    ? k.accent
    : usedBp < 10000
    ? k.warning
    : k.danger;

/// A rounded progress bar; [valueBp] is clamped to 0–100%.
class UsageBar extends StatelessWidget {
  const UsageBar({super.key, required this.barKey, required this.valueBp, required this.color});

  final Key barKey;
  final int valueBp;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final k = context.tokens;
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(
        key: barKey,
        value: valueBp.clamp(0, 10000) / 10000,
        minHeight: 8,
        color: color,
        backgroundColor: k.surfaceHigh,
      ),
    );
  }
}
