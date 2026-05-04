// lib/screens/diagnostico_screen.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'welcome_screen.dart';

class DiagnosticoScreen extends StatefulWidget {
  const DiagnosticoScreen({super.key});

  @override
  State<DiagnosticoScreen> createState() => _DiagnosticoScreenState();
}

class _DiagnosticoScreenState extends State<DiagnosticoScreen> {
  static const Color _rojo = Color(0xFFE53935);
  static const int _totalPreguntas = 10;

  final _user = FirebaseAuth.instance.currentUser!;
  final _random = Random();

  late final List<Map<String, Object>> _preguntas;

  int _actual = 0;
  int _aciertos = 0;
  int _errores = 0;
  String? _seleccionada;
  bool _respondido = false;

  @override
  void initState() {
    super.initState();
    _preguntas = _generarPreguntas();
  }

  // ── Generador de preguntas aleatorias ────────────────────────────────────
  List<Map<String, Object>> _generarPreguntas() {
    final List<Map<String, Object>> lista = [];
    // Tipos: 0=suma, 1=resta, 2=multiplicacion, 3=division
    final tipos = [0, 1, 2, 3];

    for (int i = 0; i < _totalPreguntas; i++) {
      final tipo = tipos[i % tipos.length]; // distribuye los 4 tipos
      lista.add(_generarPregunta(tipo));
    }

    lista.shuffle(_random); // mezcla el orden
    return lista;
  }

  Map<String, Object> _generarPregunta(int tipo) {
    int a, b, respuesta;
    String simbolo, preguntaStr;

    switch (tipo) {
      case 0: // Suma
        a = _random.nextInt(20) + 1;
        b = _random.nextInt(20) + 1;
        respuesta = a + b;
        simbolo = '+';
        preguntaStr = '$a $simbolo $b = ?';
        break;
      case 1: // Resta (resultado siempre positivo)
        b = _random.nextInt(15) + 1;
        a = b + _random.nextInt(15) + 1;
        respuesta = a - b;
        simbolo = '-';
        preguntaStr = '$a $simbolo $b = ?';
        break;
      case 2: // Multiplicacion
        a = _random.nextInt(10) + 1;
        b = _random.nextInt(10) + 1;
        respuesta = a * b;
        simbolo = 'x';
        preguntaStr = '$a $simbolo $b = ?';
        break;
      case 3: // Division exacta
        b = _random.nextInt(9) + 2; // divisor entre 2 y 10
        respuesta = _random.nextInt(10) + 1; // cociente entre 1 y 10
        a = b * respuesta;
        simbolo = '/';
        preguntaStr = '$a $simbolo $b = ?';
        break;
      default:
        a = 1;
        b = 1;
        respuesta = 2;
        preguntaStr = '1 + 1 = ?';
    }

    // Genera 3 opciones incorrectas únicas
    final Set<int> incorrectas = {};
    while (incorrectas.length < 3) {
      int falsa = respuesta + _random.nextInt(11) - 5;
      if (falsa != respuesta && falsa > 0) {
        incorrectas.add(falsa);
      }
    }

    final opciones = [
      respuesta.toString(),
      ...incorrectas.map((e) => e.toString()),
    ];
    opciones.shuffle(_random);

    return {
      'pregunta': preguntaStr,
      'opciones': opciones,
      'correcta': respuesta.toString(),
      'tipo': tipo,
    };
  }

