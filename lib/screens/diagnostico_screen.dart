// lib/screens/diagnostico_screen.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';
import '../services/local_storage_service.dart';
import 'home_inicio.dart';

class DiagnosticoScreen extends StatefulWidget {
  /// Cuando [isPractice] es true, el resultado NO se guarda en Firestore/local
  /// y se muestra un diálogo de resumen en lugar de navegar al Home.
  final bool isPractice;

  const DiagnosticoScreen({super.key, this.isPractice = false});

  @override
  State<DiagnosticoScreen> createState() => _DiagnosticoScreenState();
}

class _DiagnosticoScreenState extends State<DiagnosticoScreen> {
  static const int _totalPreguntas = 16;

  final _random = Random();

  late final List<Map<String, Object>> _preguntas;

  int _actual   = 0;
  int _aciertos = 0;
  int _errores  = 0;
  String? _seleccionada;
  bool _respondido = false;

  final Map<int, int> _aciertosPorTipo = {0: 0, 1: 0, 2: 0, 3: 0};
  final Map<int, int> _intentosPorTipo = {0: 0, 1: 0, 2: 0, 3: 0};

  @override
  void initState() {
    super.initState();
    _preguntas = _generarPreguntas();
  }

  // ── Generador de preguntas ────────────────────────────────────────────────
  List<Map<String, Object>> _generarPreguntas() {
    final lista = <Map<String, Object>>[];
    for (int i = 0; i < _totalPreguntas; i++) {
      lista.add(_generarPregunta(i % 4));
    }
    lista.shuffle(_random);
    return lista;
  }

