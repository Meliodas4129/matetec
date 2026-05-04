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
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        appBar: AppBar(
          backgroundColor: rojo,
          elevation: 0,
          automaticallyImplyLeading: false,
          title: const Text(
            'MateTec',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(
                Icons.notifications_outlined,
                color: Colors.white,
              ),
              onPressed: () {},
            ),
          ],
        ),
        body: StreamBuilder<DocumentSnapshot>(
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
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentIndex,
          selectedItemColor: rojo,
          unselectedItemColor: Colors.grey.shade500,
          selectedLabelStyle: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: const TextStyle(fontSize: 11),
          type: BottomNavigationBarType.fixed,
          elevation: 8,
          onTap: (i) => setState(() => _currentIndex = i),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.calculate_outlined),
              activeIcon: Icon(Icons.calculate),
              label: 'Matemáticas',
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

  const _Inicio({
    required this.nombre,
    required this.grado,
    required this.gradoNum,
    required this.racha,
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

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: const Color(0xFFFFCDD2),
                child: Text(
                  nombre.isNotEmpty
                      ? nombre.substring(0, 1).toUpperCase()
                      : '?',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFB71C1C),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hola, $nombre',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (grado.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
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
              ),
            ],
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
              children: [
                const Icon(
                  Icons.local_fire_department,
                  color: Color(0xFFE53935),
                  size: 28,
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Racha actual',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    Text(
                      '$racha ${racha == 1 ? 'día' : 'días'} seguidos',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Selecciona un tema',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.1,
            ),
            itemCount: _temas.length,
            itemBuilder: (_, i) =>
                _TemaCard(tema: _temas[i], gradoNum: gradoNum),
          ),
          const SizedBox(height: 20),
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
        builder: (_) => PracticaScreen(
          tema: tema.temaPractica,
          gradoNum: gradoNum,
        ),
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
    return Opacity(
      opacity: tema.desbloqueado ? 1.0 : 0.45,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: tema.desbloqueado
            ? () => _abrirPractica(context)
            : () => _mostrarBloqueado(context),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: tema.fondo,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                tema.desbloqueado ? tema.icono : Icons.lock_outline,
                color: tema.color,
                size: 28,
              ),
              const Spacer(),
              Text(
                tema.nombre,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: tema.color.withOpacity(0.85),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                tema.desbloqueado ? tema.subtitulo : 'Bloqueado',
                style: TextStyle(
                  fontSize: 11,
                  color: tema.color.withOpacity(0.7),
                ),
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

  /// Devuelve (precision 0..1, intentos) de un tema
  ({double valor, int intentos}) _statsTema(String clave) {
    final t = temas[clave];
    if (t is Map) {
      final int a = (t['aciertos'] ?? 0) as int;
      final int i = (t['intentos'] ?? 0) as int;
      final double v = i > 0 ? a / i : 0.0;
      return (valor: v.clamp(0.0, 1.0), intentos: i);
    }
    return (valor: 0.0, intentos: 0);
  }

  @override
  Widget build(BuildContext context) {
    final precision = intentos > 0 ? '${(progreso * 100).toInt()}%' : '0%';
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Mi progreso',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _MetricCard('Ejercicios', '$intentos')),
              const SizedBox(width: 12),
              Expanded(child: _MetricCard('Precisión', precision)),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'Por tema',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 10),
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
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String valor;
  const _MetricCard(this.label, this.valor);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          const SizedBox(height: 4),
          Text(
            valor,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: Color(0xFFE53935),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgresoCard extends StatelessWidget {
  final String nombre;
  final double valor;
  final int intentos;
  final Color color;
  const _ProgresoCard({
    required this.nombre,
    required this.valor,
    required this.intentos,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    nombre,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    intentos > 0
                        ? '($intentos ${intentos == 1 ? "ejercicio" : "ejercicios"})'
                        : '(sin datos)',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
              Text(
                '${(valor * 100).toInt()}%',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: valor,
              minHeight: 7,
              backgroundColor: Colors.grey.shade100,
              valueColor: AlwaysStoppedAnimation(color),
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
