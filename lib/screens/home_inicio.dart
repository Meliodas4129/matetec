import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/local_storage_service.dart';
import '../services/notification_service.dart';
import '../services/theme_service.dart';
import '../widgets/sync_indicator.dart';
import 'admin_screen.dart';
import 'login_screen.dart';
import 'welcome_screen.dart';
import 'diagnostico_screen.dart';
import 'practica_screen.dart';
import 'evaluacion_final_screen.dart';
import 'configuracion_screen.dart';
import 'perfil_editable_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  static const rojo = Color(0xFFE53935);

  // Construye las 4 pantallas a partir de un mapa de datos (Firestore o local)
  List<Widget> _buildScreens(
    Map<String, dynamic> data, {
    bool isGuest = false,
  }) {
    final String nombre =
        data["nombre"] ??
        (data["email"]?.toString().isNotEmpty == true
            ? data["email"].toString().split('@')[0]
            : 'Usuario');
    final String grado = data["grado"] ?? "";
    final String email = data["email"] ?? "";
    final String rol = data["rol"] ?? "estudiante";
    final String ciudad = data["ciudad"] ?? "";
    final String avatar = data["avatar"] ?? "";
    final int gradoNum = data["grado_num"] ?? 1;
    final int aciertos = data["aciertos"] ?? 0;
    final int intentos = data["intentos"] ?? 1;
    final int racha = data["racha"] ?? 0;
    final int puntos = data["puntos"] ?? 0;
    final double progreso = intentos > 0 ? aciertos / intentos : 0.0;
    final Map<String, dynamic> temas =
        (data["temas"] as Map<String, dynamic>?) ?? const {};
    final List<String> temasDesbloqueados =
        ((data["temas_desbloqueados"] as List?)?.cast<String>()) ?? ['sumas'];
    final Map<String, dynamic> retosDiarios =
        (data["retos_diarios"] as Map<String, dynamic>?) ?? {};

    return [
      _Inicio(
        nombre: nombre,
        grado: grado,
        gradoNum: gradoNum,
        racha: racha,
        puntos: puntos,
        avatar: avatar,
        temasDesbloqueados: temasDesbloqueados,
        temas: temas,
      ),
      _Progreso(
        aciertos: aciertos,
        intentos: intentos,
        progreso: progreso,
        temas: temas,
      ),
      _Retos(retos: retosDiarios, puntos: puntos),
      _Perfil(
        nombre: nombre,
        grado: grado,
        email: email,
        aciertos: aciertos,
        racha: racha,
        puntos: puntos,
        ciudad: ciudad,
        avatar: avatar,
        isGuest: isGuest,
        isAdmin: rol == 'admin',
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    // Si hay usuario de Firebase activo, siempre usar Firestore aunque
    // isGuest quedara en true por una sesión anterior como invitado
    final firebaseUser = FirebaseAuth.instance.currentUser;
    final isGuest = firebaseUser == null && LocalStorageService.isGuest;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          bottom: false,
          child: isGuest
              // ── Modo invitado: datos desde ValueNotifier local ──────────
              ? ValueListenableBuilder<Map<String, dynamic>>(
                  valueListenable: LocalStorageService.guestDataNotifier,
                  builder: (context, data, _) {
                    final screens = _buildScreens(data, isGuest: true);
                    return IndexedStack(
                      index: _currentIndex,
                      children: screens,
                    );
                  },
                )
              // ── Usuario con cuenta: datos desde Firestore ───────────────
              : StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(FirebaseAuth.instance.currentUser!.uid)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final data = snapshot.data!.data() as Map<String, dynamic>;
                    final screens = _buildScreens(data);
                    return IndexedStack(
                      index: _currentIndex,
                      children: screens,
                    );
                  },
                ),
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 12,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: BottomNavigationBar(
              currentIndex: _currentIndex,
              backgroundColor: AppColors.surface,
              selectedItemColor: rojo,
              unselectedItemColor: AppColors.textMuted,
              selectedLabelStyle: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: const TextStyle(fontSize: 11),
              type: BottomNavigationBarType.fixed,
              elevation: 0,
              onTap: (i) => setState(() => _currentIndex = i),
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.home_outlined),
                  activeIcon: Icon(Icons.home),
                  label: 'Inicio',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.bar_chart_outlined),
                  activeIcon: Icon(Icons.bar_chart),
                  label: 'Progreso',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.extension_outlined),
                  activeIcon: Icon(Icons.extension),
                  label: 'Retos',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.person_outline),
                  activeIcon: Icon(Icons.person),
                  label: 'Perfil',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 🏠 INICIO
