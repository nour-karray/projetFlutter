import 'package:flutter/material.dart';

/// Palette partagée (UI).
abstract final class AppThemePalette {
  static const Color primary = Color(0xFF2563EB);
  static const Color secondary = Color(0xFF0EA5A4);
  static const Color tertiary = Color(0xFF7C3AED);
  static const Color danger = Color(0xFFDC2626);
  static const Color success = Color(0xFF16A34A);
  static const Color warning = Color(0xFFD97706);

  static LinearGradient heroGradient([bool isDark = false]) {
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: isDark
          ? const <Color>[Color(0xFF1E3A8A), Color(0xFF172554)]
          : const <Color>[Color(0xFF3B82F6), Color(0xFF1D4ED8)],
    );
  }

  static List<BoxShadow> softShadow([bool isDark = false]) {
    return <BoxShadow>[
      BoxShadow(
        color:
            (isDark ? Colors.black : const Color(0xFF1E293B)).withValues(alpha: isDark ? 0.55 : 0.12),
        blurRadius: 22,
        offset: const Offset(0, 14),
      ),
      BoxShadow(
        color:
            primary.withValues(alpha: isDark ? 0.16 : 0.08),
        blurRadius: 12,
        offset: const Offset(0, 6),
      ),
    ];
  }
}

abstract final class AppTheme {
  static ThemeData light() {
    final base = ThemeData(useMaterial3: true, brightness: Brightness.light);
    return base.copyWith(
      colorScheme: ColorScheme.fromSeed(
        brightness: Brightness.light,
        seedColor: AppThemePalette.primary,
        primary: AppThemePalette.primary,
        secondary: AppThemePalette.secondary,
        tertiary: AppThemePalette.tertiary,
      ),
      appBarTheme: const AppBarTheme(centerTitle: false, scrolledUnderElevation: 0),
    );
  }

  static ThemeData dark() {
    final base = ThemeData(useMaterial3: true, brightness: Brightness.dark);
    return base.copyWith(
      colorScheme: ColorScheme.fromSeed(
        brightness: Brightness.dark,
        seedColor: AppThemePalette.primary,
        primary: AppThemePalette.primary,
        secondary: AppThemePalette.secondary,
        tertiary: AppThemePalette.tertiary,
      ),
      appBarTheme: const AppBarTheme(centerTitle: false, scrolledUnderElevation: 0),
    );
  }
}
