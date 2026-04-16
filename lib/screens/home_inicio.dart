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

  String nombre = "Cargando...";
  String grado = "";

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

    if (doc.exists) {
      setState(() {
        nombre = doc['nombre'] ?? "Usuario";
        grado = doc['grado'] ?? "";
      });
    }
  }

  List<Widget> get _screens => [_inicio(), _progreso(), _retos(), _perfil()];

  @override
  Widget build(BuildContext context) {
    const rojo = Color(0xFFE53935);

    return WillPopScope(
      onWillPop: () async => false, // 🔥 bloquea botón atrás
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: rojo,
          title: const Text('MateTec'),
          automaticallyImplyLeading: false, // 🔥 quita flecha
        ),

        body: _screens[_currentIndex],

        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentIndex,
          selectedItemColor: rojo,
          unselectedItemColor: Colors.grey,
          onTap: (index) {
            setState(() => _currentIndex = index);
          },
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.calculate),
              label: 'Matemáticas',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.bar_chart),
              label: 'Progreso',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.extension),
              label: 'Retos',
            ),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Perfil'),
          ],
        ),
      ),
    );
  }

  // 🏠 INICIO
  Widget _inicio() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hola, $nombre 👋',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          Text(grado),

          const SizedBox(height: 30),

          const Text('Selecciona un tema:', style: TextStyle(fontSize: 18)),

          const SizedBox(height: 15),

          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 15,
              mainAxisSpacing: 15,
              children: [
                _card('Sumas', Colors.red),
                _card('Restas', Colors.blue),
                _card('Multiplicación', Colors.green),
                _card('División', Colors.orange),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 📊 PROGRESO
  Widget _progreso() {
    return const Center(
      child: Text('Aquí verás tu progreso 📊', style: TextStyle(fontSize: 18)),
    );
  }

  // 🧩 RETOS
  Widget _retos() {
    return const Center(
      child: Text('Retos disponibles 🧩', style: TextStyle(fontSize: 18)),
    );
  }

  // 👤 PERFIL
  Widget _perfil() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Nombre: $nombre'),
          Text('Grado: $grado'),

          const SizedBox(height: 20),

          ElevatedButton(
            onPressed: () async {
              await FirebaseAuth.instance.signOut();

              if (!mounted) return;

              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
  }

  // 🎯 TARJETAS
  Widget _card(String title, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Center(
        child: Text(title, style: const TextStyle(color: Colors.white)),
      ),
    );
  }
}
