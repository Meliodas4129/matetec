// lib/services/theme_service.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Gestiona el color primario de la app seleccionado por el usuario.
/// Se guarda localmente en SharedPreferences para persistir entre sesiones.
class ThemeService {
  ThemeService._();

  static const _key = 'app_color_index';

  // ── Presets de color ───────────────────────────────────────────────────────
  static const List<Color> presets = [
    Color(0xFFE53935), // 🔴 Rojo (default MateTec)
    Color(0xFF1E88E5), // 🔵 Azul
    Color(0xFF43A047), // 🟢 Verde
    Color(0xFF8E24AA), // 🟣 Morado
    Color(0xFFFB8C00), // 🟠 Naranja
  ];

  static const List<String> nombresPresets = [
    'Rojo',
    'Azul',
    'Verde',
    'Morado',
    'Naranja',
  ];

  /// Índice del preset activo. Escuchar con `addListener` para reaccionar.
  static final colorIndexNotifier = ValueNotifier<int>(0);

  /// Color primario actual.
  static Color get primaryColor => presets[colorIndexNotifier.value];

  /// Versión oscura del color primario.
  static Color get primaryDark {
    final c = primaryColor;
    return Color.fromARGB(
      c.alpha,
      (c.red * 0.75).round(),
      (c.green * 0.75).round(),
      (c.blue * 0.75).round(),
    );
  }

  // ── Inicialización ─────────────────────────────────────────────────────────
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getInt(_key) ?? 0;
    colorIndexNotifier.value = saved.clamp(0, presets.length - 1);
  }

  // ── Cambiar color ──────────────────────────────────────────────────────────
  static Future<void> setColorIndex(int index) async {
    final i = index.clamp(0, presets.length - 1);
    colorIndexNotifier.value = i;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key, i);
  }
}
