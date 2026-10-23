import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';

/// The rounded surface card used across the finance screens (matches Home).
class Panel extends StatelessWidget {
  const Panel({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.onTap});

  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final k = context.tokens;
    final radius = BorderRadius.circular(AppTokens.radiusCard);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: k.surface,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: k.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
