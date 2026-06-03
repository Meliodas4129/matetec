import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:http/http.dart' as http;

class IAService {
  // ── URL del servidor de IA ──────────────────────────────────────────────
  //
  // Ya NO hay que editar el código al cambiar de red. La URL se resuelve sola:
  //
  //  • Override manual (recomendado para celular físico):
  //      flutter run --dart-define=IA_BASE_URL=http://192.168.1.50:5000
  //  • Web / escritorio  → http://localhost:5000
  //  • Emulador Android   → http://10.0.2.2:5000  (10.0.2.2 = el PC anfitrión)
  //
  // Para un celular físico SIEMPRE usa --dart-define con la IP de tu PC en la
  // misma red WiFi (ipconfig / ifconfig), porque no se puede autodetectar.
  static const String _override =
      String.fromEnvironment('IA_BASE_URL', defaultValue: '');

  static String get baseUrl {
    if (_override.isNotEmpty) return _override;
    if (kIsWeb) return 'http://localhost:5000';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:5000';
    }
    return 'http://localhost:5000';
  }

  /// Clasifica el nivel del alumno usando el modelo de IA.
  ///
  /// Parámetros globales requeridos:
  /// - [aciertos], [errores], [tiempo], [intentos]
  ///
  /// Parámetros por tema (opcionales, mejoran la predicción):
  /// - [precisionSumas], [precisionRestas], [precisionMult], [precisionDiv]: 0.0–1.0
  /// - [temaActual]: clave del tema que se acaba de practicar
  ///
  /// [client] es opcional; si no se pasa se usa el cliente HTTP real.
  static Future<Map<String, dynamic>> clasificar({
    required int    aciertos,
    required int    errores,
    required double tiempo,
    required int    intentos,
    double precisionSumas  = 0.0,
    double precisionRestas = 0.0,
    double precisionMult   = 0.0,
    double precisionDiv    = 0.0,
    String temaActual      = '',
    http.Client? client,
  }) async {
    final httpClient = client ?? http.Client();

    final response = await httpClient.post(
      Uri.parse("$baseUrl/clasificar"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "aciertos":           aciertos,
        "errores":            errores,
        "tiempo_promedio":    tiempo,
        "intentos":           intentos,
        "precision_sumas":    precisionSumas,
        "precision_restas":   precisionRestas,
        "precision_mult":     precisionMult,
        "precision_div":      precisionDiv,
        "tema_actual":        temaActual,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception("Error en IA: ${response.body}");
    }
  }

  // ── Emails de autenticación ───────────────────────────────────────────────

  /// Envía un correo de **verificación de cuenta** con diseño MateTec.
  /// Usa el servidor Flask + Firebase Admin para generar el enlace oficial.
  /// Lanza excepción si el servidor no está disponible.
  static Future<void> enviarVerificacion({
    required String email,
    required String nombre,
    http.Client? client,
  }) async {
    final httpClient = client ?? http.Client();
    final response = await httpClient.post(
      Uri.parse("$baseUrl/enviar_verificacion"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"email": email, "nombre": nombre}),
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      final body = jsonDecode(response.body);
      throw Exception(body['error'] ?? 'Error enviando verificación');
    }
  }

  /// Envía un correo de **recuperación de contraseña** con diseño MateTec.
  /// Usa el servidor Flask + Firebase Admin para generar el enlace oficial.
  /// Lanza excepción si el servidor no está disponible.
  static Future<void> enviarReset({
    required String email,
    http.Client? client,
  }) async {
    final httpClient = client ?? http.Client();
    final response = await httpClient.post(
      Uri.parse("$baseUrl/enviar_reset"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"email": email}),
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      final body = jsonDecode(response.body);
      throw Exception(body['error'] ?? 'Error enviando reset');
    }
  }

  /// Envía el resumen semanal por correo al alumno.
  ///
  /// [destino] correo del alumno o padre/tutor.
  /// [datos] mapa con nombre, aciertos, errores, racha, puntos, temas.
  static Future<bool> enviarResumen({
    required String destino,
    required Map<String, dynamic> datos,
    http.Client? client,
  }) async {
    final httpClient = client ?? http.Client();

    try {
      final response = await httpClient.post(
        Uri.parse("$baseUrl/enviar_resumen"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "destino": destino,
          "nombre":  datos['nombre']  ?? 'Estudiante',
          "aciertos": datos['aciertos'] ?? 0,
          "errores":  datos['errores']  ?? 0,
          "racha":    datos['racha']    ?? 0,
          "puntos":   datos['puntos']   ?? 0,
          "grado":    datos['grado']    ?? '',
          "temas":    datos['temas']    ?? {},
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
