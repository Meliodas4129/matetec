// lib/services/local_storage_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Gestiona el almacenamiento local para el modo invitado.
/// También expone [guestDataNotifier] para que HomeScreen
/// reaccione en tiempo real cuando cambian los datos locales.
class LocalStorageService {
  LocalStorageService._();

  static SharedPreferences? _prefs;
  static const _keyIsGuest  = 'is_guest';
  static const _keyGuestData = 'guest_data';

  /// Notifier reactivo: HomeScreen escucha cambios sin Firestore.
  static final ValueNotifier<Map<String, dynamic>> guestDataNotifier =
      ValueNotifier({});

  // ── Inicialización ─────────────────────────────────────────────────────────
  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    // Cargar datos actuales en el notifier
    guestDataNotifier.value = _readRaw();
  }

  // ── Estado de sesión ───────────────────────────────────────────────────────
  static bool get isGuest => _prefs?.getBool(_keyIsGuest) ?? false;
  static bool get hasGuestData {
    final d = _readRaw();
    return d['grado'] != null && d['grado'] != 'Pendiente';
  }

  static Future<void> startGuestSession() async {
    await _prefs!.setBool(_keyIsGuest, true);
    final existing = _readRaw();
    if (existing.isEmpty) {
      await _saveRaw(_defaultData());
    }
    guestDataNotifier.value = _readRaw();
  }

  static Future<void> endGuestSession() async {
    await _prefs!.setBool(_keyIsGuest, false);
  }

  static Future<void> clearGuestData() async {
    await _prefs!.remove(_keyGuestData);
    await _prefs!.setBool(_keyIsGuest, false);
    guestDataNotifier.value = {};
  }

  // ── Lectura / escritura ────────────────────────────────────────────────────
  static Map<String, dynamic> getData() => _readRaw();

  static Future<void> saveData(Map<String, dynamic> data) async {
    await _saveRaw(data);
    guestDataNotifier.value = Map<String, dynamic>.from(data);
  }

  static Future<void> updateFields(Map<String, dynamic> updates) async {
    final data = _readRaw();
    _deepMerge(data, updates);
    await _saveRaw(data);
    guestDataNotifier.value = Map<String, dynamic>.from(data);
  }

  // ── Operaciones específicas ─────────────────────────────────────────────────
  /// Incrementa un campo numérico (similar a FieldValue.increment).
  static Future<void> increment(String field, num amount) async {
    final data = _readRaw();
    final current = (data[field] as num?) ?? 0;
    data[field] = current + amount;
    await _saveRaw(data);
    guestDataNotifier.value = Map<String, dynamic>.from(data);
  }

  /// Actualiza un campo anidado como 'temas.sumas.aciertos'.
  static Future<void> incrementNested(String path, num amount) async {
    final data = _readRaw();
    final parts = path.split('.');
    dynamic node = data;
    for (int i = 0; i < parts.length - 1; i++) {
      if (node[parts[i]] == null || node[parts[i]] is! Map) {
        node[parts[i]] = <String, dynamic>{};
      }
      node = node[parts[i]];
    }
    final last = parts.last;
    final current = (node[last] as num?) ?? 0;
    node[last] = current + amount;
    await _saveRaw(data);
    guestDataNotifier.value = Map<String, dynamic>.from(data);
  }

  // ── Migración a Firestore cuando el invitado crea cuenta ──────────────────
  /// Devuelve los datos del invitado listos para fusionar en Firestore.
  static Map<String, dynamic> getDataForMigration() {
    final d = _readRaw();
    // Quitamos campos que Firestore manejará de otra manera
    d.remove('ultimaPractica');
    return d;
  }

  // ── Internos ───────────────────────────────────────────────────────────────
  static Map<String, dynamic> _readRaw() {
    final json = _prefs?.getString(_keyGuestData);
    if (json == null || json.isEmpty) return <String, dynamic>{};
    try {
      return Map<String, dynamic>.from(jsonDecode(json) as Map);
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  static Future<void> _saveRaw(Map<String, dynamic> data) async {
    await _prefs?.setString(_keyGuestData, jsonEncode(data));
  }

  /// Merge profundo: actualiza solo las claves recibidas (no sobreescribe todo).
  static void _deepMerge(Map<String, dynamic> target, Map<String, dynamic> source) {
    source.forEach((key, value) {
      if (value is Map<String, dynamic> &&
          target[key] is Map<String, dynamic>) {
        _deepMerge(target[key] as Map<String, dynamic>, value);
      } else {
        target[key] = value;
      }
    });
  }

  static Map<String, dynamic> _defaultData() => {
    'nombre': 'Invitado',
    'grado': 'Pendiente',
    'grado_num': 0,
    'aciertos': 0,
    'errores': 0,
    'intentos': 0,
    'tiempo_total': 0,
    'racha': 0,
    'puntos': 0,
    'ultimaPractica': null,
    'temas': {
      'sumas':          {'aciertos': 0, 'intentos': 0},
      'restas':         {'aciertos': 0, 'intentos': 0},
      'multiplicacion': {'aciertos': 0, 'intentos': 0},
      'division':       {'aciertos': 0, 'intentos': 0},
    },
  };
}
