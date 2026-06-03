// lib/screens/practica_screen.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/ia_service.dart';
import '../services/local_storage_service.dart';
import '../services/notification_service.dart';
import '../services/sync_service.dart';
import '../services/sound_service.dart';
import '../theme/app_theme.dart';

/// Tema disponible para practicar
enum TemaPractica { sumas, restas, multiplicacion, division }

/// Nivel de dificultad
enum NivelDificultad { facil, normal, dificil, experto }

extension NivelDificultadX on NivelDificultad {
  String get label {
    switch (this) {
      case NivelDificultad.facil:
        return '🟢 Fácil';
      case NivelDificultad.normal:
        return '🟡 Normal';
      case NivelDificultad.dificil:
        return '🔴 Difícil';
      case NivelDificultad.experto:
        return '🟣 Experto';
    }
  }

  String get descripcion {
    switch (this) {
      case NivelDificultad.facil:
        return 'Números 1-20 · A veces 3 números';
      case NivelDificultad.normal:
        return 'Números 1-100 · 2-3 operandos';
      case NivelDificultad.dificil:
        return 'Números grandes · 3 operandos · Opciones cercanas';
      case NivelDificultad.experto:
        return 'Números enormes · Operaciones mixtas · Opciones engañosas';
    }
  }
}

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
  final NivelDificultad nivelDificultad;

  const PracticaScreen({
    super.key,
    required this.tema,
    required this.gradoNum,
    this.nivelDificultad = NivelDificultad.normal,
  });

  @override
  State<PracticaScreen> createState() => _PracticaScreenState();
}

class _PracticaScreenState extends State<PracticaScreen> {
  final _random = Random();
  // Puede ser null cuando el usuario juega como invitado
  final _user = FirebaseAuth.instance.currentUser;

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

  // 🤖 Grado actual (se actualiza con la IA en tiempo real)
  late int _gradoActual;

  // 📅 Racha diaria: solo actualizamos Firestore una vez por sesión
  bool _rachaActualizadaHoy = false;

  static const List<String> _nombresGrado = [
    '',
    'Nivel Inicial',
    'Nivel Básico',
    'Nivel Intermedio',
    'Nivel Avanzado',
  ];

