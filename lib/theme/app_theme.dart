// lib/theme/app_theme.dart
import 'package:flutter/material.dart';

/// Paleta centralizada de MateTec — fondos oscuros + rojo.
/// Usar SIEMPRE estos colores en lugar de hardcodear hex en cada pantalla.
class AppColors {
  AppColors._();

  // ── Marca / acento principal ────────────────────────────────────────────
  static const Color primary      = Color(0xFFE53935); // rojo MateTec
  static const Color primaryDark  = Color(0xFFB71C1C);
  static const Color primaryLight = Color(0xFFEF5350);
  static const Color primarySoft  = Color(0x1FE53935); // rojo 12% opacidad

  // ── Fondos / superficies ────────────────────────────────────────────────
  /// Fondo principal de las pantallas
  static const Color background     = Color(0xFF0D0D0D);
  /// Tarjetas y superficies elevadas
  static const Color surface        = Color(0xFF1A1A1A);
  /// Variante de superficie (chips, inputs, hover)
  static const Color surfaceVariant = Color(0xFF242424);
  /// Bordes sutiles
  static const Color border         = Color(0xFF2E2E2E);

  // ── Texto ───────────────────────────────────────────────────────────────
  static const Color textPrimary   = Color(0xFFF0F0F0);
  static const Color textSecondary = Color(0xFFAAAAAA);
  static const Color textMuted     = Color(0xFF666666);

  // ── Estados ─────────────────────────────────────────────────────────────
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFB8C00);
  static const Color danger  = Color(0xFFE53935);

  // ── Colores por tema (operación) ─────────────────────────────────────────
  static const Color temaSumas     = Color(0xFFE53935);
  static const Color temaSumasSoft = Color(0x1FE53935);
  static const Color temaRestas     = Color(0xFF1E88E5);
  static const Color temaRestasSoft = Color(0x1F1E88E5);
  static const Color temaMult       = Color(0xFF43A047);
  static const Color temaMultSoft   = Color(0x1F43A047);
  static const Color temaDiv        = Color(0xFFFB8C00);
  static const Color temaDivSoft    = Color(0x1FFB8C00);

  // ── Helpers ─────────────────────────────────────────────────────────────
  static Color softPrimary(double opacity) =>
      primary.withValues(alpha: opacity);
}

/// Theme global de la app.
class AppTheme {
  AppTheme._();

  static ThemeData light = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.background,

    colorScheme: const ColorScheme.dark(
      primary:          AppColors.primary,
      onPrimary:        Colors.white,
      secondary:        AppColors.primaryLight,
      onSecondary:      Colors.white,
      surface:          AppColors.surface,
      onSurface:        AppColors.textPrimary,
      surfaceContainerHighest: AppColors.surfaceVariant,
      error:            AppColors.danger,
      onError:          Colors.white,
    ),

    appBarTheme: const AppBarTheme(
      backgroundColor:    AppColors.primary,
      foregroundColor:    Colors.white,
      elevation:          0,
      surfaceTintColor:   Colors.transparent,
      titleTextStyle: TextStyle(
        color:      Colors.white,
        fontSize:   18,
        fontWeight: FontWeight.w600,
      ),
    ),