// ─────────────────────────────────────────────────────────────────────────────
class _Inicio extends StatelessWidget {
  final String nombre;
  final String grado;
  final int gradoNum;
  final int racha;
  final int puntos;
  final String avatar;
  final List<String> temasDesbloqueados;
  final Map<String, dynamic> temas;

  const _Inicio({
    required this.nombre,
    required this.grado,
    required this.gradoNum,
    required this.racha,
    required this.puntos,
    this.avatar = '',
    required this.temasDesbloqueados,
    required this.temas,
  });

  // Orden fijo: sumas desbloquea restas, restas → mult, mult → div
  static const _temasConfig = [
    (
      nombre: 'Sumas',
      icono: Icons.add,
      color: Color(0xFFE53935),
      fondo: AppColors.temaSumasSoft,
      subtitulo: 'Practica sumando',
      clave: 'sumas',
      siguiente: 'restas',
      tema: TemaPractica.sumas,
    ),
    (
      nombre: 'Restas',
      icono: Icons.remove,
      color: AppColors.temaRestas,
      fondo: AppColors.temaRestasSoft,
      subtitulo: 'Practica restando',
      clave: 'restas',
      siguiente: 'multiplicacion',
      tema: TemaPractica.restas,
    ),
    (
      nombre: 'Multiplicación',
      icono: Icons.close,
      color: AppColors.temaMult,
      fondo: AppColors.temaMultSoft,
      subtitulo: 'Tablas de multiplicar',
      clave: 'multiplicacion',
      siguiente: 'division',
      tema: TemaPractica.multiplicacion,
    ),
    (
      nombre: 'División',
      icono: Icons.more_horiz,
      color: AppColors.temaDiv,
      fondo: AppColors.temaDivSoft,
      subtitulo: 'Divisiones exactas',
      clave: 'division',
      siguiente: '',
      tema: TemaPractica.division,
    ),
  ];

