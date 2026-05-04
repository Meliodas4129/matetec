// lib/screens/practica_screen.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/ia_service.dart';
import '../theme/app_theme.dart';

/// Tema disponible para practicar
enum TemaPractica { sumas, restas, multiplicacion, division }

extension TemaPracticaX on TemaPractica {
  String get clave {
    switch (this) {
      case TemaPractica.sumas:
        return 'sumas';
      case TemaPractica.restas:
        return 'restas';
      case TemaPractica.multiplicacion:
        return 'multiplicacion';
      case TemaPractica.division:
        return 'division';
    }
  }

  String get nombre {
    switch (this) {
      case TemaPractica.sumas:
        return 'Sumas';
      case TemaPractica.restas:
        return 'Restas';
      case TemaPractica.multiplicacion:
        return 'Multiplicación';
      case TemaPractica.division:
        return 'División';
    }
  }

  Color get color {
    switch (this) {
      case TemaPractica.sumas:
        return AppColors.temaSumas;
      case TemaPractica.restas:
        return AppColors.temaRestas;
      case TemaPractica.multiplicacion:
        return AppColors.temaMult;
      case TemaPractica.division:
        return AppColors.temaDiv;
    }
  }

  IconData get icono {
    switch (this) {
      case TemaPractica.sumas:
        return Icons.add;
      case TemaPractica.restas:
        return Icons.remove;
      case TemaPractica.multiplicacion:
        return Icons.close;
      case TemaPractica.division:
        return Icons.more_horiz;
    }
  }
}

/// Fases de la pantalla
enum _Fase { seleccion, jugando, resultados }

class PracticaScreen extends StatefulWidget {
  final TemaPractica tema;
  final int gradoNum;

  const PracticaScreen({
    super.key,
    required this.tema,
    required this.gradoNum,
  });

  @override
  State<PracticaScreen> createState() => _PracticaScreenState();
}

class _PracticaScreenState extends State<PracticaScreen> {
  final _random = Random();
  final _user = FirebaseAuth.instance.currentUser!;

  _Fase _fase = _Fase.seleccion;

  // ⏱️ Cronómetro
  int _duracionTotal = 60; // en segundos, lo elige el usuario
  int _segundosRestantes = 60;
  Timer? _timer;

  // Pregunta actual
  Map<String, Object>? _pregunta;
  String? _seleccionada;
  bool _respondido = false;

