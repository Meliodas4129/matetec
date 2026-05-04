// lib/theme/app_theme.dart
import 'package:flutter/material.dart';

/// Paleta centralizada de MateTec — dark mode + índigo.
/// Usar SIEMPRE estos colores en lugar de hardcodear hex en cada pantalla.
class AppColors {
  AppColors._();

  // ── Marca / acento principal ────────────────────────────────────────────
  /// Índigo principal — color de marca de la app
  static const Color primary = Color(0xFF6366F1); // indigo-500
  static const Color primaryDark = Color(0xFF4F46E5); // indigo-600
  static const Color primaryLight = Color(0xFF818CF8); // indigo-400
  static const Color primarySoft = Color(0xFF312E81); // indigo-900 (para fondos suaves)

  // ── Fondos / superficies ────────────────────────────────────────────────
  /// Fondo principal de las pantallas
  static const Color background = Color(0xFF0F172A); // slate-900
  /// Tarjetas y superficies elevadas
  static const Color surface = Color(0xFF1E293B); // slate-800
  /// Variante de superficie (chips, hover, divisores fuertes)
  static const Color surfaceVariant = Color(0xFF334155); // slate-700
  /// Bordes sutiles
  static const Color border = Color(0xFF334155); // slate-700

  // ── Texto ───────────────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFFF1F5F9); // slate-100
  static const Color textSecondary = Color(0xFF94A3B8); // slate-400
  static const Color textMuted = Color(0xFF64748B); // slate-500

  // ── Estados ─────────────────────────────────────────────────────────────
  static const Color success = Color(0xFF10B981); // emerald-500
  static const Color warning = Color(0xFFF59E0B); // amber-500
  static const Color danger = Color(0xFFEF4444); // red-500

  // ── Colores por tema (operación) — versiones para dark mode ─────────────
  /// Sumas
  static const Color temaSumas = Color(0xFFF87171); // red-400
  static const Color temaSumasSoft = Color(0xFF7F1D1D); // red-900
  /// Restas
  static const Color temaRestas = Color(0xFF60A5FA); // blue-400
  static const Color temaRestasSoft = Color(0xFF1E3A8A); // blue-900
  /// Multiplicación
  static const Color temaMult = Color(0xFF34D399); // emerald-400
  static const Color temaMultSoft = Color(0xFF064E3B); // emerald-900
  /// División
  static const Color temaDiv = Color(0xFFFBBF24); // amber-400
  static const Color temaDivSoft = Color(0xFF78350F); // amber-900

  // ── Helpers ─────────────────────────────────────────────────────────────
  /// Versión semitransparente (útil para superposiciones)
  static Color softPrimary(double opacity) =>
      primary.withValues(alpha: opacity);
}

/// Theme global de la app.
class AppTheme {
  AppTheme._();

  static ThemeData dark = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.background,

    colorScheme: const ColorScheme.dark(
      primary: AppColors.primary,
      onPrimary: Colors.white,
      secondary: AppColors.primaryLight,
      onSecondary: Colors.white,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      error: AppColors.danger,
      onError: Colors.white,
    ),

    fontFamily: 'Roboto',

    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(
        color: AppColors.textPrimary,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
    ),

    cardColor: AppColors.surface,
    dividerColor: AppColors.border,
    iconTheme: const IconThemeData(color: AppColors.textSecondary),

    textTheme: const TextTheme(
      displayLarge: TextStyle(color: AppColors.textPrimary),
      displayMedium: TextStyle(color: AppColors.textPrimary),
      headlineLarge: TextStyle(color: AppColors.textPrimary),
      headlineMedium: TextStyle(color: AppColors.textPrimary),
      headlineSmall: TextStyle(color: AppColors.textPrimary),
      titleLarge: TextStyle(color: AppColors.textPrimary),
      titleMedium: TextStyle(color: AppColors.textPrimary),
      titleSmall: TextStyle(color: AppColors.textPrimary),
      bodyLarge: TextStyle(color: AppColors.textPrimary),
      bodyMedium: TextStyle(color: AppColors.textPrimary),
      bodySmall: TextStyle(color: AppColors.textSecondary),
      labelLarge: TextStyle(color: AppColors.textPrimary),
      labelMedium: TextStyle(color: AppColors.textSecondary),
      labelSmall: TextStyle(color: AppColors.textMuted),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      labelStyle: const TextStyle(color: AppColors.textSecondary),
      hintStyle: const TextStyle(color: AppColors.textMuted),
      prefixIconColor: AppColors.textSecondary,
      suffixIconColor: AppColors.textSecondary,
      border: OutlineInputBorder(
        borderSide: const BorderSide(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      enabledBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        borderRadius: BorderRadius.circular(12),
      ),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: AppColors.primary),
    ),

    snackBarTheme: const SnackBarThemeData(
      backgroundColor: AppColors.surface,
      contentTextStyle: TextStyle(color: AppColors.textPrimary),
      behavior: SnackBarBehavior.floating,
    ),

    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.primary,
      linearTrackColor: AppColors.surface,
      circularTrackColor: AppColors.surface,
    ),

    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surface,
      titleTextStyle: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
      contentTextStyle: const TextStyle(
        color: AppColors.textSecondary,
        fontSize: 13,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    ),

    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.surface,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.textMuted,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    ),
  );
}
