// lib/screens/login_screen.dart
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../theme/app_theme.dart';
import '../services/local_storage_service.dart';
import 'home_inicio.dart';
import 'register_screen.dart';
import 'diagnostico_screen.dart';
import 'verify_email_screen.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  bool _loading = false;
  bool _obscurePass = true;

  // ── Login con correo ──────────────────────────────────────────────────────
  Future<void> _login() async {
    if (_emailCtrl.text.isEmpty || _passCtrl.text.isEmpty) {
      _showSnack('Completa todos los campos');
      return;
    }
    setState(() => _loading = true);
    try {
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text.trim(),
      );

      // ── Verificar si la cuenta está bloqueada / promover admin ─────────
      if (cred.user != null) {
        final userEmail = (cred.user!.email ?? '').toLowerCase();
        final ref = FirebaseFirestore.instance
            .collection('users')
            .doc(cred.user!.uid);
        final doc = await ref.get();
        final data = doc.data() ?? {};

        // Cuenta bloqueada
        if ((data['bloqueado'] ?? false) as bool) {
          await FirebaseAuth.instance.signOut();
          if (!mounted) return;
          _showSnack(
            'Tu cuenta ha sido suspendida. Contacta al administrador.',
            duration: const Duration(seconds: 6),
          );
          setState(() => _loading = false);
          return;
        }

        // Promover automáticamente a admin si el dominio coincide
        if (userEmail.endsWith('@matetec.com') &&
            (data['rol'] ?? 'estudiante') != 'admin') {
          await ref.update({'rol': 'admin'});
        }
      }

      // ── Verificar que el correo esté confirmado ───────────────────────
      // Excepción: admins @matetec.com no necesitan verificar correo
      final loginEmail = (cred.user?.email ?? _emailCtrl.text.trim()).toLowerCase();
      final esAdminDomain = loginEmail.endsWith('@matetec.com');
      if (cred.user != null && !cred.user!.emailVerified && !esAdminDomain) {
        final email = cred.user!.email ?? _emailCtrl.text.trim();
        if (!mounted) return;
        // Mantenemos sesión activa para que VerifyEmailScreen haga polling
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => VerifyEmailScreen(email: email),
          ),
        );
        return;
      }

      // Limpiar sesión de invitado si había una activa
      await LocalStorageService.endGuestSession();

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } on FirebaseAuthException catch (e) {
      final msgs = {
        'user-not-found': 'Usuario no encontrado',
        'wrong-password': 'Contraseña incorrecta',
        'invalid-credential': 'Correo o contraseña incorrectos',
        'invalid-email': 'Correo inválido',
        'user-disabled': 'Usuario deshabilitado',
        'too-many-requests': 'Demasiados intentos, espera un momento',
        'network-request-failed': 'Sin conexión a internet',
      };
      _showSnack(msgs[e.code] ?? 'Error: ${e.code}');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Google Sign-In ────────────────────────────────────────────────────────
  Future<void> _signInWithGoogle() async {
    setState(() => _loading = true);
    try {
      UserCredential userCredential;

      if (kIsWeb) {
        final provider = GoogleAuthProvider()
          ..addScope('email')
          ..addScope('profile')
          ..setCustomParameters({'prompt': 'select_account'});
        try {
          userCredential =
              await FirebaseAuth.instance.signInWithPopup(provider);
        } on FirebaseAuthException catch (e) {
          if (e.code == 'popup-blocked') {
            // Fallback: redirect si el popup fue bloqueado
            await FirebaseAuth.instance.signInWithRedirect(provider);
            return;
          }
          rethrow;
        }
      } else {
        // Limpiar credenciales en caché para evitar tokens obsoletos
        final googleSignIn =
            GoogleSignIn(scopes: ['email', 'profile']);
        try {
          await googleSignIn.signOut();
        } catch (_) {}

        final googleUser = await googleSignIn.signIn();
        if (googleUser == null) {
          if (mounted) setState(() => _loading = false);
          return;
        }
        final googleAuth = await googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        userCredential =
            await FirebaseAuth.instance.signInWithCredential(credential);
      }

      final user = userCredential.user!;
      final docRef =
          FirebaseFirestore.instance.collection('users').doc(user.uid);
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
      } else {
        // Usuario existente: promover a admin si su correo es @matetec.com
        final existingData = doc.data() as Map<String, dynamic>? ?? {};
        final userEmail = (user.email ?? '').toLowerCase();
        if (userEmail.endsWith('@matetec.com') &&
            (existingData['rol'] ?? 'estudiante') != 'admin') {
          await docRef.update({'rol': 'admin'});
        }
        // Verificar si está bloqueado
        if ((existingData['bloqueado'] ?? false) as bool) {
          await FirebaseAuth.instance.signOut();
          _showSnack(
            'Tu cuenta ha sido suspendida. Contacta al administrador.',
            duration: const Duration(seconds: 6),
          );
          return;
        }
      }

      // Limpiar sesión de invitado si había una activa
      await LocalStorageService.endGuestSession();

      if (!mounted) return;
      final data = (await docRef.get()).data();
      final grado = (data?['grado'] ?? 'Pendiente') as String;
      final rol   = (data?['rol']   ?? 'estudiante') as String;
      // Admins no necesitan diagnóstico → van directo al home
      if (rol != 'admin' && (grado == 'Pendiente' || grado.isEmpty)) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const DiagnosticoScreen()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    } on FirebaseAuthException catch (e) {
      final msgs = {
        'popup-closed-by-user':     'Cerraste la ventana de Google',
        'cancelled-popup-request':  'Solicitud cancelada, intenta de nuevo',
        'popup-blocked':            'Popup bloqueado — permite popups para localhost',
        'unauthorized-domain':      'Dominio no autorizado en Firebase Console',
        'operation-not-allowed':    'Google Sign-In no está habilitado en Firebase',
        'account-exists-with-different-credential':
            'Ya existe una cuenta con ese correo',
        'network-request-failed':   'Sin conexión a internet',
      };
      final msg = msgs[e.code] ?? '[${e.code}] ${e.message ?? "sin detalle"}';
      _showSnack(msg, duration: const Duration(seconds: 6));
      debugPrint('GOOGLE LOGIN ERROR code=${e.code}  msg=${e.message}');
    } catch (e) {
      debugPrint('GOOGLE LOGIN ERROR: $e');
      final txt = e.toString();
      _showSnack(
        txt.length > 120 ? txt.substring(0, 120) : txt,
        duration: const Duration(seconds: 6),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showSnack(String msg, {bool isError = true, Duration duration = const Duration(seconds: 3)}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? AppColors.danger : AppColors.success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(12),
      duration: duration,
    ));
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  // ── UI ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // ── Header rojo ───────────────────────────────────────────────
          Container(
            height: MediaQuery.of(context).size.height * 0.38,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFE53935), Color(0xFFC62828)],
              ),
            ),
          ),

          // ── Cuerpo scrollable ─────────────────────────────────────────
          SafeArea(
            child: Column(
              children: [
                // Flecha + espacio superior
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new,
                        color: Colors.white, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),

                // Ícono + título en la zona roja
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.lock_open_rounded,
                            color: Colors.white, size: 28),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Bienvenido\nde vuelta',
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Ingresa a tu cuenta para continuar',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Tarjeta blanca con el formulario
                Expanded(
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Color(0xFFFAFAFA),
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(32)),
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Correo ──────────────────────────────────
                          _buildLabel('Correo electrónico'),
                          const SizedBox(height: 8),
                          _buildField(
                            controller: _emailCtrl,
                            hint: 'ejemplo@correo.com',
                            icon: Icons.email_outlined,
                            keyboard: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 20),

                          // ── Contraseña ───────────────────────────────
                          _buildLabel('Contraseña'),
                          const SizedBox(height: 8),
                          _buildField(
                            controller: _passCtrl,
                            hint: '••••••••',
                            icon: Icons.lock_outline,
                            obscure: _obscurePass,
                            suffix: IconButton(
                              icon: Icon(
                                _obscurePass
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                size: 20,
                                color: Colors.grey.shade500,
                              ),
                              onPressed: () => setState(
                                  () => _obscurePass = !_obscurePass),
                            ),
                          ),

                          // ── ¿Olvidaste? ───────────────────────────────
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _loading
                                  ? null
                                  : () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => ForgotPasswordScreen(
                                            initialEmail:
                                                _emailCtrl.text.trim(),
                                          ),
                                        ),
                                      ),
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero,
                              ),
                              child: Text(
                                '¿Olvidaste tu contraseña?',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 8),

                          // ── Botón iniciar sesión ──────────────────────
                          SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: ElevatedButton(
                              onPressed: _loading ? null : _login,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 0,
                              ),
                              child: _loading
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2.5,
                                      ),
                                    )
                                  : const Text(
                                      'Iniciar sesión',
                                      style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600),
                                    ),
                            ),
                          ),

                          const SizedBox(height: 24),

                          // ── Divisor ───────────────────────────────────
                          Row(
                            children: [
                              Expanded(
                                  child:
                                      Divider(color: Colors.grey.shade300)),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14),
                                child: Text(
                                  'o',
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade500),
                                ),
                              ),
                              Expanded(
                                  child:
                                      Divider(color: Colors.grey.shade300)),
                            ],
                          ),

                          const SizedBox(height: 20),

                          // ── Botón Google ──────────────────────────────
                          _GoogleButton(
                            onPressed: _loading ? null : _signInWithGoogle,
                            loading: _loading,
                          ),

                          const SizedBox(height: 28),

                          // ── Ir a registro ─────────────────────────────
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '¿No tienes cuenta? ',
                                style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade600),
                              ),
                              GestureDetector(
                                onTap: _loading
                                    ? null
                                    : () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                              builder: (_) =>
                                                  const RegisterScreen()),
                                        ),
                                child: const Text(
                                  'Regístrate',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Color(0xFF444444),
        ),
      );

  Widget _buildField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboard = TextInputType.text,
    bool obscure = false,
    Widget? suffix,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboard,
      style: const TextStyle(fontSize: 15, color: Color(0xFF1A1A1A)),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
        prefixIcon: Icon(icon, size: 20, color: Colors.grey.shade500),
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
    );
  }
}

// ── Botón Google ──────────────────────────────────────────────────────────────
class _GoogleButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool loading;
  const _GoogleButton({required this.onPressed, this.loading = false});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF444444),
          side: BorderSide(color: Colors.grey.shade300, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5, color: AppColors.primary),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _GoogleLogo(),
                  const SizedBox(width: 12),
                  const Text(
                    'Continuar con Google',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF333333)),
                  ),
                ],
              ),
      ),
    );
  }
}

class _GoogleLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.grey.shade200),
        color: Colors.white,
      ),
      child: const Center(
        child: Text(
          'G',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w900,
            color: Color(0xFF4285F4),
            height: 1,
          ),
        ),
      ),
    );
  }
}
