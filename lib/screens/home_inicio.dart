import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  String nombre = '';
  String grado = '';
  String email = '';
  bool _cargando = true;

  static const rojo = Color(0xFFE53935);

  @override
  void initState() {
    super.initState();
    _cargarUsuario();
  }

  Future<void> _cargarUsuario() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    if (doc.exists && mounted) {
      setState(() {
        nombre = doc['nombre'] ?? 'Usuario';
        grado = doc['grado'] ?? '';
        email = doc['email'] ?? '';
        _cargando = false;
      });
    }
  }

  List<Widget> get _screens => [
    _Inicio(nombre: nombre, grado: grado, cargando: _cargando),
    const _Progreso(),
    const _Retos(),
    _Perfil(nombre: nombre, grado: grado, email: email),
  ];

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
        body: IndexedStack(index: _currentIndex, children: _screens),
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

// ─────────────────────────────────────────
// 🏠 INICIO
// ─────────────────────────────────────────
class _Inicio extends StatelessWidget {
  final String nombre;
  final String grado;
  final bool cargando;

  const _Inicio({
    required this.nombre,
    required this.grado,
    required this.cargando,
  });

  static const _temas = [
    _Tema(
      'Sumas',
      Icons.add,
      Color(0xFFE53935),
      Color(0xFFFFEBEE),
      '12 lecciones',
    ),
    _Tema(
      'Restas',
      Icons.remove,
      Color(0xFF1E88E5),
      Color(0xFFE3F2FD),
      '10 lecciones',
    ),
    _Tema(
      'Multiplicación',
      Icons.close,
      Color(0xFF43A047),
      Color(0xFFE8F5E9),
      '15 lecciones',
    ),
    _Tema(
      'División',
      Icons.more_horiz,
      Color(0xFFFB8C00),
      Color(0xFFFFF3E0),
      '11 lecciones',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Saludo ──────────────────────────────
          Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: const Color(0xFFFFCDD2),
                child: Text(
                  cargando ? '?' : nombre.substring(0, 1).toUpperCase(),
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
                    cargando ? 'Cargando...' : 'Hola, $nombre',
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

          // ── Racha ────────────────────────────────
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
                  children: const [
                    Text(
                      'Racha actual',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    Text(
                      '7 días seguidos',
                      style: TextStyle(
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

          // ── Grid de temas ────────────────────────
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
            itemBuilder: (_, i) => _TemaCard(tema: _temas[i]),
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
  const _Tema(this.nombre, this.icono, this.color, this.fondo, this.subtitulo);
}

class _TemaCard extends StatelessWidget {
  final _Tema tema;
  const _TemaCard({required this.tema});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {},
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: tema.fondo,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(tema.icono, color: tema.color, size: 28),
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
              tema.subtitulo,
              style: TextStyle(
                fontSize: 11,
                color: tema.color.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
// 📊 PROGRESO
// ─────────────────────────────────────────
class _Progreso extends StatelessWidget {
  const _Progreso();

  static const _datos = [
    _ProgDato('Sumas', 0.80, Color(0xFFE53935)),
    _ProgDato('Restas', 0.65, Color(0xFF1E88E5)),
    _ProgDato('Multiplicación', 0.45, Color(0xFF43A047)),
    _ProgDato('División', 0.20, Color(0xFFFB8C00)),
  ];

  @override
  Widget build(BuildContext context) {
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

          // Métricas rápidas
          Row(
            children: [
              Expanded(child: _MetricCard('Ejercicios', '84')),
              const SizedBox(width: 12),
              Expanded(child: _MetricCard('Precisión', '91%')),
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

          // Barras de progreso
          ..._datos.map(
            (d) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ProgresoCard(dato: d),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgDato {
  final String nombre;
  final double valor;
  final Color color;
  const _ProgDato(this.nombre, this.valor, this.color);
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
  final _ProgDato dato;
  const _ProgresoCard({required this.dato});

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
              Text(
                dato.nombre,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                '${(dato.valor * 100).toInt()}%',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: dato.color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: dato.valor,
              minHeight: 7,
              backgroundColor: Colors.grey.shade100,
              valueColor: AlwaysStoppedAnimation(dato.color),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
// 🧩 RETOS
// ─────────────────────────────────────────
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

          // Banner de puntos
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                const Icon(Icons.star, color: Color(0xFFF59E0B), size: 24),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
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

// ─────────────────────────────────────────
// 👤 PERFIL
// ─────────────────────────────────────────
class _Perfil extends StatelessWidget {
  final String nombre;
  final String grado;
  final String email;

  const _Perfil({
    required this.nombre,
    required this.grado,
    required this.email,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Tarjeta de usuario
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

          // Estadísticas
          Row(
            children: [
              Expanded(child: _StatMini('84', 'Ejercicios')),
              const SizedBox(width: 8),
              Expanded(child: _StatMini('7', 'Racha')),
              const SizedBox(width: 8),
              Expanded(child: _StatMini('340', 'Puntos')),
            ],
          ),

          const SizedBox(height: 20),

          // Opciones
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

          // Cerrar sesión
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
