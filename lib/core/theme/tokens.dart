import 'dart:math' as math;

import 'package:flutter/material.dart';

const kAppFont = 'Vazirmatn';

/// Design tokens from the approved mockup (spec §7, plan Global Constraints).
@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  const AppTokens({
    required this.bg,
    required this.surface,
    required this.surfaceHigh,
    required this.border,
    required this.text,
    required this.textMuted,
    required this.accent,
    required this.onAccent,
    required this.success,
    required this.danger,
    required this.warning,
  });

  final Color bg;
  final Color surface;
  final Color surfaceHigh;
  final Color border;
  final Color text;
  final Color textMuted;
  final Color accent;
  final Color onAccent;
  final Color success;
  final Color danger;
  final Color warning;

  static const double radiusCard = 20;
  static const double radiusSmall = 14;

  static const dark = AppTokens(
    bg: Color(0xFF060A13),
    surface: Color(0xFF0B1224),
    surfaceHigh: Color(0xFF0F1A33),
    border: Color(0xFF1B2744),
    text: Color(0xFFEEF2FA),
    textMuted: Color(0xFFA3ADC2),
    accent: Color(0xFF3B82FF),
    // White on #3B82FF is 3.7:1; midnight on it is 5.6:1.
    onAccent: Color(0xFF060A13),
    success: Color(0xFF3DDC97),
    danger: Color(0xFFFF6B7A),
    warning: Color(0xFFF5B544),
  );

  static const light = AppTokens(
    bg: Color(0xFFF5F7FB),
    surface: Color(0xFFFFFFFF),
    surfaceHigh: Color(0xFFEEF2F9),
    border: Color(0xFFD9E0EC),
    text: Color(0xFF0B1224),
    textMuted: Color(0xFF4A5672),
    // Darkened so white labels on filled buttons reach 4.5:1.
    accent: Color(0xFF2563EB),
    onAccent: Color(0xFFFFFFFF),
    success: Color(0xFF13804F),
    danger: Color(0xFFC9283A),
    warning: Color(0xFF9A6200),
  );

  @override
  AppTokens copyWith({
    Color? bg,
    Color? surface,
    Color? surfaceHigh,
    Color? border,
    Color? text,
    Color? textMuted,
    Color? accent,
    Color? onAccent,
    Color? success,
    Color? danger,
    Color? warning,
  }) => AppTokens(
    bg: bg ?? this.bg,
    surface: surface ?? this.surface,
    surfaceHigh: surfaceHigh ?? this.surfaceHigh,
    border: border ?? this.border,
    text: text ?? this.text,
    textMuted: textMuted ?? this.textMuted,
    accent: accent ?? this.accent,
    onAccent: onAccent ?? this.onAccent,
    success: success ?? this.success,
    danger: danger ?? this.danger,
    warning: warning ?? this.warning,
  );

  @override
  AppTokens lerp(AppTokens? other, double t) {
    if (other == null) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppTokens(
      bg: l(bg, other.bg),
      surface: l(surface, other.surface),
      surfaceHigh: l(surfaceHigh, other.surfaceHigh),
      border: l(border, other.border),
      text: l(text, other.text),
      textMuted: l(textMuted, other.textMuted),
      accent: l(accent, other.accent),
      onAccent: l(onAccent, other.onAccent),
      success: l(success, other.success),
      danger: l(danger, other.danger),
      warning: l(warning, other.warning),
    );
  }
}

/// WCAG 2.x contrast ratio between two opaque colors.
double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

extension AppTokensX on BuildContext {
  AppTokens get tokens => Theme.of(this).extension<AppTokens>()!;
}
