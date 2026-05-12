// lib/screens/register_screen.dart
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../theme/app_theme.dart';
import 'diagnostico_screen.dart';
import 'home_inicio.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  bool _loading = false;
  bool _obscurePass = true;

  // ── Datos base nuevo usuario ──────────────────────────────────────────────
  Map<String, dynamic> _datosNuevo({
    required String nombre,
    required String email,
  }) =>
      {
        'nombre': nombre,
        'email': email,
        'grado': 'Pendiente',
        'grado_num': 0,
        'aciertos': 0,
        'errores': 0,
        'intentos': 0,
        'tiempo_total': 0,
        'temas': {
          'sumas': {'aciertos': 0, 'intentos': 0},
          'restas': {'aciertos': 0, 'intentos': 0},
          'multiplicacion': {'aciertos': 0, 'intentos': 0},
          'division': {'aciertos': 0, 'intentos': 0},
        },
        'racha': 0,
        'puntos': 0,
        'rol': 'estudiante',
        'createdAt': FieldValue.serverTimestamp(),
      };

  // ── Registro con correo ───────────────────────────────────────────────────
  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    UserCredential? cred;
    try {
      cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text.trim(),
      );
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(cred.user!.uid)
            .set(_datosNuevo(
              nombre: _nombreCtrl.text.trim(),
              email: _emailCtrl.text.trim(),
            ));
      } catch (e) {
        await cred.user?.delete();
        rethrow;
      }
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const DiagnosticoScreen()),
      );
    } on FirebaseAuthException catch (e) {
      final msgs = {
        'email-already-in-use': 'Ese correo ya está registrado',
        'invalid-email': 'Correo inválido',
        'weak-password': 'La contraseña es muy débil',
        'network-request-failed': 'Sin conexión a internet',
      };
      _showSnack(msgs[e.code] ?? 'Error: ${e.code}');
    } catch (e) {
      _showSnack('Error al registrar, intenta de nuevo');
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
        final provider = GoogleAuthProvider();
        userCredential =
            await FirebaseAuth.instance.signInWithPopup(provider);
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

      bool esNuevo = false;
      if (!doc.exists) {
        await docRef.set(_datosNuevo(
          nombre: user.displayName ?? 'Usuario',
          email: user.email ?? '',
        ));
        esNuevo = true;
      }

      if (!mounted) return;
      final data = (await docRef.get()).data();
      final grado = (data?['grado'] ?? 'Pendiente') as String;
      if (esNuevo || grado == 'Pendiente' || grado.isEmpty) {
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
        'account-exists-with-different-credential':
            'Ya existe una cuenta con ese correo',
        'network-request-failed': 'Sin conexión a internet',
      };
      _showSnack(msgs[e.code] ?? 'Error: ${e.code}');
      debugPrint('GOOGLE REGISTER ERROR: ${e.code} - ${e.message}');
    } catch (e) {
      debugPrint('GOOGLE REGISTER ERROR: $e');
      _showSnack('Error con Google');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showSnack(String msg, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? AppColors.danger : AppColors.success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(12),
    ));
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
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
            height: MediaQuery.of(context).size.height * 0.36,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFE53935), Color(0xFFC62828)],
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Flecha atrás
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new,
                        color: Colors.white, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),

                // Ícono + título en zona roja
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
                        child: const Icon(Icons.person_add_alt_1_rounded,
                            color: Colors.white, size: 28),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Crear\ntu cuenta',
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Empieza a aprender matemáticas hoy',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Tarjeta blanca con formulario
                Expanded(
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Color(0xFFFAFAFA),
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(32)),
                    ),
                    child: SingleChildScrollView(
                      padding:
                          const EdgeInsets.fromLTRB(28, 32, 28, 24),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ── Nombre ──────────────────────────────
                            _buildLabel('Nombre completo'),
                            const SizedBox(height: 8),
                            _buildField(
                              controller: _nombreCtrl,
                              hint: 'Tu nombre',
                              icon: Icons.person_outline,
                              validator: (v) =>
                                  v!.isEmpty ? 'Requerido' : null,
                            ),
                            const SizedBox(height: 18),

                            // ── Correo ───────────────────────────────
                            _buildLabel('Correo electrónico'),
                            const SizedBox(height: 8),
                            _buildField(
                              controller: _emailCtrl,
                              hint: 'ejemplo@correo.com',
                              icon: Icons.email_outlined,
                              keyboard: TextInputType.emailAddress,
                              validator: (v) => !v!.contains('@')
                                  ? 'Correo inválido'
                                  : null,
                            ),
                            const SizedBox(height: 18),

                            // ── Contraseña ───────────────────────────
                            _buildLabel('Contraseña'),
                            const SizedBox(height: 8),
                            _buildField(
                              controller: _passCtrl,
                              hint: 'Mínimo 6 caracteres',
                              icon: Icons.lock_outline,
                              obscure: _obscurePass,
                              validator: (v) => v!.length < 6
                                  ? 'Mínimo 6 caracteres'
                                  : null,
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

                            const SizedBox(height: 24),

                            // ── Botón crear cuenta ───────────────────
                            SizedBox(
                              width: double.infinity,
                              height: 54,
                              child: ElevatedButton(
                                onPressed: _loading ? null : _register,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(16),
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
                                        'Crear cuenta',
                                        style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600),
                                      ),
                              ),
                            ),

                            const SizedBox(height: 20),

                            // ── Divisor ──────────────────────────────
                            Row(
                              children: [
                                Expanded(
                                    child: Divider(
                                        color: Colors.grey.shade300)),
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
                                    child: Divider(
                                        color: Colors.grey.shade300)),
                              ],
                            ),

                            const SizedBox(height: 16),

                            // ── Botón Google ─────────────────────────
                            _GoogleButton(
                              onPressed:
                                  _loading ? null : _signInWithGoogle,
                              loading: _loading,
                            ),

                            const SizedBox(height: 24),

                            // ── Link login ───────────────────────────
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.center,
                              children: [
                                Text(
                                  '¿Ya tienes cuenta? ',
                                  style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade600),
                                ),
                                GestureDetector(
                                  onTap: _loading
                                      ? null
                                      : () => Navigator.pop(context),
                                  child: const Text(
                                    'Inicia sesión',
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
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboard,
      validator: validator,
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
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              const BorderSide(color: AppColors.danger, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              const BorderSide(color: AppColors.danger, width: 1.5),
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
