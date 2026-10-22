import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/core/theme/app_theme.dart';
import 'package:life_manager/core/theme/tokens.dart';

void main() {
  test('dark theme uses approved tokens', () {
    final t = buildAppTheme(Brightness.dark);
    final k = t.extension<AppTokens>()!;
    expect(t.scaffoldBackgroundColor, const Color(0xFF060A13));
    expect(k.accent, const Color(0xFF3B82FF));
    expect(k.text, const Color(0xFFEEF2FA));
    expect(t.colorScheme.primary, k.accent);
    expect(t.textTheme.bodyMedium!.fontFamily, kAppFont);
  });

  test('light theme has its own tokens and keeps accent hue', () {
    final k = buildAppTheme(Brightness.light).extension<AppTokens>()!;
    expect(HSVColor.fromColor(k.accent).hue,
        closeTo(HSVColor.fromColor(const Color(0xFF3B82FF)).hue, 3));
    expect(k.bg.computeLuminance(), greaterThan(0.8));
  });

  test('text on surfaces meets 4.5:1 in both themes', () {
    for (final b in Brightness.values) {
      final k = buildAppTheme(b).extension<AppTokens>()!;
      expect(contrastRatio(k.text, k.surface), greaterThanOrEqualTo(4.5));
      expect(contrastRatio(k.textMuted, k.surface), greaterThanOrEqualTo(4.5));
      expect(contrastRatio(k.textMuted, k.surfaceHigh), greaterThanOrEqualTo(4.5));
    }
  });

  test('accent is legible as text on bg in both themes (3:1 large)', () {
    for (final b in Brightness.values) {
      final k = buildAppTheme(b).extension<AppTokens>()!;
      expect(contrastRatio(k.accent, k.bg), greaterThanOrEqualTo(3));
    }
  });

  test('cards use the 20 radius', () {
    final shape = buildAppTheme(Brightness.dark).cardTheme.shape as RoundedRectangleBorder;
    expect(shape.borderRadius, BorderRadius.circular(20));
  });

  test('contrastRatio of black on white is 21', () {
    expect(contrastRatio(const Color(0xFF000000), const Color(0xFFFFFFFF)), closeTo(21, 0.01));
  });
}