    cardColor:   AppColors.surface,
    cardTheme: CardThemeData(
      color:          AppColors.surface,
      elevation:      0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.border),
      ),
    ),
    dividerColor: AppColors.border,
    iconTheme:   const IconThemeData(color: AppColors.textSecondary),

    textTheme: const TextTheme(
      displayLarge:  TextStyle(color: AppColors.textPrimary),
      displayMedium: TextStyle(color: AppColors.textPrimary),
      headlineLarge: TextStyle(color: AppColors.textPrimary),
      headlineMedium:TextStyle(color: AppColors.textPrimary),
      headlineSmall: TextStyle(color: AppColors.textPrimary),
      titleLarge:    TextStyle(color: AppColors.textPrimary),
      titleMedium:   TextStyle(color: AppColors.textPrimary),
      titleSmall:    TextStyle(color: AppColors.textPrimary),
      bodyLarge:     TextStyle(color: AppColors.textPrimary),
      bodyMedium:    TextStyle(color: AppColors.textPrimary),
      bodySmall:     TextStyle(color: AppColors.textSecondary),
      labelLarge:    TextStyle(color: AppColors.textPrimary),
      labelMedium:   TextStyle(color: AppColors.textSecondary),
      labelSmall:    TextStyle(color: AppColors.textMuted),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled:           true,
      fillColor:        AppColors.surfaceVariant,
      labelStyle:   const TextStyle(color: AppColors.textSecondary),
      hintStyle:    const TextStyle(color: AppColors.textMuted),
      prefixIconColor:  AppColors.textSecondary,
      suffixIconColor:  AppColors.textSecondary,
      border: OutlineInputBorder(
        borderSide:   const BorderSide(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      enabledBorder: OutlineInputBorder(
        borderSide:   const BorderSide(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide:   const BorderSide(color: AppColors.primary, width: 1.5),
        borderRadius: BorderRadius.circular(12),
      ),
      errorBorder: OutlineInputBorder(
        borderSide:   const BorderSide(color: AppColors.danger, width: 1.5),
        borderRadius: BorderRadius.circular(12),
      ),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation:       0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.textPrimary,
        side:            const BorderSide(color: AppColors.border, width: 1.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: AppColors.primary),
    ),

    snackBarTheme: SnackBarThemeData(
      behavior:         SnackBarBehavior.floating,
      backgroundColor:  AppColors.surface,
      contentTextStyle: const TextStyle(color: AppColors.textPrimary),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
    ),

    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.primary,
    ),

    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surface,
      titleTextStyle: const TextStyle(
        color:      AppColors.textPrimary,
        fontSize:   16,
        fontWeight: FontWeight.w600,
      ),
      contentTextStyle: const TextStyle(
        color:    AppColors.textSecondary,
        fontSize: 13,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
    ),

    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor:     AppColors.surface,
      selectedItemColor:   AppColors.primary,
      unselectedItemColor: AppColors.textMuted,
      type:                BottomNavigationBarType.fixed,
      elevation:           0,
    ),

    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor:  AppColors.surface,
      modalBackgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),

    listTileTheme: const ListTileThemeData(
      tileColor:   Colors.transparent,
      iconColor:   AppColors.textSecondary,
      textColor:   AppColors.textPrimary,
    ),

    switchTheme: SwitchThemeData(
      thumbColor:  WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? AppColors.primary
            : AppColors.textMuted,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? AppColors.primarySoft
            : AppColors.border,
      ),
    ),

    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? AppColors.primary
            : Colors.transparent,
      ),
      side: const BorderSide(color: AppColors.border, width: 1.5),
    ),
  );

  /// Alias (código antiguo que llame a `dark` también funciona).
  static ThemeData dark = light;

  /// Genera un ThemeData usando el color primario dinámico del usuario.
  static ThemeData forColor(Color primary) {
    final darkVariant = Color.fromARGB(
      primary.alpha,
      (primary.red   * 0.75).round(),
      (primary.green * 0.75).round(),
      (primary.blue  * 0.75).round(),
    );
    final soft = primary.withValues(alpha: 0.12);

    return light.copyWith(
      colorScheme: ColorScheme.dark(
        primary:     primary,
        onPrimary:   Colors.white,
        secondary:   primary.withValues(alpha: 0.8),
        onSecondary: Colors.white,
        surface:     AppColors.surface,
        onSurface:   AppColors.textPrimary,
        error:       AppColors.danger,
        onError:     Colors.white,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor:  primary,
        foregroundColor:  Colors.white,
        elevation:        0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: const TextStyle(
          color:      Colors.white,
          fontSize:   18,
          fontWeight: FontWeight.w600,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation:       0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: primary),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled:          true,
        fillColor:       AppColors.surfaceVariant,
        labelStyle:   const TextStyle(color: AppColors.textSecondary),
        hintStyle:    const TextStyle(color: AppColors.textMuted),
        prefixIconColor: AppColors.textSecondary,
        suffixIconColor: AppColors.textSecondary,
        border: OutlineInputBorder(
          borderSide:   const BorderSide(color: AppColors.border),
          borderRadius: BorderRadius.circular(12),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide:   const BorderSide(color: AppColors.border),
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: primary, width: 1.5),
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor:     AppColors.surface,
        selectedItemColor:   primary,
        unselectedItemColor: AppColors.textMuted,
        type:                BottomNavigationBarType.fixed,
        elevation:           0,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: primary),
      extensions: [
        _PrimaryVariants(dark: darkVariant, soft: soft),
      ],
    );
  }
}

/// ThemeExtension que expone `primaryDark` y `primarySoft` calculados.
class _PrimaryVariants extends ThemeExtension<_PrimaryVariants> {
  final Color dark;
  final Color soft;
  const _PrimaryVariants({required this.dark, required this.soft});

  @override
  ThemeExtension<_PrimaryVariants> copyWith({Color? dark, Color? soft}) =>
      _PrimaryVariants(dark: dark ?? this.dark, soft: soft ?? this.soft);

  @override
  ThemeExtension<_PrimaryVariants> lerp(
          ThemeExtension<_PrimaryVariants>? other, double t) =>
      this;
}
