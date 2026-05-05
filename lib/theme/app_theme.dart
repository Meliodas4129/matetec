// lib/theme/app_theme.dart
import 'package:flutter/material.dart';

/// Paleta centralizada de MateTec — fondos claros + rojo.
/// Usar SIEMPRE estos colores en lugar de hardcodear hex en cada pantalla.
class AppColors {
  AppColors._();

  // ── Marca / acento principal ────────────────────────────────────────────
  /// Rojo principal — color de marca de la app
  static const Color primary = Color(0xFFE53935); // rojo MateTec
  static const Color primaryDark = Color(0xFFB71C1C);
  static const Color primaryLight = Color(0xFFEF5350);
  static const Color primarySoft = Color(0xFFFFEBEE); // fondo rojo muy claro

  // ── Fondos / superficies ────────────────────────────────────────────────
  /// Fondo principal de las pantallas
  static const Color background = Color(0xFFFAFAFA);
  /// Tarjetas y superficies elevadas
  static const Color surface = Color(0xFFFFFFFF);
  /// Variante de superficie (chips, hover)
  static const Color surfaceVariant = Color(0xFFF5F5F5);
  /// Bordes sutiles
  static const Color border = Color(0xFFE0E0E0);

  // ── Texto ───────────────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF616161);
  static const Color textMuted = Color(0xFF9E9E9E);

  // ── Estados ─────────────────────────────────────────────────────────────
  static const Color success = Color(0xFF43A047);
  static const Color warning = Color(0xFFFB8C00);
  static const Color danger = Color(0xFFE53935);

  // ── Colores por tema (operación) — colores originales ───────────────────
  /// Sumas
  static const Color temaSumas = Color(0xFFE53935);
  static const Color temaSumasSoft = Color(0xFFFFEBEE);
  /// Restas
  static const Color temaRestas = Color(0xFF1E88E5);
  static const Color temaRestasSoft = Color(0xFFE3F2FD);
  /// Multiplicación
  static const Color temaMult = Color(0xFF43A047);
  static const Color temaMultSoft = Color(0xFFE8F5E9);
  /// División
  static const Color temaDiv = Color(0xFFFB8C00);
  static const Color temaDivSoft = Color(0xFFFFF3E0);

  // ── Helpers ─────────────────────────────────────────────────────────────
  static Color softPrimary(double opacity) =>
      primary.withValues(alpha: opacity);
}

/// Theme global de la app.
class AppTheme {
  AppTheme._();

  static ThemeData light = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: AppColors.background,

    colorScheme: const ColorScheme.light(
      primary: AppColors.primary,
      onPrimary: Colors.white,
      secondary: AppColors.primaryLight,
      onSecondary: Colors.white,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      error: AppColors.danger,
      onError: Colors.white,
    ),

    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(
        color: Colors.white,
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
      behavior: SnackBarBehavior.floating,
    ),

    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.primary,
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
      backgroundColor: Colors.white,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.textMuted,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    ),
  );

  /// Alias para compatibilidad con código existente que aún use `dark`.
  static ThemeData dark = light;
}
