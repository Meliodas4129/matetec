// lib/screens/evaluacion_final_screen.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';
import '../services/sync_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Modelo de pregunta de evaluación
// ─────────────────────────────────────────────────────────────────────────────
class _Pregunta {
  final String expresion; // e.g. "12 + 7 + 5 = ?"
  final int respuesta;
  final List<String> opciones; // 4 opciones mezcladas

  const _Pregunta({
    required this.expresion,
    required this.respuesta,
    required this.opciones,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
class EvaluacionFinalScreen extends StatefulWidget {
  /// 'sumas', 'restas', 'multiplicacion', 'division'
  final String tema;
  final int gradoNum;

  /// Tema que se desbloqueará al pasar la evaluación ('' si es el último)
  final String siguienteTema;

  /// Cuántos intentos ha hecho ya el usuario en ESTE tema (para actualizar
  /// eval_desde_intentos al reprobar).
  final int intentosActuales;

  const EvaluacionFinalScreen({
    super.key,
    required this.tema,
    required this.gradoNum,
    required this.siguienteTema,
    required this.intentosActuales,
  });

  @override
  State<EvaluacionFinalScreen> createState() => _EvaluacionFinalScreenState();
}

class _EvaluacionFinalScreenState extends State<EvaluacionFinalScreen> {
  static const int _totalPreguntas = 30;
  static const double _umbralAprobado = 0.80; // 80 % = 24/30

  final _random = Random();
  final _user = FirebaseAuth.instance.currentUser;

  late final List<_Pregunta> _preguntas;

  int _indice = 0; // pregunta actual
  int _aciertos = 0;
  String? _seleccionada;
  bool _respondido = false;
  bool _guardando = false;
  bool _terminado = false;

  // ── Colores por tema ───────────────────────────────────────────────────────
  Color get _color {
    switch (widget.tema) {
      case 'restas':
        return AppColors.temaRestas;
      case 'multiplicacion':
        return AppColors.temaMult;
      case 'division':
        return AppColors.temaDiv;
      default:
        return AppColors.temaSumas;
    }
  }

  String get _nombreTema {
    switch (widget.tema) {
      case 'restas':
        return 'Restas';
      case 'multiplicacion':
        return 'Multiplicación';
      case 'division':
        return 'División';
      default:
        return 'Sumas';
    }
  }

  String get _nombreSiguiente {
    switch (widget.siguienteTema) {
      case 'restas':
        return 'Restas';
      case 'multiplicacion':
        return 'Multiplicación';
      case 'division':
        return 'División';
      default:
        return '';
    }
  }

  // ── Configuración por grado ────────────────────────────────────────────────
  ({int maxNum, int operandos}) get _config {
    switch (widget.gradoNum) {
      case 1:
        return (maxNum: 10, operandos: 2);
      case 2:
        return (maxNum: 20, operandos: 3);
      case 3:
        return (maxNum: 50, operandos: 3);
      case 4:
        return (maxNum: 100, operandos: 4);
      case 5:
        return (maxNum: 200, operandos: 4);
      default:
        return (maxNum: 500, operandos: 4);
    }
  }

  // ── Generación de preguntas ────────────────────────────────────────────────
  List<_Pregunta> _generarTodasLasPreguntas() {
    return List.generate(_totalPreguntas, (_) => _generarUna());
  }

  _Pregunta _generarUna() {
    final cfg = _config;

    switch (widget.tema) {
      case 'sumas':
        return _generarSuma(cfg.maxNum, cfg.operandos);
      case 'restas':
        return _generarResta(cfg.maxNum, cfg.operandos);
      case 'multiplicacion':
        return _generarMultiplicacion(cfg.operandos);
      case 'division':
        return _generarDivision(cfg.maxNum);
      default:
        return _generarSuma(cfg.maxNum, cfg.operandos);
    }
  }

  _Pregunta _generarSuma(int maxNum, int numOperandos) {
    final operandos = List.generate(
      numOperandos,
      (_) => _random.nextInt(maxNum) + 1,
    );
    final respuesta = operandos.reduce((a, b) => a + b);
    final expresion = '${operandos.join(' + ')} = ?';
    return _Pregunta(
      expresion: expresion,
      respuesta: respuesta,
      opciones: _generarOpciones(respuesta, maxNum * numOperandos),
    );
  }

  _Pregunta _generarResta(int maxNum, int numOperandos) {
    // Genera: a - b - c ... garantizando resultado > 0
    final ops = <int>[];
    // Primer operando: suficientemente grande
    int primero = _random.nextInt(maxNum) + (maxNum ~/ 2) + 1;
    ops.add(primero);
    int acum = primero;
    for (int i = 1; i < numOperandos; i++) {
      if (acum <= 1) break;
      final sig =
          _random.nextInt((acum - 1).clamp(1, maxNum ~/ numOperandos)) + 1;
      ops.add(sig);
      acum -= sig;
    }
    if (ops.length < 2) ops.add(_random.nextInt(primero - 1) + 1);
    final respuesta = ops.reduce((a, b) => a - b);
    final expresion = '${ops.join(' - ')} = ?';
    return _Pregunta(
      expresion: expresion,
      respuesta: respuesta.abs(),
      opciones: _generarOpciones(respuesta.abs(), maxNum),
    );
  }

  _Pregunta _generarMultiplicacion(int numOperandos) {
    // Factores pequeños para que el resultado sea manejable
    final maxFactor = widget.gradoNum <= 2
        ? 9
        : (widget.gradoNum <= 4 ? 12 : 15);
    final cantOps = numOperandos.clamp(2, 3); // máx 3 para mult
    final ops = List.generate(cantOps, (_) => _random.nextInt(maxFactor) + 1);
    final respuesta = ops.reduce((a, b) => a * b);
    final expresion = '${ops.join(' × ')} = ?';
    return _Pregunta(
      expresion: expresion,
      respuesta: respuesta,
      opciones: _generarOpciones(respuesta, respuesta + 30),
    );
  }

  _Pregunta _generarDivision(int maxNum) {
    // Siempre 2 operandos con división exacta
    final maxDiv = widget.gradoNum <= 2 ? 9 : (widget.gradoNum <= 4 ? 12 : 15);
    final divisor = _random.nextInt(maxDiv - 1) + 2;
    final cociente = _random.nextInt(maxNum ~/ divisor) + 1;
    final dividendo = divisor * cociente;
    final expresion = '$dividendo ÷ $divisor = ?';
    return _Pregunta(
      expresion: expresion,
      respuesta: cociente,
      opciones: _generarOpciones(cociente, maxDiv + 5),
    );
  }

  List<String> _generarOpciones(int correcta, int rangoMax) {
    final Set<int> set = {correcta};
    int intentos = 0;
    while (set.length < 4 && intentos < 50) {
      intentos++;
      final delta = _random.nextInt(11) - 5;
      final candidato = correcta + delta;
      if (candidato > 0 && candidato != correcta) set.add(candidato);
    }
    // Si no se completaron, agrega valores cercanos
    int extra = 1;
    while (set.length < 4) {
      if (correcta + extra > 0) set.add(correcta + extra);
      extra++;
    }
    final lista = set.map((e) => e.toString()).toList();
    lista.shuffle(_random);
    return lista;
  }

  // ── Ciclo de respuesta ────────────────────────────────────────────────────
  void _responder(String opcion) {
    if (_respondido || _terminado) return;
    final correcta = _preguntas[_indice].respuesta.toString();
    setState(() {
      _seleccionada = opcion;
      _respondido = true;
      if (opcion == correcta) _aciertos++;
    });
    Future.delayed(const Duration(milliseconds: 700), _siguiente);
  }

  void _siguiente() {
    if (!mounted) return;
    if (_indice + 1 >= _totalPreguntas) {
      setState(() => _terminado = true);
      _guardarResultado();
      return;
    }
    setState(() {
      _indice++;
      _seleccionada = null;
      _respondido = false;
    });
  }

  // ── Guardar resultado en Firestore ────────────────────────────────────────
  Future<void> _guardarResultado() async {
    if (_user == null) return;
    final aprobado = _aciertos / _totalPreguntas >= _umbralAprobado;
    final ref = FirebaseFirestore.instance.collection('users').doc(_user.uid);

    try {
      setState(() => _guardando = true);

      if (aprobado) {
        // Marcar eval aprobada y desbloquear siguiente tema
        final Map<String, dynamic> updates = {
          'temas.${widget.tema}.eval_aprobada': true,
        };
        if (widget.siguienteTema.isNotEmpty) {
          updates['temas_desbloqueados'] = FieldValue.arrayUnion([
            widget.siguienteTema,
          ]);
          updates['temas.${widget.siguienteTema}.eval_desde_intentos'] = 10;
        }
        await SyncService.wrap(() => ref.update(updates));
      } else {
        // Bloquear 5 prácticas más antes del siguiente intento
        await SyncService.wrap(
          () => ref.update({
            'temas.${widget.tema}.eval_desde_intentos':
                widget.intentosActuales + 5,
          }),
        );
      }
    } catch (e) {
      debugPrint('Error guardando evaluación: $e');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  // ── initState ─────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _preguntas = _generarTodasLasPreguntas();
  }

  // ── UI ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: _color,
        elevation: 0,
        leading: _terminado
            ? null
            : IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => _confirmarSalir(context),
              ),
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            const Icon(
              Icons.emoji_events_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'Evaluación · $_nombreTema',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ],
        ),
        actions: [
          if (!_terminado)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_indice + 1}/$_totalPreguntas',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _terminado ? _buildResultados() : _buildPregunta(),
      ),
    );
  }

  // ── Vista de pregunta ─────────────────────────────────────────────────────
  Widget _buildPregunta() {
    final pregunta = _preguntas[_indice];
    final correcta = pregunta.respuesta.toString();
    final progreso = (_indice + 1) / _totalPreguntas;

    return Column(
      key: ValueKey(_indice),
      children: [
        // Barra de progreso
        LinearProgressIndicator(
          value: progreso,
          minHeight: 6,
          backgroundColor: _color.withValues(alpha: 0.15),
          valueColor: AlwaysStoppedAnimation<Color>(_color),
        ),

        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 16),

                // Contador de aciertos
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _chip(
                      Icons.check_circle_outline,
                      '$_aciertos aciertos',
                      Colors.green,
                    ),
                    const SizedBox(width: 12),
                    _chip(
                      Icons.cancel_outlined,
                      '${_indice - _aciertos} errores',
                      Colors.red,
                    ),
                  ],
                ),

                const SizedBox(height: 28),

                // Tarjeta de pregunta
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    vertical: 36,
                    horizontal: 20,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _color.withValues(alpha: 0.35),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _color.withValues(alpha: 0.08),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Text(
                    pregunta.expresion,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: pregunta.expresion.length > 20 ? 26 : 32,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Opciones 2x2
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 2.0,
                  children: pregunta.opciones.map((op) {
                    final esCorrecta = op == correcta;
                    final esSeleccionada = op == _seleccionada;

                    Color borde = AppColors.border;
                    Color fondo = Colors.white;
                    Color textoColor = AppColors.textPrimary;

                    if (_respondido) {
                      if (esSeleccionada && esCorrecta) {
                        borde = Colors.green;
                        fondo = Colors.green.withValues(alpha: 0.12);
                        textoColor = Colors.green[700]!;
                      } else if (esSeleccionada && !esCorrecta) {
                        borde = Colors.red;
                        fondo = Colors.red.withValues(alpha: 0.12);
                        textoColor = Colors.red[700]!;
                      } else if (esCorrecta) {
                        borde = Colors.green;
                        fondo = Colors.green.withValues(alpha: 0.08);
                        textoColor = Colors.green[700]!;
                      }
                    }

                    return GestureDetector(
                      onTap: () => _responder(op),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        decoration: BoxDecoration(
                          color: fondo,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: borde, width: 1.5),
                        ),
                        child: Center(
                          child: Text(
                            op,
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: textoColor,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Vista de resultados ───────────────────────────────────────────────────
  Widget _buildResultados() {
    final aprobado = _aciertos / _totalPreguntas >= _umbralAprobado;
    final porcentaje = (_aciertos / _totalPreguntas * 100).toInt();

    return SingleChildScrollView(
      key: const ValueKey('resultados'),
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
      child: Column(
        children: [
          // Ícono resultado
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: (aprobado ? Colors.amber : Colors.grey).withValues(
                alpha: 0.15,
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              aprobado ? Icons.emoji_events_rounded : Icons.school_rounded,
              size: 56,
              color: aprobado ? Colors.amber[700] : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 20),

          Text(
            aprobado ? '¡Evaluación aprobada!' : 'Sigue practicando',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: aprobado ? Colors.amber[800] : Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            aprobado
                ? (widget.siguienteTema.isNotEmpty
                      ? '¡Desbloqueaste $_nombreSiguiente! 🎉'
                      : '¡Completaste todos los temas!')
                : 'Necesitas 5 prácticas más antes del próximo intento',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),

          const SizedBox(height: 32),

          // Tarjeta de puntuación grande
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                Text(
                  '$porcentaje%',
                  style: TextStyle(
                    fontSize: 52,
                    fontWeight: FontWeight.w900,
                    color: aprobado ? Colors.green[700] : Colors.red[600],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$_aciertos de $_totalPreguntas correctas',
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: _aciertos / _totalPreguntas,
                    minHeight: 12,
                    backgroundColor: AppColors.border,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      aprobado ? Colors.green : Colors.red,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Mínimo para aprobar: 80% (24/30)',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Tarjetas secundarias
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  valor: '$_aciertos',
                  label: 'Correctas',
                  color: Colors.green,
                  icono: Icons.check_circle_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  valor: '${_totalPreguntas - _aciertos}',
                  label: 'Incorrectas',
                  color: Colors.red,
                  icono: Icons.cancel_rounded,
                ),
              ),
            ],
          ),

          const SizedBox(height: 28),

          if (_guardando)
            const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: CircularProgressIndicator(),
            ),

          // Botón volver
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _guardando ? null : () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: _color,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: Text(
                aprobado ? 'Continuar' : 'Volver a practicar',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(IconData icono, String texto, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, color: color, size: 14),
          const SizedBox(width: 6),
          Text(
            texto,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmarSalir(BuildContext context) async {
    final salir = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          '¿Abandonar la evaluación?',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        content: const Text(
          'Si sales ahora, perderás tu progreso en esta evaluación y no contará.',
          style: TextStyle(fontSize: 13, color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Continuar',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text(
              'Salir',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
    if (salir == true && context.mounted) Navigator.pop(context);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final String valor;
  final String label;
  final Color color;
  final IconData icono;

  const _StatCard({
    required this.valor,
    required this.label,
    required this.color,
    required this.icono,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(icono, color: color, size: 28),
          const SizedBox(height: 6),
          Text(
            valor,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      ),
    );
  }
}
