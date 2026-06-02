// lib/services/notification_service.dart
//
// Maneja las 3 notificaciones locales de MateTec:
//   1. Recordatorio diario        → hora configurable (default 18:00)
//   2. Racha en peligro           → 20:00 si el usuario no practicó hoy
//   3. Evaluación desbloqueada    → inmediata al cumplir el requisito
//
// Uso:
//   await NotificationService.init();
//   await NotificationService.programarRecordatorioDiario(hora: 18, minuto: 0);
//   await NotificationService.programarAlertaRacha();
//   await NotificationService.mostrarEvaluacionDesbloqueada('Sumas');
//   await NotificationService.cancelarTodo();

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._();

  // ── IDs fijos por tipo ────────────────────────────────────────────────────
  static const int _idDiario  = 1;
  static const int _idRacha   = 2;
  static const int _idEval    = 3;

  // ── Keys de SharedPreferences ────────────────────────────────────────────
  static const _kHora    = 'notif_hora';
  static const _kMinuto  = 'notif_minuto';
  static const _kActivo  = 'notif_activo';
  static const _kRacha   = 'notif_racha_activo';

  // ── Instancia del plugin ─────────────────────────────────────────────────
  static final _plugin = FlutterLocalNotificationsPlugin();

  // ── Canal Android ────────────────────────────────────────────────────────
  static const _channel = AndroidNotificationChannel(
    'matetec_channel',
    'MateTec',
    description: 'Notificaciones de MateTec',
    importance: Importance.high,
    enableVibration: true,
    playSound: true,
  );

  // ── Detalles de notificación ──────────────────────────────────────────────
  static NotificationDetails get _detalles => NotificationDetails(
    android: AndroidNotificationDetails(
      _channel.id,
      _channel.name,
      channelDescription: _channel.description,
      importance: Importance.high,
      priority: Priority.high,
      color:     const Color(0xFFE53935),
      icon:      '@mipmap/ic_launcher',
    ),
  );

  // ─── Inicialización ───────────────────────────────────────────────────────
  static Future<void> init() async {
    // Inicializar base de datos de zonas horarias
    tz_data.initializeTimeZones();

    // Intentar detectar la zona horaria local
    try {
      // México/Ciudad de México como default para el proyecto
      tz.setLocalLocation(tz.getLocation('America/Mexico_City'));
    } catch (_) {
      // Si falla, usar UTC
    }

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);

    await _plugin.initialize(settings);

    // Crear el canal en Android 8+
    final androidPlugin =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(_channel);

    // Solicitar permiso de notificaciones (Android 13+)
    await androidPlugin?.requestNotificationsPermission();

    debugPrint('NotificationService: inicializado ✓');
  }

  // ─── Leer configuración guardada ─────────────────────────────────────────
  static Future<({int hora, int minuto, bool activo, bool rachaActivo})>
      leerConfig() async {
    final prefs = await SharedPreferences.getInstance();
    return (
      hora:        prefs.getInt(_kHora)    ?? 18,
      minuto:      prefs.getInt(_kMinuto)  ?? 0,
      activo:      prefs.getBool(_kActivo) ?? true,
      rachaActivo: prefs.getBool(_kRacha)  ?? true,
    );
  }

  // ─── 1. Recordatorio diario ───────────────────────────────────────────────
  /// Programa (o reprograma) el recordatorio diario a la hora indicada.
  /// Llama también a [programarAlertaRacha] para sincronizar.
  static Future<void> programarRecordatorioDiario({
    int hora   = 18,
    int minuto = 0,
    bool activo = true,
  }) async {
    // Guardar preferencias
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kHora,    hora);
    await prefs.setInt(_kMinuto,  minuto);
    await prefs.setBool(_kActivo, activo);

    // Cancelar el anterior
    await _plugin.cancel(_idDiario);

    if (!activo) {
      debugPrint('NotificationService: recordatorio diario desactivado');
      return;
    }

    final ahora  = tz.TZDateTime.now(tz.local);
    var programado = tz.TZDateTime(
      tz.local, ahora.year, ahora.month, ahora.day, hora, minuto,
    );
    // Si ya pasó hoy, programar para mañana
    if (programado.isBefore(ahora)) {
      programado = programado.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      _idDiario,
      '📐 ¡Hora de practicar!',
      'Mantén tu racha activa. ¿Cuántas preguntas puedes responder hoy?',
      programado,
      _detalles,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time, // repite diariamente
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );

    debugPrint('NotificationService: recordatorio diario → ${hora.toString().padLeft(2,'0')}:${minuto.toString().padLeft(2,'0')} ✓');
  }

  // ─── 2. Alerta de racha en peligro ────────────────────────────────────────
  /// Programa una notificación a las 20:00 para avisar si el usuario
  /// no ha practicado hoy. Se cancela automáticamente al guardar una respuesta.
  static Future<void> programarAlertaRacha({bool activo = true}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kRacha, activo);
    await _plugin.cancel(_idRacha);

    if (!activo) return;

    final ahora = tz.TZDateTime.now(tz.local);
    var hora20  = tz.TZDateTime(
      tz.local, ahora.year, ahora.month, ahora.day, 20, 0,
    );
    if (hora20.isBefore(ahora)) {
      hora20 = hora20.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      _idRacha,
      '🔥 ¡Tu racha está en peligro!',
      'No has practicado hoy. Entra a MateTec y mantén tu racha.',
      hora20,
      _detalles,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );

    debugPrint('NotificationService: alerta racha programada ✓');
  }

  /// Llama esto cuando el usuario termina una partida:
  /// cancela la alerta de racha para ese día y la reprograma para mañana.
  static Future<void> marcarPracticadoHoy() async {
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool(_kRacha) ?? true)) return;

    await _plugin.cancel(_idRacha);
    // Reprogramar para mañana a las 20:00
    await programarAlertaRacha();
    debugPrint('NotificationService: racha OK por hoy ✓');
  }

  // ─── 3. Evaluación desbloqueada ───────────────────────────────────────────
  /// Muestra una notificación inmediata cuando el usuario desbloquea
  /// la evaluación de [nombreTema] (ej. "Sumas").
  static Future<void> mostrarEvaluacionDesbloqueada(String nombreTema) async {
    await _plugin.show(
      _idEval,
      '🏆 ¡Evaluación desbloqueada!',
      'Ya puedes presentar la evaluación de $nombreTema. ¡Demuestra lo que sabes!',
      _detalles,
    );
    debugPrint('NotificationService: evaluación desbloqueada ($nombreTema) ✓');
  }

  // ─── Cancelar todo ────────────────────────────────────────────────────────
  static Future<void> cancelarTodo() async {
    await _plugin.cancelAll();
  }
}
