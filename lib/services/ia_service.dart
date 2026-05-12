import 'dart:convert';
import 'package:http/http.dart' as http;

class IAService {
  // ⚠️ CAMBIA SEGÚN TU CASO:

  // 🌐 Flutter Web (Chrome)
  static const String baseUrl = "http://localhost:5000";

  // 📱 Android Emulator
  // static const String baseUrl = "http://10.0.2.2:5000";

  // 📱 Celular físico (misma red WiFi que tu PC)
  // static const String baseUrl = "http://192.168.X.X:5000";

  /// [client] es opcional; si no se pasa se usa el cliente HTTP real.
  /// Inyectar el cliente permite sustituirlo por un mock en los tests.
  static Future<Map<String, dynamic>> clasificar({
    required int aciertos,
    required int errores,
    required double tiempo,
    required int intentos,
    http.Client? client,
  }) async {
    final httpClient = client ?? http.Client();

    final response = await httpClient.post(
      Uri.parse("$baseUrl/clasificar"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "aciertos": aciertos,
        "errores": errores,
        "tiempo_promedio": tiempo,
        "intentos": intentos,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception("Error en IA: ${response.body}");
    }
  }
}
