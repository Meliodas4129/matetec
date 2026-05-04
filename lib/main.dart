// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'firebase_options.dart';
import 'screens/welcome_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/diagnostico_screen.dart';

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
      routes: {
        '/welcome': (_) => const WelcomeScreen(),
        '/login': (_) => const LoginScreen(),
        '/register': (_) => const RegisterScreen(),
        '/home': (_) => const WelcomeScreen(),
        '/diagnostico': (_) => const DiagnosticoScreen(),
      },
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Firebase verificando sesión → pantalla de carga
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
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
        }

        // ✅ Sesión activa → pantalla principal con tabs
        if (snapshot.hasData && snapshot.data != null) {
          return const WelcomeScreen();
        }

        // ✅ Sin sesión → pantalla de bienvenida con Registrarse/Iniciar Sesión
        return const WelcomeScreen();
      },
    );
  }
}
