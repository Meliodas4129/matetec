// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'firebase_options.dart';
import 'services/local_storage_service.dart';
import 'services/sync_service.dart';
import 'services/theme_service.dart';
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
    persistenceEnabled: true, // caché local cuando no hay internet
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  // ── Inicializar almacenamiento local (modo invitado) ──────────────────────
  await LocalStorageService.init();

  // ── Inicializar servicio de sincronización / conectividad ─────────────────
  await SyncService.init();

  // ── Inicializar preferencia de color de tema ──────────────────────────────
  await ThemeService.init();

  // Manejar resultado de signInWithRedirect (fallback web cuando popup es bloqueado)
  try {
    final result = await FirebaseAuth.instance.getRedirectResult();
    if (result.user != null) {
      final user = result.user!;
      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid);
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
              'aciertos': 0,
              'intentos': 0,
              'eval_desde_intentos': 10,
              'eval_aprobada': false,
            },
            'restas': {
              'aciertos': 0,
              'intentos': 0,
              'eval_desde_intentos': 10,
              'eval_aprobada': false,
            },
            'multiplicacion': {
              'aciertos': 0,
              'intentos': 0,
              'eval_desde_intentos': 10,
              'eval_aprobada': false,
            },
            'division': {
              'aciertos': 0,
              'intentos': 0,
              'eval_desde_intentos': 10,
              'eval_aprobada': false,
            },
          },
          'temas_desbloqueados': ['sumas'],
          'racha': 0,
          'puntos': 0,
          'rol': (user.email ?? '').toLowerCase().endsWith('@matetec.com')
              ? 'admin'
              : 'estudiante',
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
    return ValueListenableBuilder<int>(
      valueListenable: ThemeService.colorIndexNotifier,
      builder: (context, _, __) {
        return MaterialApp(
          title: 'MateTec',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.forColor(ThemeService.primaryColor),
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
      },
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

        // ✅ Correo no verificado → pedir verificación
        // Excepción: admins @matetec.com no necesitan verificar
        final esAdminDomain = (user.email ?? '').toLowerCase().endsWith(
          '@matetec.com',
        );
        if (!user.emailVerified && !esAdminDomain) {
          return VerifyEmailScreen(email: user.email ?? '');
        }

        // ✅ Con sesión → revisar diagnóstico y estado de cuenta
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

            // ✅ Cuenta bloqueada → mostrar pantalla de suspensión
            if ((data?['bloqueado'] ?? false) as bool) {
              FirebaseAuth.instance.signOut();
              return const _CuentaBloqueadaScreen();
            }

            final grado = (data?['grado'] ?? 'Pendiente') as String;
            final rol = (data?['rol'] ?? 'estudiante') as String;

            // Los admins no necesitan diagnóstico → van directo al home
            // Si todavía no hizo el diagnóstico → diagnóstico
            if (rol != 'admin' && (grado == 'Pendiente' || grado.isEmpty)) {
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

// ── Pantalla de cuenta suspendida ─────────────────────────────────────────────
class _CuentaBloqueadaScreen extends StatelessWidget {
  const _CuentaBloqueadaScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.block_rounded,
                  size: 52,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Cuenta suspendida',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Tu cuenta ha sido suspendida temporalmente por el administrador.\n\n'
                'Si crees que es un error, contacta a tu profesor o al administrador del sistema.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 36),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await FirebaseAuth.instance.signOut();
                  },
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Cerrar sesión'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey.shade700,
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