  @override
  void initState() {
    super.initState();
    _gradoActual = widget.gradoNum;
  }

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
    if (!LocalStorageService.isGuest && _user != null) {
      _contarPartida();
      _actualizarRetos();
    }
    // IA adaptativa: se llama UNA vez al terminar la partida (no por respuesta)
    _actualizarNivelConIA();
    // Cancelar alerta de racha para hoy (el usuario ya practicó)
    NotificationService.marcarPracticadoHoy();
  }

  // Incrementa el contador de partidas completadas para este tema.
  // Si la dificultad es Difícil o Experto, también incrementa partidas_dificil
  // (que es el requisito para desbloquear la evaluación).
  Future<void> _contarPartida() async {
    if (_user == null) return;
    final tema = widget.tema.name; // 'sumas', 'restas', etc.
    try {
      final updates = <String, dynamic>{
        'temas.$tema.partidas': FieldValue.increment(1),
      };
      if (widget.nivelDificultad.index >= NivelDificultad.dificil.index) {
        updates['temas.$tema.partidas_dificil'] = FieldValue.increment(1);
      }
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_user.uid)
          .update(updates);
    } catch (e) {
      debugPrint('Error contando partida: $e');
    }
  }

  // ─── IA adaptativa: actualizar nivel al finalizar partida ────────────────
  Future<void> _actualizarNivelConIA() async {
    try {
      Map<String, dynamic> data;
      final tema = widget.tema.clave;

      if (LocalStorageService.isGuest || _user == null) {
        // Invitado: leer datos locales
        data = LocalStorageService.getData();
      } else {
        // Con cuenta: leer Firestore
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(_user!.uid)
            .get();
        if (!doc.exists || doc.data() == null) return;
        data = doc.data()!;
      }

      final intentosTotales = (data['intentos'] ?? 1) as int;
      final tiempoTotal = ((data['tiempo_total'] ?? 0) as num).toDouble();
      final tiempoPromedio = tiempoTotal / intentosTotales.clamp(1, 1 << 31);

      // Precisión por tema (0.0 – 1.0)
      double precisionTema(String t) {
        final temaMap =
            (data['temas'] as Map<String, dynamic>?)?[t]
                as Map<String, dynamic>?;
        if (temaMap == null) return 0.0;
        final ac = (temaMap['aciertos'] ?? 0) as int;
        final int_ = (temaMap['intentos'] ?? 0) as int;
        if (int_ == 0) return 0.0;
        return ac / int_;
      }

      final ia = await IAService.clasificar(
        aciertos: (data['aciertos'] ?? 0) as int,
        errores: (data['errores'] ?? 0) as int,
        tiempo: tiempoPromedio,
        intentos: intentosTotales,
        precisionSumas: precisionTema('sumas'),
        precisionRestas: precisionTema('restas'),
        precisionMult: precisionTema('multiplicacion'),
        precisionDiv: precisionTema('division'),
        temaActual: tema,
      );

      final nuevoGrado = (ia['grado'] as num).toInt();

      if (LocalStorageService.isGuest || _user == null) {
        await LocalStorageService.updateFields({
          'grado': ia['descripcion'],
          'grado_num': nuevoGrado,
        });
      } else {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(_user!.uid)
            .update({'grado': ia['descripcion'], 'grado_num': nuevoGrado});
      }

      _mostrarCambioNivel(nuevoGrado);
    } catch (e) {
      debugPrint('IA no disponible (se ignorará): $e');
    }
  }

  // ─── Actualizar retos del día ─────────────────────────────────────────────
  Future<void> _actualizarRetos() async {
    if (_user == null) return;
    try {
      final ref = FirebaseFirestore.instance
          .collection('users')
          .doc(_user!.uid);
      final doc = await ref.get();
      final data = doc.data();
      if (data == null) return;

      final ahora = DateTime.now();
      final fechaHoy =
          '${ahora.year}-${ahora.month.toString().padLeft(2, '0')}-${ahora.day.toString().padLeft(2, '0')}';

      // Datos actuales de retos (pueden ser de otro día → resetear)
      final retosActual =
          (data['retos_diarios'] as Map<String, dynamic>?) ?? {};
      final esMismoDia = (retosActual['fecha'] as String?) == fechaHoy;

      final aciertosAntMejor = esMismoDia
          ? (retosActual['aciertos_mejor_sesion'] as int?) ?? 0
          : 0;
      final precisionAntMejor = esMismoDia
          ? (retosActual['precision_mejor_sesion'] as num?)?.toDouble() ?? 0.0
          : 0.0;
      final ejerciciosHoy = esMismoDia
          ? (retosActual['ejercicios_hoy'] as int?) ?? 0
          : 0;
      final completadosAnt = esMismoDia
          ? ((retosActual['completados'] as List?)?.cast<String>() ?? [])
          : <String>[];
      final puntosRetosAnt = esMismoDia
          ? (retosActual['puntos_retos'] as int?) ?? 0
          : 0;

      // Calcular valores de esta sesión
      final total = _aciertos + _errores;
      final precision = total > 0 ? _aciertos / total : 0.0;
      final ejerciciosNuevos = ejerciciosHoy + total;

      // Nuevos mejores
      final nuevoMejorAciertos = _aciertos > aciertosAntMejor
          ? _aciertos
          : aciertosAntMejor;
      final nuevoMejorPrecision = precision > precisionAntMejor
          ? precision
          : precisionAntMejor;

      // Verificar qué retos se completaron
      final completados = List<String>.from(completadosAnt);
      int puntosNuevos = puntosRetosAnt;

      void _check(String id, bool condicion, int pts) {
        if (condicion && !completados.contains(id)) {
          completados.add(id);
          puntosNuevos += pts;
        }
      }

      _check('velocidad', nuevoMejorAciertos >= 15, 50);
      _check('punteria', nuevoMejorPrecision >= 0.8 && total >= 10, 40);
      _check('constancia', ejerciciosNuevos >= 25, 30);

      // Guardar en Firestore
      await SyncService.wrap(
        () => ref.update({
          'retos_diarios': {
            'fecha': fechaHoy,
            'aciertos_mejor_sesion': nuevoMejorAciertos,
            'precision_mejor_sesion': nuevoMejorPrecision,
            'ejercicios_hoy': ejerciciosNuevos,
            'completados': completados,
            'puntos_retos': puntosNuevos,
          },
          if (puntosNuevos > puntosRetosAnt)
            'puntos': FieldValue.increment(puntosNuevos - puntosRetosAnt),
        }),
      );

      // Mostrar notificación si se desbloqueó un reto nuevo
      final nuevos = completados
          .where((id) => !completadosAnt.contains(id))
          .toList();
      if (nuevos.isNotEmpty && mounted) {
        final nombres = {
          'velocidad': '🏃 Velocidad mental',
          'punteria': '🎯 Puntería',
          'constancia': '📚 Constancia del día',
        };
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '¡Reto completado: ${nombres[nuevos.first] ?? nuevos.first}! +pts',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            backgroundColor: Colors.amber[800],
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(12),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error actualizando retos: $e');
    }
  }

  // ─── Racha de días consecutivos ───────────────────────────────────────────
  Future<void> _actualizarRachaDias(DocumentReference? ref) async {
    if (_rachaActualizadaHoy) return;

    try {
      final ahora = DateTime.now();
      final hoy = DateTime(ahora.year, ahora.month, ahora.day);

      if (LocalStorageService.isGuest) {
        // ── Invitado: leer/escribir en local ─────────────────────────────
        final data = LocalStorageService.getData();
        final ultimaStr = data['ultimaPractica'] as String?;
        final DateTime? ultimaDt = ultimaStr != null
            ? DateTime.tryParse(ultimaStr)
            : null;

        if (ultimaDt != null) {
          final ultimoDia = DateTime(
            ultimaDt.year,
            ultimaDt.month,
            ultimaDt.day,
          );
          if (hoy.difference(ultimoDia).inDays == 0) {
            _rachaActualizadaHoy = true;
            return;
          }
        }

        int nuevaRacha;
        if (ultimaDt == null) {
          nuevaRacha = 1;
        } else {
          final ultimoDia = DateTime(
            ultimaDt.year,
            ultimaDt.month,
            ultimaDt.day,
          );
          final dias = hoy.difference(ultimoDia).inDays;
          nuevaRacha = dias == 1 ? ((data['racha'] ?? 0) as int) + 1 : 1;
        }

        await LocalStorageService.updateFields({
          'racha': nuevaRacha,
          'ultimaPractica': hoy.toIso8601String(),
        });
        _rachaActualizadaHoy = true;
      } else {
        // ── Con cuenta: leer/escribir en Firestore ────────────────────────
        if (ref == null) return;
        final doc = await ref.get();
        final data = doc.data() as Map<String, dynamic>?;
        if (data == null) return;

        final ultimaRaw = data['ultimaPractica'];
        final DateTime? ultimaDt = ultimaRaw is Timestamp
            ? ultimaRaw.toDate()
            : null;

        if (ultimaDt != null) {
          final ultimoDia = DateTime(
            ultimaDt.year,
            ultimaDt.month,
            ultimaDt.day,
          );
          if (hoy.difference(ultimoDia).inDays == 0) {
            _rachaActualizadaHoy = true;
            return;
          }
        }

        int nuevaRacha;
        if (ultimaDt == null) {
          nuevaRacha = 1;
        } else {
          final ultimoDia = DateTime(
            ultimaDt.year,
            ultimaDt.month,
            ultimaDt.day,
          );
          final dias = hoy.difference(ultimoDia).inDays;
          nuevaRacha = dias == 1 ? ((data['racha'] ?? 0) as int) + 1 : 1;
        }

        await ref.update({
          'racha': nuevaRacha,
          'ultimaPractica': Timestamp.fromDate(hoy),
        });
        _rachaActualizadaHoy = true;
      }
    } catch (e) {
      debugPrint('Error actualizando racha de días: $e');
    }
  }

  // ─── Dificultad según grado + nivel ───────────────────────────────────────
  //
  // Fácil:   1–20   · opciones alejadas (delta ±4–10)
  // Normal:  1–100  · 2-3 operandos · opciones moderadas (delta ±3–8)
  // Difícil: 1–200  · 3 operandos · opciones muy cercanas (delta ±1–3)
  // Experto: 1–600  · operaciones mixtas · opciones ±1
  //
  ({int max, int base}) get _rangos {
    int maxBase = switch (widget.nivelDificultad) {
      NivelDificultad.facil => 20,
      NivelDificultad.normal => 100,
      NivelDificultad.dificil => 200,
      NivelDificultad.experto => 600,
    };
    // Reducción suave por grado bajo (la dificultad elegida sigue mandando,
    // para que "Normal" realmente llegue a números altos y se sienta variado).
    final factor = switch (_gradoActual) {
      4 => 0.85,
      3 => 0.75,
      2 => 0.65,
      _ => 1.0,
    };
    final maxAjustado = (maxBase * factor).round().clamp(10, maxBase);
    return (max: maxAjustado, base: 1);
  }

  // Rangos para tabla de multiplicar según dificultad
  ({int maxA, int maxB}) get _rangosMult {
    final base = switch (widget.nivelDificultad) {
      NivelDificultad.facil => (maxA: 5, maxB: 5),
      NivelDificultad.normal => (maxA: 9, maxB: 9),
      NivelDificultad.dificil => (maxA: 15, maxB: 12),
      NivelDificultad.experto => (maxA: 25, maxB: 15),
    };
    // Reducción por grado bajo
    switch (_gradoActual) {
      case 2:
        return (
          maxA: (base.maxA * 0.5).toInt().clamp(3, base.maxA),
          maxB: (base.maxB * 0.5).toInt().clamp(3, base.maxB),
        );
      case 3:
        return (
          maxA: (base.maxA * 0.7).toInt().clamp(4, base.maxA),
          maxB: (base.maxB * 0.7).toInt().clamp(4, base.maxB),
        );
      default:
        return base;
    }
  }

  // Amplitud del delta para las opciones incorrectas según dificultad.
  // Difícil → opciones muy cercanas a la correcta (más engañosas).
  int get _deltaOpciones => switch (widget.nivelDificultad) {
    NivelDificultad.facil => _random.nextInt(7) + 4, // ±4–10
    NivelDificultad.normal => _random.nextInt(6) + 3, // ±3–8
    NivelDificultad.dificil => _random.nextInt(3) + 1, // ±1–3
    NivelDificultad.experto => 1, // siempre ±1 (muy engañoso)
  };

  // ─── Generador de preguntas ───────────────────────────────────────────────
  Map<String, Object> _generarPregunta() {
    int respuesta;
    String preguntaStr;
    final rangos = _rangos;
    final nivel = widget.nivelDificultad;
    final esExperto = nivel == NivelDificultad.experto;
    // Probabilidad de usar una forma con más operandos (más variedad).
    // Incluso Fácil y Normal varían seguido para que no se sienta repetitivo.
    final double pVariante = switch (nivel) {
      NivelDificultad.facil => 0.35,
      NivelDificultad.normal => 0.60,
      NivelDificultad.dificil => 0.80,
      NivelDificultad.experto => 1.0,
    };
    final usarVariante = _random.nextDouble() < pVariante;

    // Aleatorio en [1, max] respetando la base
    int rnd(int max) => _random.nextInt(max < 1 ? 1 : max) + rangos.base;

    switch (widget.tema) {
      // ── SUMAS ─────────────────────────────────────────────────────────────
      case TemaPractica.sumas:
        final a = rnd(rangos.max);
        final b = rnd(rangos.max);
        if (esExperto) {
          // 3 o 4 sumandos con números grandes
          final c = rnd(rangos.max);
          if (_random.nextBool()) {
            final d = rnd(rangos.max ~/ 2);
            respuesta = a + b + c + d;
            preguntaStr = '$a + $b + $c + $d = ?';
          } else {
            respuesta = a + b + c;
            preguntaStr = '$a + $b + $c = ?';
          }
        } else if (usarVariante) {
          // 3 sumandos
          final c = rnd(rangos.max ~/ 2);
          respuesta = a + b + c;
          preguntaStr = '$a + $b + $c = ?';
        } else {
          respuesta = a + b;
          preguntaStr = '$a + $b = ?';
        }
        break;

      // ── RESTAS ────────────────────────────────────────────────────────────
      case TemaPractica.restas:
        if (esExperto) {
          if (_random.nextBool()) {
            // a - b - c  (siempre positivo)
            final b = rnd(rangos.max ~/ 3);
            final c = rnd(rangos.max ~/ 3);
            final a = b + c + rnd(rangos.max); // garantiza resultado positivo
            respuesta = a - b - c;
            preguntaStr = '$a - $b - $c = ?';
          } else {
            // a - b + c
            final a = rnd(rangos.max) + rangos.max ~/ 2;
            final b = rnd(rangos.max ~/ 2);
            final c = rnd(rangos.max ~/ 3);
            respuesta = a - b + c;
            preguntaStr = '$a - $b + $c = ?';
          }
        } else if (usarVariante) {
          // a - b + c  (resultado siempre positivo)
          final a = rnd(rangos.max) + rangos.max ~/ 2;
          final b = rnd(rangos.max ~/ 2);
          final c = rnd(rangos.max ~/ 3);
          respuesta = a - b + c;
          preguntaStr = '$a - $b + $c = ?';
        } else {
          final b = rnd(rangos.max);
          final a = b + rnd(rangos.max);
          respuesta = a - b;
          preguntaStr = '$a - $b = ?';
        }
        break;

      // ── MULTIPLICACIÓN ────────────────────────────────────────────────────
      case TemaPractica.multiplicacion:
        final r = _rangosMult;
        final a = _random.nextInt(r.maxA) + 1;
        final b = _random.nextInt(r.maxB) + 1;
        if (esExperto) {
          // (a × b) ± c con números mayores
          final c = _random.nextInt(20) + 1;
          if (_random.nextBool() && a * b > c) {
            respuesta = a * b - c;
            preguntaStr = '$a × $b - $c = ?';
          } else {
            respuesta = a * b + c;
            preguntaStr = '$a × $b + $c = ?';
          }
        } else if (usarVariante) {
          // (a × b) + c
          final c = _random.nextInt(10) + 1;
          respuesta = a * b + c;
          preguntaStr = '$a × $b + $c = ?';
        } else {
          respuesta = a * b;
          preguntaStr = '$a × $b = ?';
        }
        break;

      // ── DIVISIÓN ──────────────────────────────────────────────────────────
      case TemaPractica.division:
        final r = _rangosMult;
        final b = _random.nextInt(r.maxB - 1) + 2;
        final cociente = _random.nextInt(r.maxA) + 1;
        final a = b * cociente;
        if (esExperto) {
          // Dividendo enorme y a veces (a ÷ b) + c
          final k = _random.nextInt(4) + 3; // ×3–6
          final bigA = a * k;
          if (_random.nextBool()) {
            final c = _random.nextInt(15) + 1;
            respuesta = cociente * k + c;
            preguntaStr = '$bigA ÷ $b + $c = ?';
          } else {
            respuesta = cociente * k;
            preguntaStr = '$bigA ÷ $b = ?';
          }
        } else if (usarVariante) {
          // Dividendo más grande (a × k) ÷ b
          final k = _random.nextInt(3) + 2;
          final bigA = a * k;
          respuesta = cociente * k;
          preguntaStr = '$bigA ÷ $b = ?';
        } else {
          respuesta = cociente;
          preguntaStr = '$a ÷ $b = ?';
        }
        break;
    }

    // ── Generar 3 opciones incorrectas con delta acorde a la dificultad ──────
    final Set<int> incorrectas = {};
    int tries = 0;
    while (incorrectas.length < 3 && tries < 60) {
      tries++;
      final d = _deltaOpciones;
      final signo = _random.nextBool() ? 1 : -1;
      final falsa = respuesta + signo * d;
      if (falsa != respuesta && falsa > 0) incorrectas.add(falsa);
    }
    // Fallback si quedan huecos
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

    // Sonido + vibración de feedback
    if (esCorrecta) {
      SoundService.correcto();
    } else {
      SoundService.error();
    }

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

  /// Guarda una respuesta en Firestore o en local según el modo de sesión.
  Future<void> _guardarRespuesta(bool correcta) async {
    final tema = widget.tema.clave;
    int puntosGanados = correcta
        ? (10 + (_rachaActual > 0 && _rachaActual % 5 == 0 ? 20 : 0))
        : 0;

    if (LocalStorageService.isGuest) {
      // ── Invitado: actualizar SharedPreferences ─────────────────────────
      await LocalStorageService.increment('aciertos', correcta ? 1 : 0);
      await LocalStorageService.increment('errores', correcta ? 0 : 1);
      await LocalStorageService.increment('intentos', 1);
      await LocalStorageService.increment('tiempo_total', 20);
      await LocalStorageService.incrementNested('temas.$tema.intentos', 1);
      if (correcta)
        await LocalStorageService.incrementNested('temas.$tema.aciertos', 1);
      if (puntosGanados > 0)
        await LocalStorageService.increment('puntos', puntosGanados);

      await _actualizarRachaDias(null);
    } else {
      // ── Con cuenta: actualizar Firestore ────────────────────────────────
      final ref = FirebaseFirestore.instance
          .collection('users')
          .doc(_user!.uid);

      try {
        await SyncService.wrap(
          () => ref.update({
            'aciertos': FieldValue.increment(correcta ? 1 : 0),
            'errores': FieldValue.increment(correcta ? 0 : 1),
            'intentos': FieldValue.increment(1),
            'tiempo_total': FieldValue.increment(20),
            'temas.$tema.intentos': FieldValue.increment(1),
            if (correcta) 'temas.$tema.aciertos': FieldValue.increment(1),
            if (puntosGanados > 0)
              'puntos': FieldValue.increment(puntosGanados),
          }),
        );
      } catch (e) {
        debugPrint('Error guardando respuesta: $e');
      }

      await _actualizarRachaDias(ref);
    }
  }

  void _mostrarCambioNivel(int nuevoGrado) {
    if (nuevoGrado == _gradoActual || !mounted) return;
    final subio = nuevoGrado > _gradoActual;
    if (subio) SoundService.nivel();
    setState(() => _gradoActual = nuevoGrado);
    final nombre =
        _nombresGrado.elementAtOrNull(nuevoGrado) ?? 'Nivel $nuevoGrado';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Text(subio ? '🔥' : '💡', style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                subio
                    ? '¡Subiste a $nombre!'
                    : 'Ajustando dificultad a $nombre',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: subio ? Colors.green[700] : Colors.orange[700],
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(12),
      ),
    );
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
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
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
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.timer, color: Colors.white, size: 16),
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
    final tema = widget.tema;
    return SingleChildScrollView(
      key: const ValueKey('seleccion'),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Header con ícono del tema
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(tema.icono, color: color, size: 34),
          ),
          const SizedBox(height: 14),
          Text(
            tema.nombre,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '¿Cuánto tiempo quieres practicar?',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 28),

          // Tarjeta 30s
          _TiempoCard(
            segundos: 30,
            titulo: '¡Súper rápido!',
            descripcion: 'Un reto relámpago — ¿cuántos puedes?',
            icono: Icons.bolt_rounded,
            colorFondo: const Color(0xFFFFEBEE),
            colorIcono: Color(0xFFE53935),
            onTap: () => _iniciarJuego(30),
          ),
          const SizedBox(height: 12),

          // Tarjeta 60s — destacada
          _TiempoCard(
            segundos: 60,
            titulo: 'El clásico',
            descripcion: 'El tiempo perfecto para calentar motores',
            icono: Icons.timer_rounded,
            colorFondo: color.withValues(alpha: 0.12),
            colorIcono: color,
            destacado: true,
            colorDestacado: color,
            onTap: () => _iniciarJuego(60),
          ),
          const SizedBox(height: 12),

          // Tarjeta 90s
          _TiempoCard(
            segundos: 90,
            titulo: 'Con calma',
            descripcion: 'Más tiempo para pensar sin estresarte',
            icono: Icons.hourglass_bottom_rounded,
            colorFondo: const Color(0xFFE8F5E9),
            colorIcono: Color(0xFF43A047),
            onTap: () => _iniciarJuego(90),
          ),

          const SizedBox(height: 20),
          // Info de puntos
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.star_rounded,
                  color: Colors.amber.shade600,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  'Cada acierto = 10 pts · Racha bonus extra',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
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
                _segundosRestantes <= 10 ? AppColors.danger : color,
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Stats
          Row(
            children: [
              _ChipStat(
                icon: Icons.format_list_numbered,
                valor: '${_aciertos + _errores}',
                label: 'Intentos',
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
    final precision = total > 0
        ? '${((_aciertos / total) * 100).toInt()}%'
        : '0%';

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
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
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
              onPressed: () => setState(() => _fase = _Fase.seleccion),
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
            Icon(icono, color: destacado ? Colors.white : color, size: 26),
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
              color: destacado ? Colors.white : AppColors.textMuted,
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
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      ),
    );
  }
}

