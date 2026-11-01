import 'package:flutter/material.dart';

/// Centralized theme definitions and dynamic color tokens
/// supporting Dark, Light, and System adaptive themes.
class AppColors {
  // Surfaces & Backgrounds
  static Color background(bool isDark) =>
      isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);

  static Color surface(bool isDark) =>
      isDark ? const Color(0xFF1E293B) : const Color(0xFFFFFFFF);

  static Color panelBackground(bool isDark) =>
      isDark ? const Color(0xFF161E2E) : const Color(0xFFF8FAFC);

  static Color cardBackground(bool isDark) =>
      isDark ? const Color(0xFF1E293B) : const Color(0xFFFFFFFF);

  static Color subtleCard(bool isDark) =>
      isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);

  static Color minimapPanel(bool isDark) =>
      isDark ? const Color(0xFF111827) : const Color(0xFFF8FAFC);

  static Color minimapCanvas(bool isDark) =>
      isDark ? const Color(0xFF0B0F19) : const Color(0xFFF1F5F9);

  // Borders & Dividers
  static Color border(bool isDark) =>
      isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1);

  static Color borderSubtle(bool isDark) =>
      isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);

  // Typography
  static Color textPrimary(bool isDark) =>
      isDark ? Colors.white : const Color(0xFF0F172A);

  static Color textSecondary(bool isDark) =>
      isDark ? Colors.white70 : const Color(0xFF475569);

  static Color textMuted(bool isDark) =>
      isDark ? Colors.white54 : const Color(0xFF64748B);

  // Form Fields & Controls
  static Color inputFill(bool isDark) =>
      isDark ? const Color(0xFF0F172A) : Colors.white;

  static Color controlPill(bool isDark) =>
      isDark ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0);

  static Color controlPillHover(bool isDark) =>
      isDark ? const Color(0xFF1E293B) : const Color(0xFFCBD5E1);

  // Brand & Accent Colors
  static Color primary(bool isDark) =>
      isDark ? Colors.cyanAccent : const Color(0xFF0284C7);

  static Color primarySubtle(bool isDark) =>
      isDark ? Colors.cyanAccent.withValues(alpha: 0.15) : const Color(0xFF0284C7).withValues(alpha: 0.12);

  static Color secondary(bool isDark) =>
      isDark ? Colors.tealAccent : const Color(0xFF0D9488);

  // Arena Canvas Specific
  static Color arenaFloor(bool isDark) =>
      isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);

  static Color arenaGrid(bool isDark) =>
      isDark ? const Color(0xFF1E293B).withValues(alpha: 0.6) : const Color(0xFFCBD5E1).withValues(alpha: 0.8);

  static Color arenaWallFill(bool isDark) =>
      isDark ? const Color(0xFF1E293B) : const Color(0xFFCBD5E1);

  static Color arenaWallBorder(bool isDark) =>
      isDark ? const Color(0xFF64748B) : const Color(0xFF475569);
}

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF0F172A),
      colorScheme: const ColorScheme.dark(
        primary: Colors.cyanAccent,
        secondary: Colors.tealAccent,
        surface: Color(0xFF1E293B),
        onSurface: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1E293B),
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      cardTheme: const CardThemeData(
        color: Color(0xFF1E293B),
        elevation: 0,
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFF334155),
        thickness: 1.0,
      ),
      iconTheme: const IconThemeData(
        color: Colors.white,
      ),
      useMaterial3: true,
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFF1F5F9),
      colorScheme: const ColorScheme.light(
        primary: Color(0xFF0284C7),
        secondary: Color(0xFF0D9488),
        surface: Color(0xFFFFFFFF),
        onSurface: Color(0xFF0F172A),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFFFFFFF),
        foregroundColor: Color(0xFF0F172A),
        elevation: 1,
        shadowColor: Color(0x1A000000),
        scrolledUnderElevation: 1,
      ),
      cardTheme: const CardThemeData(
        color: Color(0xFFFFFFFF),
        elevation: 0,
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFFCBD5E1),
        thickness: 1.0,
      ),
      iconTheme: const IconThemeData(
        color: Color(0xFF0F172A),
      ),
      useMaterial3: true,
    );
  }
}
