import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/local_storage_service.dart';
import '../services/theme_service.dart';
import '../widgets/sync_indicator.dart';
import 'admin_screen.dart';
import 'login_screen.dart';
import 'welcome_screen.dart';
import 'diagnostico_screen.dart';
import 'practica_screen.dart';
import 'evaluacion_final_screen.dart';
import 'configuracion_screen.dart';
import 'practica_screen.dart' show NivelDificultad;
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
  List<Widget> _buildScreens(Map<String, dynamic> data, {bool isGuest = false}) {
    final String nombre   = data["nombre"]       ?? (data["email"]?.toString().isNotEmpty == true ? data["email"].toString().split('@')[0] : 'Usuario');
    final String grado    = data["grado"]        ?? "";
    final String email    = data["email"]        ?? "";
    final String rol      = data["rol"]          ?? "estudiante";
    final String ciudad   = data["ciudad"]       ?? "";
    final String fotoUrl  = data["fotoUrl"]      ?? "";
    final int    gradoNum = data["grado_num"]    ?? 1;
    final int    aciertos = data["aciertos"]     ?? 0;
    final int    intentos = data["intentos"]     ?? 1;
    final int    racha    = data["racha"]        ?? 0;
    final int    puntos   = data["puntos"]       ?? 0;
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
        temasDesbloqueados: temasDesbloqueados,
        temas: temas,
      ),
      _Progreso(aciertos: aciertos, intentos: intentos, progreso: progreso, temas: temas),
      _Retos(retos: retosDiarios, puntos: puntos),
      _Perfil(
        nombre: nombre,
        grado: grado,
        email: email,
        aciertos: aciertos,
        racha: racha,
        puntos: puntos,
        ciudad: ciudad,
        fotoUrl: fotoUrl,
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
        backgroundColor: const Color(0xFFFAFAFA),
        body: SafeArea(
          bottom: false,
          child: isGuest
              // ── Modo invitado: datos desde ValueNotifier local ──────────
              ? ValueListenableBuilder<Map<String, dynamic>>(
                  valueListenable: LocalStorageService.guestDataNotifier,
                  builder: (context, data, _) {
                    final screens = _buildScreens(data, isGuest: true);
                    return IndexedStack(index: _currentIndex, children: screens);
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
                    return IndexedStack(index: _currentIndex, children: screens);
                  },
                ),
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: Colors.white,
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
              backgroundColor: Colors.white,
              selectedItemColor: rojo,
              unselectedItemColor: Colors.grey.shade400,
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
  final List<String> temasDesbloqueados;
  final Map<String, dynamic> temas;

  const _Inicio({
    required this.nombre,
    required this.grado,
    required this.gradoNum,
    required this.racha,
    required this.puntos,
    required this.temasDesbloqueados,
    required this.temas,
  });

  // Orden fijo: sumas desbloquea restas, restas → mult, mult → div
  static const _temasConfig = [
    (
      nombre: 'Sumas',
      icono: Icons.add,
      color: Color(0xFFE53935),
      fondo: Color(0xFFFFEBEE),
      subtitulo: 'Practica sumando',
      clave: 'sumas',
      siguiente: 'restas',
      tema: TemaPractica.sumas,
    ),
    (
      nombre: 'Restas',
      icono: Icons.remove,
      color: Color(0xFF1E88E5),
      fondo: Color(0xFFE3F2FD),
      subtitulo: 'Practica restando',
      clave: 'restas',
      siguiente: 'multiplicacion',
      tema: TemaPractica.restas,
    ),
    (
      nombre: 'Multiplicación',
      icono: Icons.close,
      color: Color(0xFF43A047),
      fondo: Color(0xFFE8F5E9),
      subtitulo: 'Tablas de multiplicar',
      clave: 'multiplicacion',
      siguiente: 'division',
      tema: TemaPractica.multiplicacion,
    ),
    (
      nombre: 'División',
      icono: Icons.more_horiz,
      color: Color(0xFFFB8C00),
      fondo: Color(0xFFFFF3E0),
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
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      nombre,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A1A1A),
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
                backgroundColor: const Color(0xFFE53935),
                child: Text(
                  nombre.isNotEmpty
                      ? nombre.substring(0, 1).toUpperCase()
                      : '?',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
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
                  iconColor: const Color(0xFFFB8C00),
                  iconBg: const Color(0xFFFFF3E0),
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
                  iconBg: const Color(0xFFFFF8E1),
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
                  color: Color(0xFF1A1A1A),
                ),
              ),
              Text(
                '${temasDesbloqueados.length}/${_temasConfig.length}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Aprueba la evaluación de cada tema para avanzar',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              childAspectRatio: 0.88,
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
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
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      valor,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A1A1A),
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
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TemaCard extends StatelessWidget {
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

  // Datos de progreso hacia la evaluación
  int get _intentos => (temaData['intentos'] ?? 0) as int;
  int get _evalDesde => (temaData['eval_desde_intentos'] ?? 10) as int;
  bool get _evalAprobada => (temaData['eval_aprobada'] ?? false) as bool;
  bool get _puedeEvaluar => desbloqueado && !_evalAprobada && _intentos >= _evalDesde;
  int get _practicasParaEval => (_evalDesde - _intentos).clamp(0, _evalDesde);

  void _abrirPractica(BuildContext context) {
    // Mostrar diálogo para seleccionar dificultad
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Selecciona Dificultad'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Elige el nivel que deseas practicar:',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
          ],
        ),
        actions: [
          // Botón Fácil
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PracticaScreen(
                    tema: temaPractica,
                    gradoNum: gradoNum,
                    nivelDificultad: NivelDificultad.facil,
                  ),
                ),
              );
            },
            child: const Text('🟢 Fácil\n(1-10)'),
          ),
          // Botón Normal
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PracticaScreen(
                    tema: temaPractica,
                    gradoNum: gradoNum,
                    nivelDificultad: NivelDificultad.normal,
                  ),
                ),
              );
            },
            child: const Text('🟡 Normal\n(1-100)'),
          ),
          // Botón Difícil
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PracticaScreen(
                    tema: temaPractica,
                    gradoNum: gradoNum,
                    nivelDificultad: NivelDificultad.dificil,
                  ),
                ),
              );
            },
            child: const Text('🔴 Difícil\n(1-1000)'),
          ),
        ],
      ),
    );
  }

  void _abrirEvaluacion(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EvaluacionFinalScreen(
          tema: clave,
          gradoNum: gradoNum,
          siguienteTema: siguienteTema,
          intentosActuales: _intentos,
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
    final prereq = prereqs[clave] ?? '';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(prereq.isNotEmpty
            ? 'Aprueba la evaluación de $prereq para desbloquear $nombre'
            : 'Completa los temas anteriores primero'),
        backgroundColor: Colors.grey.shade800,
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
        onTap: desbloqueado
            ? () => _abrirPractica(context)
            : () => _mostrarBloqueado(context),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _puedeEvaluar
                  ? color.withValues(alpha: 0.5)
                  : Colors.grey.shade200,
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
                      color: desbloqueado ? fondo : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(
                      desbloqueado ? icono : Icons.lock_outline,
                      color: desbloqueado ? color : Colors.grey.shade400,
                      size: 21,
                    ),
                  ),
                  if (_evalAprobada)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.check_circle_rounded,
                          color: Colors.green, size: 15),
                    )
                  else if (_puedeEvaluar)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.emoji_events_rounded,
                          color: Colors.amber, size: 15),
                    ),
                ],
              ),

              const SizedBox(height: 10),

              // Nombre del tema
              Text(
                nombre,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: desbloqueado
                      ? const Color(0xFF1A1A1A)
                      : Colors.grey.shade500,
                ),
              ),
              const SizedBox(height: 2),

              // Subtítulo / estado
              if (!desbloqueado)
                Text(
                  'Bloquado',
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade400),
                )
              else if (_evalAprobada)
                Text(
                  '✓ Evaluación aprobada',
                  style: TextStyle(
                      fontSize: 10,
                      color: Colors.green.shade600,
                      fontWeight: FontWeight.w500),
                )
              else if (_puedeEvaluar)
                Text(
                  '¡Listo para evaluar!',
                  style: TextStyle(
                      fontSize: 10,
                      color: color,
                      fontWeight: FontWeight.w600),
                )
              else
                Text(
                  subtitulo,
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                ),

              const Spacer(),

              // Barra de progreso hacia evaluación o botón ¡Evaluarme!
              if (desbloqueado && !_evalAprobada) ...[
                if (_puedeEvaluar) ...[
                  // Botón de evaluación
                  SizedBox(
                    width: double.infinity,
                    height: 30,
                    child: ElevatedButton(
                      onPressed: () => _abrirEvaluacion(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: color,
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
                            fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ] else ...[
                  // Barra de progreso
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: _evalDesde > 0
                          ? (_intentos / _evalDesde).clamp(0.0, 1.0)
                          : 0.0,
                      minHeight: 5,
                      backgroundColor: Colors.grey.shade100,
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$_practicasParaEval más para evaluación',
                    style: TextStyle(
                        fontSize: 9, color: Colors.grey.shade500),
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
    Color(0xFF1E88E5),
    Color(0xFF43A047),
    Color(0xFFFB8C00),
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
      final int a = (t['aciertos'] ?? 0) as int;
      final int i = (t['intentos'] ?? 0) as int;
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
              color: Color(0xFF1A1A1A),
              height: 1.1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            intentosReales > 0
                ? 'Llevas $intentosReales ejercicios resueltos'
                : 'Empieza a practicar para ver tu progreso',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 26),

          // ── Anillo de precisión + stats laterales ──────────────────────
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.shade200),
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
                        color: const Color(0xFF43A047),
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
                        color: const Color(0xFF1E88E5),
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
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tu rendimiento en cada tipo de operación',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
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
              backgroundColor: Colors.grey.shade100,
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
                      ? const Color(0xFF1A1A1A)
                      : Colors.grey.shade400,
                ),
              ),
              Text(
                'Precisión',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey.shade500,
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
    if (!hayDatos) return Colors.grey.shade300;
    if (v >= 0.8) return const Color(0xFF43A047);
    if (v >= 0.5) return const Color(0xFF1E88E5);
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
            style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
          ),
        ),
        Text(
          valor,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A1A1A),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: hayDatos
                  ? color.withValues(alpha: 0.12)
                  : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icono,
              color: hayDatos ? color : Colors.grey.shade400,
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
                        color: Color(0xFF1A1A1A),
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
                      backgroundColor: Colors.grey.shade100,
                      valueColor: AlwaysStoppedAnimation(color),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$intentos ${intentos == 1 ? "ejercicio" : "ejercicios"}',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),
                ] else
                  Text(
                    'Aún no has practicado',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade400,
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
  final int meta;          // valor objetivo
  final String unidad;     // label de la barra de progreso

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
    color: Color(0xFF1E88E5),
    puntos: 40,
    meta: 80,
    unidad: '% precisión',
  ),
  _DefReto(
    id: 'constancia',
    titulo: 'Constancia del día',
    descripcion: '25 ejercicios en total hoy',
    icono: Icons.fitness_center_rounded,
    color: Color(0xFF43A047),
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
                        fontSize: 22, fontWeight: FontWeight.w700,
                        color: Color(0xFF1A1A1A)),
                  ),
                  Text(
                    'Se reinician cada medianoche',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$_retosCompletados/${_retosDefinidos.length} completados',
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600, color: primary),
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
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8E1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.star_rounded,
                      color: Color(0xFFFFA000), size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Puntos por retos hoy',
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w500)),
                      Text(
                        '$puntos puntos totales acumulados',
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                ),
                Text(
                  '+$_puntosRetos pts',
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFFFA000)),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: completado
              ? def.color.withValues(alpha: 0.4)
              : Colors.grey.shade200,
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
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  completado ? Icons.check_circle_rounded : def.icono,
                  color: completado ? def.color : Colors.grey.shade500,
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
                          fontSize: 14, fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1A1A)),
                    ),
                    Text(
                      def.descripcion,
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: completado
                      ? def.color.withValues(alpha: 0.1)
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  completado ? '✓ +${def.puntos}' : '+${def.puntos} pts',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: completado ? def.color : Colors.grey.shade600),
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
              backgroundColor: Colors.grey.shade100,
              valueColor: AlwaysStoppedAnimation<Color>(
                  completado ? def.color : def.color.withValues(alpha: 0.5)),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            completado
                ? '¡Completado!'
                : '$progreso / ${def.meta} ${def.unidad}',
            style: TextStyle(
                fontSize: 10,
                color: completado ? def.color : Colors.grey.shade500,
                fontWeight:
                    completado ? FontWeight.w600 : FontWeight.normal),
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
  final String fotoUrl;
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
    this.fotoUrl = "",
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
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: const Color(0xFFFFCDD2),
                  child: Text(
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
                    fotoUrl: fotoUrl,
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

          // ── Selector de color del tema ────────────────────────────────
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.palette_outlined,
                        color: Colors.grey.shade600, size: 20),
                    const SizedBox(width: 12),
                    const Text(
                      'Color del tema',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ValueListenableBuilder<int>(
                  valueListenable: ThemeService.colorIndexNotifier,
                  builder: (context, idx, _) {
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: List.generate(
                        ThemeService.presets.length,
                        (i) {
                          final seleccionado = i == idx;
                          return GestureDetector(
                            onTap: () => ThemeService.setColorIndex(i),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: ThemeService.presets[i],
                                shape: BoxShape.circle,
                                border: seleccionado
                                    ? Border.all(
                                        color: Colors.white, width: 2.5)
                                    : null,
                                boxShadow: seleccionado
                                    ? [
                                        BoxShadow(
                                          color: ThemeService.presets[i]
                                              .withValues(alpha: 0.5),
                                          blurRadius: 8,
                                          spreadRadius: 1,
                                        )
                                      ]
                                    : null,
                              ),
                              child: seleccionado
                                  ? const Icon(Icons.check,
                                      color: Colors.white, size: 18)
                                  : null,
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ],
            ),
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
                color: const Color(0xFFFFEBEE),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
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
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.grey.shade600, size: 20),
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
            Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 20),
          ],
        ),
      ),
    );
  }
}