  // ── Lógica de respuesta ───────────────────────────────────────────────────
  void _responder(String opcion) {
    if (_respondido) return;
    final correcta = _preguntas[_actual]['correcta'] as String;
    setState(() {
      _seleccionada = opcion;
      _respondido = true;
      if (opcion == correcta) {
        _aciertos++;
      } else {
        _errores++;
      }
    });
    Future.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      if (_actual < _preguntas.length - 1) {
        setState(() {
          _actual++;
          _seleccionada = null;
          _respondido = false;
        });
      } else {
        _terminar();
      }
    });
  }

  // ── Guardar resultado y navegar ───────────────────────────────────────────
  Future<void> _terminar() async {
    final total = _preguntas.length;
    final pct = _aciertos / total;

    int gradoNum;
    String grado;
    if (pct >= 0.8) {
      gradoNum = 4;
      grado = 'Nivel Avanzado';
    } else if (pct >= 0.6) {
      gradoNum = 3;
      grado = 'Nivel Intermedio';
    } else if (pct >= 0.4) {
      gradoNum = 2;
      grado = 'Nivel Basico';
    } else {
      gradoNum = 1;
      grado = 'Nivel Inicial';
    }

    await FirebaseFirestore.instance.collection('users').doc(_user.uid).update({
      'aciertos': _aciertos,
      'errores': _errores,
      'intentos': total,
      'tiempo_total': total * 20.0,
      'grado': grado,
      'grado_num': gradoNum,
    });

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      (route) => false,
    );
  }

  // ── UI ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final pregunta = _preguntas[_actual];
    final opciones = pregunta['opciones'] as List<String>;
    final correcta = pregunta['correcta'] as String;
    final progreso = (_actual + 1) / _preguntas.length;
    final tipo = pregunta['tipo'] as int;

    // Color e icono según tipo de operación
    final List<Color> coloresTipo = [
      const Color(0xFFE53935), // suma - rojo
      const Color(0xFF1E88E5), // resta - azul
      const Color(0xFF43A047), // multiplicacion - verde
      const Color(0xFFFB8C00), // division - naranja
    ];
    final List<String> labelsTipo = [
      'Suma',
      'Resta',
      'Multiplicación',
      'División',
    ];
    final List<IconData> iconosTipo = [
      Icons.add,
      Icons.remove,
      Icons.close,
      Icons.more_horiz,
    ];

    final colorTipo = coloresTipo[tipo];

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: _rojo,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'Diagnóstico inicial',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Progreso ────────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Pregunta ${_actual + 1} de ${_preguntas.length}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: colorTipo.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Icon(iconosTipo[tipo], color: colorTipo, size: 13),
                      const SizedBox(width: 4),
                      Text(
                        labelsTipo[tipo],
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: colorTipo,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progreso,
                minHeight: 7,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(colorTipo),
              ),
            ),
            const SizedBox(height: 10),

            // ── Puntaje en tiempo real ───────────────────────────────────
            Row(
              children: [
                Icon(
                  Icons.check_circle,
                  color: Colors.green.shade400,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  '$_aciertos correctas',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.green.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 16),
                Icon(Icons.cancel, color: Colors.red.shade300, size: 16),
                const SizedBox(width: 4),
                Text(
                  '$_errores incorrectas',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.red.shade400,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),

            // ── Tarjeta de pregunta ──────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: colorTipo.withOpacity(0.3),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: colorTipo.withOpacity(0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
                pregunta['pregunta'] as String,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF212121),
                  letterSpacing: 1,
                ),
              ),
            ),
            const SizedBox(height: 28),

            // ── Opciones ────────────────────────────────────────────────
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 2.2,
                physics: const NeverScrollableScrollPhysics(),
                children: opciones.map((op) {
                  final esCorrecta = op == correcta;
                  final esSeleccionada = op == _seleccionada;

                  Color borde = Colors.grey.shade200;
                  Color fondo = Colors.white;
                  Color textoColor = const Color(0xFF212121);

                  if (_respondido && esSeleccionada) {
                    if (esCorrecta) {
                      borde = Colors.green;
                      fondo = const Color(0xFFE8F5E9);
                      textoColor = Colors.green.shade700;
                    } else {
                      borde = _rojo;
                      fondo = const Color(0xFFFFEBEE);
                      textoColor = _rojo;
                    }
                  } else if (_respondido && esCorrecta) {
                    // Resalta la correcta aunque no la hayan elegido
                    borde = Colors.green;
                    fondo = const Color(0xFFE8F5E9);
                    textoColor = Colors.green.shade700;
                  }

                  return GestureDetector(
                    onTap: () => _responder(op),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        color: fondo,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: borde, width: 1.5),
                      ),
                      child: Center(
                        child: Text(
                          op,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: textoColor,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
