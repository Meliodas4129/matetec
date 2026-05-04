// lib/screens/diagnostico_screen.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';
import 'home_inicio.dart';

class DiagnosticoScreen extends StatefulWidget {
  const DiagnosticoScreen({super.key});

  @override
  State<DiagnosticoScreen> createState() => _DiagnosticoScreenState();
}

class _DiagnosticoScreenState extends State<DiagnosticoScreen> {
  static const int _totalPreguntas = 16;

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

  // 📊 Aciertos / intentos por tema durante el diagnóstico
  final Map<int, int> _aciertosPorTipo = {0: 0, 1: 0, 2: 0, 3: 0};
  final Map<int, int> _intentosPorTipo = {0: 0, 1: 0, 2: 0, 3: 0};

  // ── Lógica de respuesta ───────────────────────────────────────────────────
  void _responder(String opcion) {
    if (_respondido) return;
    final correcta = _preguntas[_actual]['correcta'] as String;
    final tipo = _preguntas[_actual]['tipo'] as int;
    setState(() {
      _seleccionada = opcion;
      _respondido = true;
      _intentosPorTipo[tipo] = (_intentosPorTipo[tipo] ?? 0) + 1;
      if (opcion == correcta) {
        _aciertos++;
        _aciertosPorTipo[tipo] = (_aciertosPorTipo[tipo] ?? 0) + 1;
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

    // El diagnóstico NO escribe en temas.X — eso queda solo para la práctica real,
    // así la pantalla de Progreso refleja únicamente lo que el usuario ha practicado.
    await FirebaseFirestore.instance.collection('users').doc(_user.uid).update({
      'aciertos': _aciertos,
      'errores': _errores,
      'intentos': total,
      'tiempo_total': total * 20.0,
      'grado': grado,
      'grado_num': gradoNum,
      // Reset por si reinició diagnóstico desde el perfil
      'temas': {
        'sumas': {'aciertos': 0, 'intentos': 0},
        'restas': {'aciertos': 0, 'intentos': 0},
        'multiplicacion': {'aciertos': 0, 'intentos': 0},
        'division': {'aciertos': 0, 'intentos': 0},
      },
    });

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
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

    // Color e icono según tipo de operación (versiones para dark mode)
    final List<Color> coloresTipo = [
      AppColors.temaSumas,
      AppColors.temaRestas,
      AppColors.temaMult,
      AppColors.temaDiv,
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'Diagnóstico inicial',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
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
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: colorTipo.withValues(alpha: 0.18),
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
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progreso,
                  minHeight: 7,
                  backgroundColor: AppColors.surface,
                  valueColor: AlwaysStoppedAnimation<Color>(colorTipo),
                ),
              ),
              const SizedBox(height: 14),

              // ── Puntaje en tiempo real ───────────────────────────────
              Row(
                children: [
                  const Icon(
                    Icons.check_circle,
                    color: AppColors.success,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$_aciertos correctas',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.success,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Icon(
                    Icons.cancel,
                    color: AppColors.danger,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$_errores incorrectas',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.danger,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // ── Tarjeta de pregunta ──────────────────────────────────
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: colorTipo.withValues(alpha: 0.4),
                    width: 1.5,
                  ),
                ),
                child: Text(
                  pregunta['pregunta'] as String,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    letterSpacing: 1,
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // ── Opciones ────────────────────────────────────────────
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

                    Color borde = AppColors.border;
                    Color fondo = AppColors.surface;
                    Color textoColor = AppColors.textPrimary;

                    if (_respondido && esSeleccionada) {
                      if (esCorrecta) {
                        borde = AppColors.success;
                        fondo = AppColors.success.withValues(alpha: 0.18);
                        textoColor = AppColors.success;
                      } else {
                        borde = AppColors.danger;
                        fondo = AppColors.danger.withValues(alpha: 0.18);
                        textoColor = AppColors.danger;
                      }
                    } else if (_respondido && esCorrecta) {
                      borde = AppColors.success;
                      fondo = AppColors.success.withValues(alpha: 0.18);
                      textoColor = AppColors.success;
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
      ),
    );
  }
}
