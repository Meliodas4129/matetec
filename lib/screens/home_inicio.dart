import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_screen.dart';
import 'diagnostico_screen.dart';
import 'practica_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final _user = FirebaseAuth.instance.currentUser!;
  static const rojo = Color(0xFFE53935);

  Future<void> _reiniciarDiagnostico() async {
    final ref = FirebaseFirestore.instance.collection('users').doc(_user.uid);
    await ref.update({
      "aciertos": 0,
      "errores": 0,
      "intentos": 0,
      "tiempo_total": 0,
      "grado": "Pendiente",
      "grado_num": 0,
      "racha": 0,
      "puntos": 0,
      // 📚 Reset de progreso por tema
      "temas": {
        "sumas": {"aciertos": 0, "intentos": 0},
        "restas": {"aciertos": 0, "intentos": 0},
        "multiplicacion": {"aciertos": 0, "intentos": 0},
        "division": {"aciertos": 0, "intentos": 0},
      },
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFFFAFAFA),
        body: SafeArea(
          bottom: false,
          child: StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(_user.uid)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final data = snapshot.data!.data() as Map<String, dynamic>;

              final String nombre = data["nombre"] ?? "Usuario";
              final String grado = data["grado"] ?? "";
              final String email = data["email"] ?? "";
              final int gradoNum = data["grado_num"] ?? 1;
              final int aciertos = data["aciertos"] ?? 0;
              final int intentos = data["intentos"] ?? 1;
              final int racha = data["racha"] ?? 0;
              final int puntos = data["puntos"] ?? 0;
              final double progreso = intentos > 0 ? aciertos / intentos : 0.0;

              // 📚 Sub-mapa con progreso por tema (puede no existir en usuarios viejos)
              final Map<String, dynamic> temas =
                  (data["temas"] as Map<String, dynamic>?) ?? const {};

              final List<Widget> screens = [
                _Inicio(
                  nombre: nombre,
                  grado: grado,
                  gradoNum: gradoNum,
                  racha: racha,
                  puntos: puntos,
                ),
                _Progreso(
                  aciertos: aciertos,
                  intentos: intentos,
                  progreso: progreso,
                  temas: temas,
                ),
                const _Retos(),
                _Perfil(
                  nombre: nombre,
                  grado: grado,
                  email: email,
                  aciertos: aciertos,
                  racha: racha,
                  puntos: puntos,
                  onReiniciarDiagnostico: _reiniciarDiagnostico,
                ),
              ];

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

  const _Inicio({
    required this.nombre,
    required this.grado,
    required this.gradoNum,
    required this.racha,
    required this.puntos,
  });

  List<_Tema> get _temas => [
    _Tema(
      'Sumas',
      Icons.add,
      const Color(0xFFE53935),
      const Color(0xFFFFEBEE),
      'Practica sumando',
      true,
      TemaPractica.sumas,
    ),
    _Tema(
      'Restas',
      Icons.remove,
      const Color(0xFF1E88E5),
      const Color(0xFFE3F2FD),
      'Practica restando',
      gradoNum >= 2,
      TemaPractica.restas,
    ),
    _Tema(
      'Multiplicación',
      Icons.close,
      const Color(0xFF43A047),
      const Color(0xFFE8F5E9),
      'Tablas de multiplicar',
      gradoNum >= 3,
      TemaPractica.multiplicacion,
    ),
    _Tema(
      'División',
      Icons.more_horiz,
      const Color(0xFFFB8C00),
      const Color(0xFFFFF3E0),
      'Divisiones exactas',
      gradoNum >= 4,
      TemaPractica.division,
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
                '${_temas.where((t) => t.desbloqueado).length}/${_temas.length}',
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
            'Sube de nivel para desbloquear más',
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
              childAspectRatio: 1.05,
            ),
            itemCount: _temas.length,
            itemBuilder: (_, i) =>
                _TemaCard(tema: _temas[i], gradoNum: gradoNum),
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

class _Tema {
  final String nombre;
  final IconData icono;
  final Color color;
  final Color fondo;
  final String subtitulo;
  final bool desbloqueado;
  final TemaPractica temaPractica;
  const _Tema(
    this.nombre,
    this.icono,
    this.color,
    this.fondo,
    this.subtitulo,
    this.desbloqueado,
    this.temaPractica,
  );
}

class _TemaCard extends StatelessWidget {
  final _Tema tema;
  final int gradoNum;
  const _TemaCard({required this.tema, required this.gradoNum});

  void _abrirPractica(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            PracticaScreen(tema: tema.temaPractica, gradoNum: gradoNum),
      ),
    );
  }

  void _mostrarBloqueado(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Sigue practicando para desbloquear ${tema.nombre}'),
        backgroundColor: Colors.grey.shade800,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final desbloqueado = tema.desbloqueado;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: desbloqueado
            ? () => _abrirPractica(context)
            : () => _mostrarBloqueado(context),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: desbloqueado ? tema.fondo : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      desbloqueado ? tema.icono : Icons.lock_outline,
                      color: desbloqueado ? tema.color : Colors.grey.shade400,
                      size: 22,
                    ),
                  ),
                  if (desbloqueado)
                    Icon(
                      Icons.arrow_forward_rounded,
                      color: Colors.grey.shade400,
                      size: 18,
                    ),
                ],
              ),
              const Spacer(),
              Text(
                tema.nombre,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: desbloqueado
                      ? const Color(0xFF1A1A1A)
                      : Colors.grey.shade500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desbloqueado ? tema.subtitulo : 'Sube de nivel',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
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
// 🧩 RETOS
// ─────────────────────────────────────────────────────────────────────────────
class _Retos extends StatelessWidget {
  const _Retos();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Retos del día',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          _RetoCard(
            titulo: 'Velocidad mental',
            subtitulo: '20 sumas en 60 segundos',
            icono: Icons.bolt,
            iconColor: const Color(0xFFE53935),
            fondoIcon: const Color(0xFFFFEBEE),
            puntos: '+50 pts',
            bloqueado: false,
          ),
          const SizedBox(height: 10),
          _RetoCard(
            titulo: 'Reto semanal',
            subtitulo: '100 ejercicios sin fallo',
            icono: Icons.star_outline,
            iconColor: const Color(0xFF43A047),
            fondoIcon: const Color(0xFFE8F5E9),
            puntos: '+200 pts',
            bloqueado: false,
          ),
          const SizedBox(height: 10),
          _RetoCard(
            titulo: 'División avanzada',
            subtitulo: 'Completa divisiones primero',
            icono: Icons.lock_outline,
            iconColor: Colors.grey,
            fondoIcon: Colors.grey.shade100,
            puntos: 'Bloqueado',
            bloqueado: true,
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: const [
                Icon(Icons.star, color: Color(0xFFF59E0B), size: 24),
                SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Puntos acumulados',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '340 pts esta semana',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
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

class _RetoCard extends StatelessWidget {
  final String titulo;
  final String subtitulo;
  final IconData icono;
  final Color iconColor;
  final Color fondoIcon;
  final String puntos;
  final bool bloqueado;

  const _RetoCard({
    required this.titulo,
    required this.subtitulo,
    required this.icono,
    required this.iconColor,
    required this.fondoIcon,
    required this.puntos,
    required this.bloqueado,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: bloqueado ? 0.5 : 1.0,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: fondoIcon,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icono, color: iconColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    subtitulo,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: bloqueado
                    ? Colors.grey.shade100
                    : const Color(0xFFFFEBEE),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                puntos,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: bloqueado ? Colors.grey : const Color(0xFFB71C1C),
                ),
              ),
            ),
          ],
        ),
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
  final Future<void> Function() onReiniciarDiagnostico;

  const _Perfil({
    required this.nombre,
    required this.grado,
    required this.email,
    required this.aciertos,
    required this.racha,
    required this.puntos,
    required this.onReiniciarDiagnostico,
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
            onTap: () {},
          ),
          const SizedBox(height: 8),
          _MenuItem(
            icon: Icons.settings_outlined,
            label: 'Configuración',
            onTap: () {},
          ),
          const SizedBox(height: 8),

          // ── Repetir diagnóstico ✅ CORREGIDO ──────────────────────────
          _MenuItem(
            icon: Icons.refresh_outlined,
            label: 'Repetir diagnóstico',
            onTap: () async {
              final confirmar = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  title: const Text(
                    '¿Repetir diagnóstico?',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  content: const Text(
                    'Esto reiniciará tu nivel y todas tus estadísticas. '
                    'Tu progreso actual se perderá. ¿Deseas continuar?',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text(
                        'Cancelar',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFFE53935),
                      ),
                      child: const Text(
                        'Reiniciar',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              );

              if (confirmar == true) {
                await onReiniciarDiagnostico(); // 1. Resetear Firestore
                if (!context.mounted) return;

                Navigator.pushReplacement(
                  // 2. Ir al diagnóstico ✅
                  context,
                  MaterialPageRoute(builder: (_) => const DiagnosticoScreen()),
                );
              }
            },
          ),

          const SizedBox(height: 8),

          // ── Cerrar sesión ─────────────────────────────────────────────
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () async {
              await FirebaseAuth.instance.signOut();
              if (!context.mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEBEE),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFFFCDD2)),
              ),
              child: Row(
                children: const [
                  Icon(Icons.logout, color: Color(0xFFB71C1C), size: 20),
                  SizedBox(width: 12),
                  Text(
                    'Cerrar sesión',
                    style: TextStyle(
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
