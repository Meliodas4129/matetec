// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'screens/welcome_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/diagnostico_screen.dart';
import 'screens/home_inicio.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MateTec',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      routes: {
        '/welcome': (_) => const WelcomeScreen(),
        '/login': (_) => const LoginScreen(),
        '/register': (_) => const RegisterScreen(),
        '/home': (_) => const HomeScreen(),
        '/diagnostico': (_) => const DiagnosticoScreen(),
      },
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  // Pantalla de carga reutilizable mientras se verifica algo
  static Widget _loading() => const Scaffold(
    backgroundColor: Color(0xFFE53935),
    body: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'MateTec',
            style: TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
          SizedBox(height: 24),
          CircularProgressIndicator(color: Colors.white),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Firebase verificando sesión → pantalla de carga
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _loading();
        }

        final user = snapshot.data;

        // ✅ Sin sesión → bienvenida con Registrarse / Iniciar Sesión
        if (user == null) {
          return const WelcomeScreen();
        }

        // ✅ Con sesión → revisar si ya hizo el diagnóstico inicial
        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get(),
          builder: (context, docSnap) {
            if (docSnap.connectionState == ConnectionState.waiting) {
              return _loading();
            }

            // Si el doc no existe, manda al diagnóstico (caso raro)
            if (!docSnap.hasData || !docSnap.data!.exists) {
              return const DiagnosticoScreen();
            }

            final data = docSnap.data!.data() as Map<String, dynamic>?;
            final grado = (data?['grado'] ?? 'Pendiente') as String;

            // Si todavía no hizo el diagnóstico → diagnóstico
            if (grado == 'Pendiente' || grado.isEmpty) {
              return const DiagnosticoScreen();
            }

            // Todo listo → Home con tabs
            return const HomeScreen();
          },
        );
      },
    );
  }
}