// ── Tarjeta de selección de tiempo ───────────────────────────────────────────
class _TiempoCard extends StatelessWidget {
  final int segundos;
  final String titulo;
  final String descripcion;
  final IconData icono;
  final Color colorFondo;
  final Color colorIcono;
  final bool destacado;
  final Color? colorDestacado;
  final VoidCallback onTap;

  const _TiempoCard({
    required this.segundos,
    required this.titulo,
    required this.descripcion,
    required this.icono,
    required this.colorFondo,
    required this.colorIcono,
    required this.onTap,
    this.destacado = false,
    this.colorDestacado,
  });

  @override
  Widget build(BuildContext context) {
    final bg = destacado ? (colorDestacado ?? colorIcono) : AppColors.surface;
    final textColor = destacado ? Colors.white : AppColors.textPrimary;
    final subColor = destacado
        ? Colors.white.withValues(alpha: 0.85)
        : AppColors.textSecondary;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: destacado ? Colors.transparent : AppColors.border,
            width: 1.5,
          ),
          boxShadow: destacado
              ? [
                  BoxShadow(
                    color: colorIcono.withValues(alpha: 0.30),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ]
              : [],
        ),
        child: Row(
          children: [
            // Ícono con badge de segundos
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: destacado
                        ? Colors.white.withValues(alpha: 0.2)
                        : colorFondo,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    icono,
                    color: destacado ? Colors.white : colorIcono,
                    size: 28,
                  ),
                ),
                Positioned(
                  bottom: -5,
                  right: -8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: destacado ? Colors.white : colorIcono,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${segundos}s',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: destacado ? colorIcono : Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        titulo,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                        ),
                      ),
                      if (destacado) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'Popular',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    descripcion,
                    style: TextStyle(
                      fontSize: 13,
                      color: textColor.withValues(alpha: 0.75),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: textColor.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }
}