  // 📊 Contadores de la sesión
  int _aciertos = 0;
  int _errores = 0;
  int _rachaActual = 0;
  int _mejorRacha = 0;
  int _puntosSesion = 0;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // ─── Inicio del juego ─────────────────────────────────────────────────────
  void _iniciarJuego(int segundos) {
    setState(() {
      _duracionTotal = segundos;
      _segundosRestantes = segundos;
      _aciertos = 0;
      _errores = 0;
      _rachaActual = 0;
      _mejorRacha = 0;
      _puntosSesion = 0;
      _pregunta = _generarPregunta();
      _seleccionada = null;
      _respondido = false;
      _fase = _Fase.jugando;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        _segundosRestantes--;
      });
      if (_segundosRestantes <= 0) {
        t.cancel();
        _terminarJuego();
      }
    });
  }

  void _terminarJuego() {
    _timer?.cancel();
    setState(() => _fase = _Fase.resultados);
  }

  // ─── Dificultad según grado ───────────────────────────────────────────────
  ({int max, int base}) get _rangos {
    switch (widget.gradoNum) {
      case 4:
        return (max: 50, base: 1);
      case 3:
        return (max: 30, base: 1);
      case 2:
        return (max: 15, base: 1);
      default:
        return (max: 10, base: 1);
    }
  }

  ({int maxA, int maxB}) get _rangosMult {
    switch (widget.gradoNum) {
      case 4:
        return (maxA: 12, maxB: 12);
      case 3:
        return (maxA: 10, maxB: 10);
      case 2:
        return (maxA: 7, maxB: 7);
      default:
        return (maxA: 5, maxB: 5);
    }
  }

  // ─── Generador de preguntas ───────────────────────────────────────────────
  Map<String, Object> _generarPregunta() {
    int a, b, respuesta;
    String simbolo, preguntaStr;
    final rangos = _rangos;

    switch (widget.tema) {
      case TemaPractica.sumas:
        a = _random.nextInt(rangos.max) + rangos.base;
        b = _random.nextInt(rangos.max) + rangos.base;
        respuesta = a + b;
        simbolo = '+';
        preguntaStr = '$a $simbolo $b = ?';
        break;
      case TemaPractica.restas:
        b = _random.nextInt(rangos.max) + rangos.base;
        a = b + _random.nextInt(rangos.max) + rangos.base;
        respuesta = a - b;
        simbolo = '-';
        preguntaStr = '$a $simbolo $b = ?';
        break;
      case TemaPractica.multiplicacion:
        final r = _rangosMult;
        a = _random.nextInt(r.maxA) + 1;
        b = _random.nextInt(r.maxB) + 1;
        respuesta = a * b;
        simbolo = 'x';
        preguntaStr = '$a $simbolo $b = ?';
        break;
      case TemaPractica.division:
        final r = _rangosMult;
        b = _random.nextInt(r.maxB - 1) + 2;
        respuesta = _random.nextInt(r.maxA) + 1;
        a = b * respuesta;
        simbolo = '/';
        preguntaStr = '$a $simbolo $b = ?';
        break;
    }

    final Set<int> incorrectas = {};
    int intentos = 0;
    while (incorrectas.length < 3 && intentos < 30) {
      intentos++;
      final delta = _random.nextInt(11) - 5;
      final falsa = respuesta + delta;
      if (falsa != respuesta && falsa > 0) {
        incorrectas.add(falsa);
      }
    }
    int extra = 1;
    while (incorrectas.length < 3) {
      final candidato = respuesta + extra;
      if (candidato > 0 && candidato != respuesta) incorrectas.add(candidato);
      extra++;
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
    };
  }

  // ─── Lógica de respuesta ─────────────────────────────────────────────────
  Future<void> _responder(String opcion) async {
    if (_respondido || _fase != _Fase.jugando) return;
    final correcta = _pregunta!['correcta'] as String;
    final esCorrecta = opcion == correcta;

    setState(() {
      _seleccionada = opcion;
      _respondido = true;

      if (esCorrecta) {
        _aciertos++;
        _rachaActual++;
        _puntosSesion += 10;
        if (_rachaActual > 0 && _rachaActual % 5 == 0) {
          _puntosSesion += 20;
        }
        if (_rachaActual > _mejorRacha) {
          _mejorRacha = _rachaActual;
        }
      } else {
        _errores++;
        _rachaActual = 0;
      }
    });

    _guardarRespuesta(esCorrecta);

    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted || _fase != _Fase.jugando) return;
    setState(() {
      _pregunta = _generarPregunta();
      _seleccionada = null;
      _respondido = false;
    });
  }

  /// Actualiza Firestore. La IA es best-effort.
  Future<void> _guardarRespuesta(bool correcta) async {
    final ref = FirebaseFirestore.instance.collection('users').doc(_user.uid);
    final tema = widget.tema.clave;

    int puntosGanados = 0;
    if (correcta) {
      puntosGanados = 10;
      if (_rachaActual > 0 && _rachaActual % 5 == 0) {
        puntosGanados += 20;
      }
    }

    final updates = <String, Object?>{
      'aciertos': FieldValue.increment(correcta ? 1 : 0),
      'errores': FieldValue.increment(correcta ? 0 : 1),
      'intentos': FieldValue.increment(1),
      'tiempo_total': FieldValue.increment(20),
      'temas.$tema.intentos': FieldValue.increment(1),
      if (correcta) 'temas.$tema.aciertos': FieldValue.increment(1),
      if (puntosGanados > 0) 'puntos': FieldValue.increment(puntosGanados),
    };

    try {
      await ref.update(updates);
    } catch (e) {
      debugPrint('Error guardando respuesta: $e');
    }

    try {
      final docActual = await ref.get();
      final data = docActual.data();
      if (data == null) return;

      final ia = await IAService.clasificar(
        aciertos: (data['aciertos'] ?? 0) as int,
        errores: (data['errores'] ?? 0) as int,
        tiempo: ((data['tiempo_total'] ?? 0) as num).toDouble() /
            ((data['intentos'] ?? 1) as int).clamp(1, 1 << 31),
        intentos: (data['intentos'] ?? 0) as int,
      );
      await ref.update({
        'grado': ia['descripcion'],
        'grado_num': ia['grado'],
      });
    } catch (e) {
      debugPrint('IA no disponible: $e');
    }
  }

  // ─── Confirmar salida durante el juego ───────────────────────────────────
  Future<bool> _confirmarSalir() async {
    if (_fase != _Fase.jugando || (_aciertos == 0 && _errores == 0)) {
      return true;
    }

    final salir = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          '¿Terminar la práctica?',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Llevas $_aciertos aciertos y $_errores errores.\n'
          '¿Seguro que quieres salir antes de tiempo?',
          style: const TextStyle(fontSize: 13, color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Seguir', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.danger,
            ),
            child: const Text(
              'Terminar',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    return salir == true;
  }

  // ─── UI ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final color = widget.tema.color;

    return PopScope(
      canPop: _fase != _Fase.jugando,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmarSalir() && mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: color,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () async {
              if (await _confirmarSalir() && mounted) {
                Navigator.pop(context);
              }
            },
          ),
          title: Row(
            children: [
              Icon(widget.tema.icono, color: Colors.white, size: 22),
              const SizedBox(width: 8),
              Text(
                widget.tema.nombre,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          actions: [
            if (_fase == _Fase.jugando)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.timer,
                            color: Colors.white, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          '${_segundosRestantes}s',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: _buildFase(color),
        ),
      ),
    );
  }

  Widget _buildFase(Color color) {
    switch (_fase) {
      case _Fase.seleccion:
        return _buildSeleccion(color);
      case _Fase.jugando:
        return _buildJuego(color);
      case _Fase.resultados:
        return _buildResultados(color);
    }
  }

  // ─── Fase 1: Selección de duración ───────────────────────────────────────
  Widget _buildSeleccion(Color color) {
    return Padding(
      key: const ValueKey('seleccion'),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 30),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.timer_outlined, color: color, size: 40),
          ),
          const SizedBox(height: 20),
          Text(
            'Modo Contrarreloj',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Resuelve cuántos puedas antes que se acabe el tiempo. ¡Cada acierto suma 10 puntos y hay bonus por racha!',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 30),
          const Text(
            'Elige la duración',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 16),
          _BotonDuracion(
            label: '30 segundos',
            sub: 'Modo rápido',
            icono: Icons.flash_on,
            color: color,
            onTap: () => _iniciarJuego(30),
          ),
          const SizedBox(height: 12),
          _BotonDuracion(
            label: '60 segundos',
            sub: 'El clásico',
            icono: Icons.timer,
            color: color,
            destacado: true,
            onTap: () => _iniciarJuego(60),
          ),
          const SizedBox(height: 12),
          _BotonDuracion(
            label: '90 segundos',
            sub: 'Modo relajado',
            icono: Icons.hourglass_bottom,
            color: color,
            onTap: () => _iniciarJuego(90),
          ),
        ],
      ),
    );
  }

  // ─── Fase 2: Juego ───────────────────────────────────────────────────────
  Widget _buildJuego(Color color) {
    final pregunta = _pregunta!;
    final opciones = pregunta['opciones'] as List<String>;
    final correcta = pregunta['correcta'] as String;
    final progresoTiempo = _segundosRestantes / _duracionTotal;

    return Padding(
      key: const ValueKey('juego'),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Barra de tiempo
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progresoTiempo.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: AppColors.border,
              valueColor: AlwaysStoppedAnimation<Color>(
                _segundosRestantes <= 10
                    ? AppColors.danger
                    : color,
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Stats
          Row(
            children: [
              _ChipStat(
                icon: Icons.local_fire_department,
                valor: '$_rachaActual',
                label: 'Racha',
                color: AppColors.warning,
              ),
              const SizedBox(width: 10),
              _ChipStat(
                icon: Icons.check_circle,
                valor: '$_aciertos',
                label: 'Aciertos',
                color: AppColors.success,
              ),
              const SizedBox(width: 10),
              _ChipStat(
                icon: Icons.star,
                valor: '$_puntosSesion',
                label: 'Puntos',
                color: AppColors.danger,
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Tarjeta de pregunta
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: color.withValues(alpha: 0.4),
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
          const SizedBox(height: 20),

          // Opciones
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
                          fontSize: 22,
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
    );
  }

  // ─── Fase 3: Resultados ──────────────────────────────────────────────────
  Widget _buildResultados(Color color) {
    final total = _aciertos + _errores;
    final precision =
        total > 0 ? '${((_aciertos / total) * 100).toInt()}%' : '0%';

    String mensaje;
    IconData icono;
    Color colorMensaje;
    if (_aciertos == 0) {
      mensaje = '¡Sigue practicando!';
      icono = Icons.fitness_center;
      colorMensaje = AppColors.textSecondary;
    } else if (total > 0 && _aciertos / total >= 0.8) {
      mensaje = '¡Excelente trabajo!';
      icono = Icons.emoji_events;
      colorMensaje = AppColors.warning;
    } else if (total > 0 && _aciertos / total >= 0.5) {
      mensaje = '¡Buen trabajo!';
      icono = Icons.thumb_up;
      colorMensaje = AppColors.success;
    } else {
      mensaje = '¡Casi! Sigue practicando';
      icono = Icons.school;
      colorMensaje = AppColors.primaryLight;
    }

    return SingleChildScrollView(
      key: const ValueKey('resultados'),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: colorMensaje.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icono, color: colorMensaje, size: 50),
          ),
          const SizedBox(height: 16),
          Text(
            mensaje,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: colorMensaje,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${widget.tema.nombre} · $_duracionTotal s',
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 30),

          // Tarjetas de resultados
          Row(
            children: [
              Expanded(
                child: _StatGrande(
                  valor: '$_aciertos',
                  label: 'Aciertos',
                  color: AppColors.success,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatGrande(
                  valor: '$_errores',
                  label: 'Errores',
                  color: AppColors.danger,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatGrande(
                  valor: precision,
                  label: 'Precisión',
                  color: AppColors.temaRestas,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatGrande(
                  valor: '$_mejorRacha',
                  label: 'Mejor racha',
                  color: AppColors.warning,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.star, color: AppColors.warning, size: 28),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Puntos ganados',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Text(
                  '+$_puntosSesion',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.danger,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),

          // Botones
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: () =>
                  setState(() => _fase = _Fase.seleccion),
              icon: const Icon(Icons.replay),
              label: const Text(
                'Jugar de nuevo',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.home_outlined),
              label: const Text(
                'Volver al inicio',
                style: TextStyle(fontSize: 15),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                side: BorderSide(color: AppColors.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Widgets auxiliares
// ─────────────────────────────────────────────────────────────────────────────

class _BotonDuracion extends StatelessWidget {
  final String label;
  final String sub;
  final IconData icono;
  final Color color;
  final bool destacado;
  final VoidCallback onTap;

  const _BotonDuracion({
    required this.label,
    required this.sub,
    required this.icono,
    required this.color,
    required this.onTap,
    this.destacado = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: destacado ? color : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: destacado ? color : AppColors.border,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icono,
              color: destacado ? Colors.white : color,
              size: 26,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: destacado ? Colors.white : Colors.black87,
                    ),
                  ),
                  Text(
                    sub,
                    style: TextStyle(
                      fontSize: 12,
                      color: destacado
                          ? Colors.white.withValues(alpha: 0.85)
                          : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: destacado
                  ? Colors.white
                  : AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}

class _ChipStat extends StatelessWidget {
  final IconData icon;
  final String valor;
  final String label;
  final Color color;

  const _ChipStat({
    required this.icon,
    required this.valor,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 14),
                const SizedBox(width: 4),
                Text(
                  valor,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatGrande extends StatelessWidget {
  final String valor;
  final String label;
  final Color color;

  const _StatGrande({
    required this.valor,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Text(
            valor,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