  String _saludo() {
    final hora = DateTime.now().hour;
    if (hora < 12) return 'Buenos días';
    if (hora < 19) return 'Buenas tardes';
    return 'Buenas noches';
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header limpio ─────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _saludo(),
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      nombre,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        height: 1.1,
                      ),
                    ),
                    if (grado.isNotEmpty && grado != 'Pendiente') ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE53935).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          grado,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFE53935),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // ── Indicador de sincronización con la nube ───────────────
              const SyncIndicator(),
              const SizedBox(width: 8),
              CircleAvatar(
                radius: 24,
                backgroundColor: avatar.isNotEmpty
                    ? const Color(0xFFFFCDD2)
                    : const Color(0xFFE53935),
                child: avatar.isNotEmpty
                    ? Text(avatar, style: const TextStyle(fontSize: 26))
                    : Text(
                        nombre.isNotEmpty
                            ? nombre.substring(0, 1).toUpperCase()
                            : '?',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.surface,
                        ),
                      ),
              ),
            ],
          ),

          const SizedBox(height: 28),

          // ── Stats horizontales (racha + puntos) ───────────────────────
          Row(
            children: [
              Expanded(
                child: _StatPill(
                  icon: Icons.local_fire_department,
                  iconColor: AppColors.temaDiv,
                  iconBg: AppColors.temaDivSoft,
                  label: 'Racha',
                  valor: '$racha',
                  sub: racha == 1 ? 'día' : 'días',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatPill(
                  icon: Icons.star_rounded,
                  iconColor: const Color(0xFFFFA000),
                  iconBg: const Color(0x1FFFA000),
                  label: 'Puntos',
                  valor: '$puntos',
                  sub: 'totales',
                ),
              ),
            ],
          ),

          const SizedBox(height: 32),

          // ── Sección de temas ──────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Practica un tema',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                '${temasDesbloqueados.length}/${_temasConfig.length}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Aprueba la evaluación de cada tema para avanzar',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              childAspectRatio: 0.80,
            ),
            itemCount: _temasConfig.length,
            itemBuilder: (_, i) {
              final cfg = _temasConfig[i];
              final desbloqueado = temasDesbloqueados.contains(cfg.clave);
              final temaData =
                  (temas[cfg.clave] as Map<String, dynamic>?) ?? {};
              return _TemaCard(
                nombre: cfg.nombre,
                icono: cfg.icono,
                color: cfg.color,
                fondo: cfg.fondo,
                subtitulo: cfg.subtitulo,
                clave: cfg.clave,
                siguienteTema: cfg.siguiente,
                temaPractica: cfg.tema,
                desbloqueado: desbloqueado,
                gradoNum: gradoNum,
                temaData: temaData,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String label;
  final String valor;
  final String sub;

  const _StatPill({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.label,
    required this.valor,
    required this.sub,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        valor,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Text(
                          sub,
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TemaCard extends StatefulWidget {
  final String nombre;
  final IconData icono;
  final Color color;
  final Color fondo;
  final String subtitulo;
  final String clave;
  final String siguienteTema;
  final TemaPractica temaPractica;
  final bool desbloqueado;
  final int gradoNum;
  final Map<String, dynamic> temaData;

  const _TemaCard({
    required this.nombre,
    required this.icono,
    required this.color,
    required this.fondo,
    required this.subtitulo,
    required this.clave,
    required this.siguienteTema,
    required this.temaPractica,
    required this.desbloqueado,
    required this.gradoNum,
    required this.temaData,
  });

  @override
  State<_TemaCard> createState() => _TemaCardState();
}

class _TemaCardState extends State<_TemaCard> {
  // Rastrear si ya mostramos la notificación de evaluación en esta sesión
  bool _notifEvalMostrada = false;

  // ── Getters de conveniencia ───────────────────────────────────────────────
  int  get _partidas        => (widget.temaData['partidas']         as int?) ?? 0;
  int  get _partidasDificil => (widget.temaData['partidas_dificil'] as int?) ?? 0;
  int  get _evalDesde       => (widget.temaData['eval_desde_intentos'] as int?) ?? 5;
  bool get _evalAprobada    => (widget.temaData['eval_aprobada'] as bool?) ?? false;
  bool get _puedeEvaluar    =>
      widget.desbloqueado && !_evalAprobada && _partidasDificil >= _evalDesde;
  int  get _practicasParaEval =>
      (_evalDesde - _partidasDificil).clamp(0, _evalDesde);

  @override
  void didUpdateWidget(_TemaCard old) {
    super.didUpdateWidget(old);
    // Detectar cuando la evaluación se acaba de desbloquear
    final antesPodiaEvaluar = old.desbloqueado &&
        !(old.temaData['eval_aprobada'] ?? false) &&
        ((old.temaData['partidas_dificil'] as int?) ?? 0) >= _evalDesde;
    if (!antesPodiaEvaluar && _puedeEvaluar && !_notifEvalMostrada) {
      _notifEvalMostrada = true;
      NotificationService.mostrarEvaluacionDesbloqueada(widget.nombre);
    }
  }

  void _abrirPractica(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _DificultadSheet(
        nombre: widget.nombre,
        color: widget.color,
        icono: widget.icono,
        onSelect: (nivel) {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PracticaScreen(
                tema: widget.temaPractica,
                gradoNum: widget.gradoNum,
                nivelDificultad: nivel,
              ),
            ),
          );
        },
      ),
    );
  }

  void _abrirEvaluacion(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EvaluacionFinalScreen(
          tema: widget.clave,
          gradoNum: widget.gradoNum,
          siguienteTema: widget.siguienteTema,
          intentosActuales: _partidas,
        ),
      ),
    );
  }

  void _mostrarBloqueado(BuildContext context) {
    // Determinar qué tema prerequisito desbloquea éste
    const prereqs = {
      'restas': 'Sumas',
      'multiplicacion': 'Restas',
      'division': 'Multiplicación',
    };
    final prereq = prereqs[widget.clave] ?? '';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          prereq.isNotEmpty
              ? 'Aprueba la evaluación de $prereq para desbloquear ${widget.nombre}'
              : 'Completa los temas anteriores primero',
        ),
        backgroundColor: AppColors.textPrimary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(12),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: widget.desbloqueado
            ? () => _abrirPractica(context)
            : () => _mostrarBloqueado(context),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _puedeEvaluar
                  ? widget.color.withValues(alpha: 0.5)
                  : AppColors.border,
              width: _puedeEvaluar ? 1.5 : 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Ícono + badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: widget.desbloqueado ? widget.fondo : AppColors.border,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(
                      widget.desbloqueado ? widget.icono : Icons.lock_outline,
                      color: widget.desbloqueado ? widget.color : AppColors.textMuted,
                      size: 21,
                    ),
                  ),
                  if (_evalAprobada)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.check_circle_rounded,
                        color: Colors.green,
                        size: 15,
                      ),
                    )
                  else if (_puedeEvaluar)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.emoji_events_rounded,
                        color: Colors.amber,
                        size: 15,
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 10),

              // Nombre del tema
              Text(
                widget.nombre,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: widget.desbloqueado
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 2),

              // Subtítulo / estado
              if (!widget.desbloqueado)
                Text(
                  'Bloqueado',
                  style: TextStyle(fontSize: 10, color: AppColors.textMuted),
                )
              else if (_evalAprobada)
                Text(
                  '✓ Evaluación aprobada',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.green.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                )
              else if (_puedeEvaluar)
                Text(
                  '¡Listo para evaluar!',
                  style: TextStyle(
                    fontSize: 10,
                    color: widget.color,
                    fontWeight: FontWeight.w600,
                  ),
                )
              else
                Text(
                  widget.subtitulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
                ),

              const Spacer(),

              // Barra de progreso hacia evaluación o botón ¡Evaluarme!
              if (widget.desbloqueado && !_evalAprobada) ...[
                if (_puedeEvaluar) ...[
                  // Botón de evaluación
                  SizedBox(
                    width: double.infinity,
                    height: 30,
                    child: ElevatedButton(
                      onPressed: () => _abrirEvaluacion(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.color,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(9),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        '¡Evaluarme!',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  // Barra de progreso
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: _evalDesde > 0
                          ? (_partidasDificil / _evalDesde).clamp(0.0, 1.0)
                          : 0.0,
                      minHeight: 5,
                      backgroundColor: AppColors.border,
                      valueColor: AlwaysStoppedAnimation<Color>(widget.color),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$_practicasParaEval partida${_practicasParaEval != 1 ? 's' : ''} en 🔴 Difícil para evaluación',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 9, color: AppColors.textSecondary),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 📊 PROGRESO
// ─────────────────────────────────────────────────────────────────────────────
class _Progreso extends StatelessWidget {
  final int aciertos;
  final int intentos;
  final double progreso;
  final Map<String, dynamic> temas;

  const _Progreso({
    required this.aciertos,
    required this.intentos,
    required this.progreso,
    required this.temas,
  });

  static const _colores = [
    Color(0xFFE53935),
    AppColors.temaRestas,
    AppColors.temaMult,
    AppColors.temaDiv,
  ];
  static const _nombres = ['Sumas', 'Restas', 'Multiplicación', 'División'];
  static const _claves = ['sumas', 'restas', 'multiplicacion', 'division'];
  static const _iconos = [
    Icons.add,
    Icons.remove,
    Icons.close,
    Icons.more_horiz,
  ];

  ({double valor, int intentos, int aciertos}) _statsTema(String clave) {
    final t = temas[clave];
    if (t is Map) {
      final int a = (t['aciertos'] as int?) ?? 0;
      final int i = (t['intentos'] as int?) ?? 0;
      final double v = i > 0 ? a / i : 0.0;
      return (valor: v.clamp(0.0, 1.0), intentos: i, aciertos: a);
    }
    return (valor: 0.0, intentos: 0, aciertos: 0);
  }

  @override
  Widget build(BuildContext context) {
    // Solo cuenta lo que viene de la práctica real (sumando los temas)
    int intentosReales = 0;
    int aciertosReales = 0;
    for (final clave in _claves) {
      final s = _statsTema(clave);
      intentosReales += s.intentos;
      aciertosReales += s.aciertos;
    }
    final double precisionReal = intentosReales > 0
        ? aciertosReales / intentosReales
        : 0.0;
    final precisionTexto = intentosReales > 0
        ? '${(precisionReal * 100).toInt()}%'
        : '—';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ─────────────────────────────────────────────────────
          const Text(
            'Mi progreso',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            intentosReales > 0
                ? 'Llevas $intentosReales ejercicios resueltos'
                : 'Empieza a practicar para ver tu progreso',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 26),

          // ── Anillo de precisión + stats laterales ──────────────────────
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                _AnilloPrecision(
                  valor: precisionReal,
                  texto: precisionTexto,
                  hayDatos: intentosReales > 0,
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _MiniStat(
                        label: 'Aciertos',
                        valor: '$aciertosReales',
                        color: AppColors.temaMult,
                      ),
                      const SizedBox(height: 14),
                      _MiniStat(
                        label: 'Errores',
                        valor: '${intentosReales - aciertosReales}',
                        color: const Color(0xFFE53935),
                      ),
                      const SizedBox(height: 14),
                      _MiniStat(
                        label: 'Ejercicios',
                        valor: '$intentosReales',
                        color: AppColors.temaRestas,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // ── Por tema ──────────────────────────────────────────────────
          const Text(
            'Por tema',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tu rendimiento en cada tipo de operación',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 14),
          ..._nombres.asMap().entries.map((e) {
            final i = e.key;
            final stats = _statsTema(_claves[i]);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ProgresoCard(
                nombre: e.value,
                valor: stats.valor,
                intentos: stats.intentos,
                color: _colores[i],
                icono: _iconos[i],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _AnilloPrecision extends StatelessWidget {
  final double valor;
  final String texto;
  final bool hayDatos;

  const _AnilloPrecision({
    required this.valor,
    required this.texto,
    required this.hayDatos,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 110,
      height: 110,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 110,
            height: 110,
            child: CircularProgressIndicator(
              value: hayDatos ? valor : 0,
              strokeWidth: 10,
              backgroundColor: AppColors.border,
              valueColor: AlwaysStoppedAnimation<Color>(
                _colorDePrecision(valor),
              ),
              strokeCap: StrokeCap.round,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                texto,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: hayDatos
                      ? AppColors.textPrimary
                      : AppColors.textMuted,
                ),
              ),
              Text(
                'Precisión',
                style: TextStyle(
                  fontSize: 10,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _colorDePrecision(double v) {
    if (!hayDatos) return AppColors.border;
    if (v >= 0.8) return AppColors.temaMult;
    if (v >= 0.5) return AppColors.temaRestas;
    return const Color(0xFFE53935);
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String valor;
  final Color color;
  const _MiniStat({
    required this.label,
    required this.valor,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
          ),
        ),
        Text(
          valor,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _ProgresoCard extends StatelessWidget {
  final String nombre;
  final double valor;
  final int intentos;
  final Color color;
  final IconData icono;
  const _ProgresoCard({
    required this.nombre,
    required this.valor,
    required this.intentos,
    required this.color,
    required this.icono,
  });

  @override
  Widget build(BuildContext context) {
    final hayDatos = intentos > 0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: hayDatos
                  ? color.withValues(alpha: 0.12)
                  : AppColors.border,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icono,
              color: hayDatos ? color : AppColors.textMuted,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      nombre,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (hayDatos)
                      Text(
                        '${(valor * 100).toInt()}%',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                if (hayDatos) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: valor,
                      minHeight: 6,
                      backgroundColor: AppColors.border,
                      valueColor: AlwaysStoppedAnimation(color),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$intentos ${intentos == 1 ? "ejercicio" : "ejercicios"}',
                    style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                ] else
                  Text(
                    'Aún no has practicado',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 🧩 RETOS DEL DÍA
// ─────────────────────────────────────────────────────────────────────────────

/// Definición estática de cada reto diario.
class _DefReto {
  final String id;
  final String titulo;
  final String descripcion;
  final IconData icono;
  final Color color;
  final int puntos;
  final int meta; // valor objetivo
  final String unidad; // label de la barra de progreso

  const _DefReto({
    required this.id,
    required this.titulo,
    required this.descripcion,
    required this.icono,
    required this.color,
    required this.puntos,
    required this.meta,
    required this.unidad,
  });
}

const _retosDefinidos = [
  _DefReto(
    id: 'velocidad',
    titulo: 'Velocidad mental',
    descripcion: '15 aciertos en una sola sesión',
    icono: Icons.bolt_rounded,
    color: Color(0xFFE53935),
    puntos: 50,
    meta: 15,
    unidad: 'aciertos/sesión',
  ),
  _DefReto(
    id: 'punteria',
    titulo: 'Puntería',
    descripcion: '80% de precisión con al menos 10 intentos',
    icono: Icons.my_location_rounded,
    color: AppColors.temaRestas,
    puntos: 40,
    meta: 80,
    unidad: '% precisión',
  ),
  _DefReto(
    id: 'constancia',
    titulo: 'Constancia del día',
    descripcion: '25 ejercicios en total hoy',
    icono: Icons.fitness_center_rounded,
    color: AppColors.temaMult,
    puntos: 30,
    meta: 25,
    unidad: 'ejercicios',
  ),
];

class _Retos extends StatelessWidget {
  final Map<String, dynamic> retos;
  final int puntos;

  const _Retos({required this.retos, required this.puntos});

  // Verifica que los datos sean del día de hoy
  bool get _esHoy {
    final fecha = retos['fecha'] as String?;
    if (fecha == null) return false;
    final hoy = DateTime.now();
    return fecha ==
        '${hoy.year}-${hoy.month.toString().padLeft(2, '0')}-${hoy.day.toString().padLeft(2, '0')}';
  }

  int _progreso(String id) {
    if (!_esHoy) return 0;
    switch (id) {
      case 'velocidad':
        return (retos['aciertos_mejor_sesion'] as int?) ?? 0;
      case 'punteria':
        final p = (retos['precision_mejor_sesion'] as num?) ?? 0;
        return (p * 100).toInt();
      case 'constancia':
        return (retos['ejercicios_hoy'] as int?) ?? 0;
      default:
        return 0;
    }
  }

  bool _completado(String id) {
    if (!_esHoy) return false;
    final completados = (retos['completados'] as List?)?.cast<String>() ?? [];
    return completados.contains(id);
  }

  int get _puntosRetos {
    if (!_esHoy) return 0;
    return (retos['puntos_retos'] as int?) ?? 0;
  }

  int get _retosCompletados {
    if (!_esHoy) return 0;
    return ((retos['completados'] as List?)?.length ?? 0);
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Retos del día',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    'Se reinician cada medianoche',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$_retosCompletados/${_retosDefinidos.length} completados',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: primary,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Tarjetas de retos
          ..._retosDefinidos.map((def) {
            final prog = _progreso(def.id);
            final ok = _completado(def.id);
            final fraccion = (prog / def.meta).clamp(0.0, 1.0);

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _RetoCard(
                def: def,
                progreso: prog,
                fraccion: fraccion,
                completado: ok,
              ),
            );
          }),

          const SizedBox(height: 8),

          // Resumen de puntos de retos
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0x1FFFA000),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.star_rounded,
                    color: Color(0xFFFFA000),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Puntos por retos hoy',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        '$puntos puntos totales acumulados',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '+$_puntosRetos pts',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFFFA000),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RetoCard extends StatelessWidget {
  final _DefReto def;
  final int progreso;
  final double fraccion;
  final bool completado;

  const _RetoCard({
    required this.def,
    required this.progreso,
    required this.fraccion,
    required this.completado,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: completado
              ? def.color.withValues(alpha: 0.4)
              : AppColors.border,
          width: completado ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: completado
                      ? def.color.withValues(alpha: 0.12)
                      : AppColors.border,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  completado ? Icons.check_circle_rounded : def.icono,
                  color: completado ? def.color : AppColors.textSecondary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      def.titulo,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      def.descripcion,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: completado
                      ? def.color.withValues(alpha: 0.1)
                      : AppColors.border,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  completado ? '✓ +${def.puntos}' : '+${def.puntos} pts',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: completado ? def.color : AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Barra de progreso
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fraccion,
              minHeight: 6,
              backgroundColor: AppColors.border,
              valueColor: AlwaysStoppedAnimation<Color>(
                completado ? def.color : def.color.withValues(alpha: 0.5),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            completado
                ? '¡Completado!'
                : '$progreso / ${def.meta} ${def.unidad}',
            style: TextStyle(
              fontSize: 10,
              color: completado ? def.color : AppColors.textSecondary,
              fontWeight: completado ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 👤 PERFIL
// ─────────────────────────────────────────────────────────────────────────────
class _Perfil extends StatelessWidget {
  final String nombre;
  final String grado;
  final String email;
  final int aciertos;
  final int racha;
  final int puntos;
  final String ciudad;
  final String avatar;
  final bool isGuest;
  final bool isAdmin;

  const _Perfil({
    required this.nombre,
    required this.grado,
    required this.email,
    required this.aciertos,
    required this.racha,
    required this.puntos,
    this.ciudad = "",
    this.avatar = "",
    this.isGuest = false,
    this.isAdmin = false,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: const Color(0xFFFFCDD2),
                  child: avatar.isNotEmpty
                      ? Text(avatar, style: const TextStyle(fontSize: 30))
                      : Text(
                          nombre.isNotEmpty
                              ? nombre.substring(0, 1).toUpperCase()
                              : '?',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFB71C1C),
                          ),
                        ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nombre,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (grado.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFCDD2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            grado,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFB71C1C),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        email,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _StatMini('$aciertos', 'Aciertos')),
              const SizedBox(width: 8),
              Expanded(child: _StatMini('$racha', 'Racha')),
              const SizedBox(width: 8),
              Expanded(child: _StatMini('$puntos', 'Puntos')),
            ],
          ),
          const SizedBox(height: 20),
          _MenuItem(
            icon: Icons.edit_outlined,
            label: 'Editar perfil',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PerfilEditableScreen(
                    nombre: nombre,
                    email: email,
                    ciudad: ciudad,
                    avatar: avatar,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          _MenuItem(
            icon: Icons.settings_outlined,
            label: 'Configuración',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ConfiguracionScreen()),
            ),
          ),
          const SizedBox(height: 8),

          // ── Panel de administrador (solo admins) ──────────────────────
          if (isAdmin) ...[
            _MenuItem(
              icon: Icons.admin_panel_settings_outlined,
              label: 'Panel de administrador',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AdminScreen()),
              ),
            ),
            const SizedBox(height: 8),
          ],

          // ── Modo práctica (antes "Repetir diagnóstico") ───────────────
          _MenuItem(
            icon: Icons.sports_esports_outlined,
            label: 'Modo práctica',
            onTap: () {
              // Abre el diagnóstico como práctica libre: no resetea nada
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const DiagnosticoScreen(isPractice: true),
                ),
              );
            },
          ),

          const SizedBox(height: 8),

          // ── Salir / Cerrar sesión ─────────────────────────────────────
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () async {
              if (isGuest) {
                // Invitado: terminar sesión local y volver a la bienvenida
                await LocalStorageService.endGuestSession();
                if (!context.mounted) return;
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                  (route) => false,
                );
              } else {
                await FirebaseAuth.instance.signOut();
                if (!context.mounted) return;
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.temaSumasSoft,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFFFCDD2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.logout, color: Color(0xFFB71C1C), size: 20),
                  const SizedBox(width: 12),
                  Text(
                    isGuest ? 'Salir del modo invitado' : 'Cerrar sesión',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFFB71C1C),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatMini extends StatelessWidget {
  final String valor;
  final String label;
  const _StatMini(this.valor, this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Text(
            valor,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFFE53935),
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.textSecondary, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(Icons.chevron_right, color: AppColors.textMuted, size: 20),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 🎯 SELECTOR DE DIFICULTAD (bottom sheet)
// ─────────────────────────────────────────────────────────────────────────────
class _DificultadSheet extends StatelessWidget {
  final String nombre;
  final Color color;
  final IconData icono;
  final void Function(NivelDificultad) onSelect;

  const _DificultadSheet({
    required this.nombre,
    required this.color,
    required this.icono,
    required this.onSelect,
  });

  static const _niveles = [
    (
      nivel: NivelDificultad.facil,
      label: 'Fácil',
      rango: 'Números 1 al 20 · a veces 3 números',
      icon: Icons.sentiment_satisfied_alt_rounded,
      color: AppColors.temaMult,
      fondo: AppColors.temaMultSoft,
    ),
    (
      nivel: NivelDificultad.normal,
      label: 'Normal',
      rango: 'Números 1 al 100 · 2-3 operandos',
      icon: Icons.sentiment_neutral_rounded,
      color: AppColors.temaDiv,
      fondo: AppColors.temaDivSoft,
    ),
    (
      nivel: NivelDificultad.dificil,
      label: 'Difícil',
      rango: 'Números grandes · 3 operandos',
      icon: Icons.sentiment_very_dissatisfied_rounded,
      color: Color(0xFFE53935),
      fondo: AppColors.temaSumasSoft,
    ),
    (
      nivel: NivelDificultad.experto,
      label: 'Experto',
      rango: 'Operaciones mixtas · muy difícil',
      icon: Icons.local_fire_department_rounded,
      color: Color(0xFF8E24AA),
      fondo: Color(0x1F8E24AA),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // Título
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icono, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nombre,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    'Elige la dificultad',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Tarjetas de dificultad (desplazable por si no caben)
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: _niveles.map(
            (n) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GestureDetector(
                onTap: () => onSelect(n.nivel),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: n.fondo,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(n.icon, color: n.color, size: 26),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              n.label,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: n.color,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              n.rango,
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 14,
                        color: AppColors.textMuted,
                      ),
                    ],
                  ),
                ),
              ),
            ),
                ).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
