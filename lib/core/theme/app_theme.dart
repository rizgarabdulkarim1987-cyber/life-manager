import 'package:flutter/material.dart';

import 'tokens.dart';

ThemeData buildAppTheme(Brightness brightness) {
  final k = brightness == Brightness.dark ? AppTokens.dark : AppTokens.light;

  final scheme = ColorScheme(
    brightness: brightness,
    primary: k.accent,
    onPrimary: k.onAccent,
    primaryContainer: k.surfaceHigh,
    onPrimaryContainer: k.text,
    secondary: k.accent,
    onSecondary: k.onAccent,
    secondaryContainer: k.surfaceHigh,
    onSecondaryContainer: k.text,
    error: k.danger,
    onError: k.onAccent,
    surface: k.surface,
    onSurface: k.text,
    onSurfaceVariant: k.textMuted,
    surfaceContainerLowest: k.bg,
    surfaceContainerLow: k.surface,
    surfaceContainer: k.surface,
    surfaceContainerHigh: k.surfaceHigh,
    surfaceContainerHighest: k.surfaceHigh,
    outline: k.border,
    outlineVariant: k.border,
  );

  final base = ThemeData(useMaterial3: true, brightness: brightness, colorScheme: scheme, fontFamily: kAppFont);

  return base.copyWith(
    scaffoldBackgroundColor: k.bg,
    extensions: [k],
    cardTheme: CardThemeData(
      color: k.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTokens.radiusCard),
        side: BorderSide(color: k.border),
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: k.bg,
      foregroundColor: k.text,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: k.surface,
      indicatorColor: k.surfaceHigh,
      surfaceTintColor: Colors.transparent,
      height: 72,
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: k.accent,
      foregroundColor: k.onAccent,
      shape: const CircleBorder(),
    ),
    dividerTheme: DividerThemeData(color: k.border, space: 1, thickness: 1),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: k.surfaceHigh,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTokens.radiusSmall),
        borderSide: BorderSide(color: k.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTokens.radiusSmall),
        borderSide: BorderSide(color: k.border),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: k.surfaceHigh,
      contentTextStyle: TextStyle(color: k.text, fontFamily: kAppFont),
    ),
  );
}