  Map<String, Object> _generarPregunta(int tipo) {
    int a, b, respuesta;
    String simbolo, preguntaStr;

    switch (tipo) {
      case 0:
        a = _random.nextInt(20) + 1;
        b = _random.nextInt(20) + 1;
        respuesta = a + b;
        simbolo = '+';
        preguntaStr = '$a $simbolo $b = ?';
        break;
      case 1:
        b = _random.nextInt(15) + 1;
        a = b + _random.nextInt(15) + 1;
        respuesta = a - b;
        simbolo = '-';
        preguntaStr = '$a $simbolo $b = ?';
        break;
      case 2:
        a = _random.nextInt(10) + 1;
        b = _random.nextInt(10) + 1;
        respuesta = a * b;
        simbolo = 'x';
        preguntaStr = '$a $simbolo $b = ?';
        break;
      case 3:
        b = _random.nextInt(9) + 2;
        respuesta = _random.nextInt(10) + 1;
        a = b * respuesta;
        simbolo = '/';
        preguntaStr = '$a $simbolo $b = ?';
        break;
      default:
        a = 1; b = 1; respuesta = 2;
        preguntaStr = '1 + 1 = ?';
    }

    final incorrectas = <int>{};
    while (incorrectas.length < 3) {
      final falsa = respuesta + _random.nextInt(11) - 5;
      if (falsa != respuesta && falsa > 0) incorrectas.add(falsa);
    }

    final opciones = [respuesta.toString(), ...incorrectas.map((e) => e.toString())];
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
    final tipo     = _preguntas[_actual]['tipo'] as int;
    setState(() {
      _seleccionada = opcion;
      _respondido   = true;
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
          _respondido   = false;
        });
      } else {
        _terminar();
      }
    });
  }

  // ── Calcular nivel a partir del resultado ─────────────────────────────────
  (int gradoNum, String grado) _calcularNivel() {
    final pct = _aciertos / _preguntas.length;
    if (pct >= 0.8) return (4, 'Nivel Avanzado');
    if (pct >= 0.6) return (3, 'Nivel Intermedio');
    if (pct >= 0.4) return (2, 'Nivel Básico');
    return (1, 'Nivel Inicial');
  }

  // ── Finalizar: práctica vs diagnóstico real ───────────────────────────────
  Future<void> _terminar() async {
    final (gradoNum, grado) = _calcularNivel();

    if (widget.isPractice) {
      // ── Modo práctica: solo mostrar resumen, no guardar nada ──────────────
      if (!mounted) return;
      _mostrarResumenPractica(gradoNum, grado);
      return;
    }

    // ── Diagnóstico inicial: SOLO fija el nivel ───────────────────────────
    // El diagnóstico NO debe contar como práctica: las estadísticas de
    // Progreso/Perfil arrancan en cero y solo se llenan con la práctica real.
    const temasEnCero = {
      'sumas':          {'aciertos': 0, 'intentos': 0},
      'restas':         {'aciertos': 0, 'intentos': 0},
      'multiplicacion': {'aciertos': 0, 'intentos': 0},
      'division':       {'aciertos': 0, 'intentos': 0},
    };

    if (LocalStorageService.isGuest) {
      // Invitado → guardar en local
      await LocalStorageService.saveData({
        ...LocalStorageService.getData(),
        'grado': grado,
        'grado_num': gradoNum,
        'aciertos': 0,
        'errores': 0,
        'intentos': 0,
        'tiempo_total': 0.0,
        'temas': temasEnCero,
      });
    } else {
      // Usuario con cuenta → guardar en Firestore
      final user = FirebaseAuth.instance.currentUser!;
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'aciertos':    0,
        'errores':     0,
        'intentos':    0,
        'tiempo_total': 0.0,
        'grado':       grado,
        'grado_num':   gradoNum,
        'temas': temasEnCero,
      });
    }

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (route) => false,
    );
  }

  // ── Diálogo de resumen (modo práctica) ────────────────────────────────────
  void _mostrarResumenPractica(int gradoNum, String grado) {
    final List<Color> colores = [AppColors.temaSumas, AppColors.temaRestas, AppColors.temaMult, AppColors.temaDiv];
    final List<String> nombres = ['Sumas', 'Restas', 'Multiplicación', 'División'];
    final List<IconData> iconos = [Icons.add, Icons.remove, Icons.close, Icons.more_horiz];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Práctica completada 🎉',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Resultado global
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    Text(
                      '$_aciertos / ${_preguntas.length}',
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                    Text('aciertos',
                        style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                    const SizedBox(height: 8),
                    Text(
                      'Tu nivel estimado: $grado',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      '(tu nivel guardado no cambia)',
                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Resultado por tema
              ...List.generate(4, (i) {
                final ac = _aciertosPorTipo[i] ?? 0;
                final int_ = _intentosPorTipo[i] ?? 0;
                if (int_ == 0) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(children: [
                    Icon(iconos[i], color: colores[i], size: 18),
                    const SizedBox(width: 8),
                    Text(nombres[i], style: const TextStyle(fontSize: 13)),
                    const Spacer(),
                    Text('$ac/$int_',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: colores[i])),
                  ]),
                );
              }),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);         // cierra diálogo
              Navigator.pop(context);         // vuelve al Home/Perfil
            },
            child: const Text('Volver', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);         // cierra diálogo
              // reinicia la práctica en la misma pantalla
              setState(() {
                _actual       = 0;
                _aciertos     = 0;
                _errores      = 0;
                _seleccionada = null;
                _respondido   = false;
                _aciertosPorTipo.updateAll((_, __) => 0);
                _intentosPorTipo.updateAll((_, __) => 0);
                _preguntas.shuffle(_random);
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Repetir'),
          ),
        ],
      ),
    );
  }

  // ── UI ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final pregunta  = _preguntas[_actual];
    final opciones  = pregunta['opciones'] as List<String>;
    final correcta  = pregunta['correcta'] as String;
    final progreso  = (_actual + 1) / _preguntas.length;
    final tipo      = pregunta['tipo'] as int;

    final coloresTipo = [AppColors.temaSumas, AppColors.temaRestas, AppColors.temaMult, AppColors.temaDiv];
    final labelsTipo  = ['Suma', 'Resta', 'Multiplicación', 'División'];
    final iconosTipo  = [Icons.add, Icons.remove, Icons.close, Icons.more_horiz];
    final colorTipo   = coloresTipo[tipo];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        automaticallyImplyLeading: widget.isPractice,
        title: Text(
          widget.isPractice ? 'Modo práctica' : 'Diagnóstico inicial',
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: widget.isPractice
            ? [
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Chip(
                    label: const Text('Solo práctica',
                        style: TextStyle(fontSize: 11, color: Colors.white)),
                    backgroundColor: AppColors.primary,
                    padding: EdgeInsets.zero,
                  ),
                ),
              ]
            : null,
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
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: colorTipo.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Icon(iconosTipo[tipo], color: colorTipo, size: 13),
                        const SizedBox(width: 4),
                        Text(labelsTipo[tipo],
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: colorTipo)),
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

              // ── Puntaje en tiempo real ────────────────────────────────
              Row(
                children: [
                  const Icon(Icons.check_circle, color: AppColors.success, size: 16),
                  const SizedBox(width: 4),
                  Text('$_aciertos correctas',
                      style: const TextStyle(fontSize: 12, color: AppColors.success, fontWeight: FontWeight.w500)),
                  const SizedBox(width: 16),
                  const Icon(Icons.cancel, color: AppColors.danger, size: 16),
                  const SizedBox(width: 4),
                  Text('$_errores incorrectas',
                      style: const TextStyle(fontSize: 12, color: AppColors.danger, fontWeight: FontWeight.w500)),
                ],
              ),
              const SizedBox(height: 28),

              // ── Tarjeta pregunta ──────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: colorTipo.withValues(alpha: 0.4), width: 1.5),
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

              // ── Opciones ──────────────────────────────────────────────
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 2.2,
                  physics: const NeverScrollableScrollPhysics(),
                  children: opciones.map((op) {
                    final esCorrecta   = op == correcta;
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
                          child: Text(op,
                              style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                  color: textoColor)),
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
