// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'firebase_options.dart';
import 'services/local_storage_service.dart';
import 'services/sync_service.dart';
import 'theme/app_theme.dart';
import 'screens/welcome_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/diagnostico_screen.dart';
import 'screens/verify_email_screen.dart';
import 'screens/home_inicio.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // ── Persistencia offline para usuarios con cuenta ─────────────────────────
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,   // caché local cuando no hay internet
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  // ── Inicializar almacenamiento local (modo invitado) ──────────────────────
  await LocalStorageService.init();

  // ── Inicializar servicio de sincronización / conectividad ─────────────────
  await SyncService.init();

  // Manejar resultado de signInWithRedirect (fallback web cuando popup es bloqueado)
  try {
    final result = await FirebaseAuth.instance.getRedirectResult();
    if (result.user != null) {
      final user = result.user!;
      final docRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
      final doc = await docRef.get();
      if (!doc.exists) {
        await docRef.set({
          'nombre': user.displayName ?? 'Usuario',
          'email': user.email ?? '',
          'grado': 'Pendiente',
          'grado_num': 0,
          'aciertos': 0,
          'errores': 0,
          'intentos': 0,
          'tiempo_total': 0,
          'temas': {
            'sumas': {
              'aciertos': 0, 'intentos': 0,
              'eval_desde_intentos': 10, 'eval_aprobada': false,
            },
            'restas': {
              'aciertos': 0, 'intentos': 0,
              'eval_desde_intentos': 10, 'eval_aprobada': false,
            },
            'multiplicacion': {
              'aciertos': 0, 'intentos': 0,
              'eval_desde_intentos': 10, 'eval_aprobada': false,
            },
            'division': {
              'aciertos': 0, 'intentos': 0,
              'eval_desde_intentos': 10, 'eval_aprobada': false,
            },
          },
          'temas_desbloqueados': ['sumas'],
          'racha': 0,
          'puntos': 0,
          'rol': 'estudiante',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    }
  } catch (_) {
    // getRedirectResult solo aplica en web; en móvil/desktop se ignora
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MateTec',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      themeMode: ThemeMode.light,
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

        // ✅ Sin sesión pero con sesión de invitado activa → HomeScreen con datos locales
        if (user == null && LocalStorageService.isGuest) {
          return const HomeScreen();
        }

        // ✅ Sin sesión → bienvenida con Registrarse / Iniciar Sesión
        if (user == null) {
          return const WelcomeScreen();
        }

        // ✅ Correo no verificado → pedir verificación (sesión activa para polling)
        if (!user.emailVerified) {
          return VerifyEmailScreen(email: user.email ?? '');
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
