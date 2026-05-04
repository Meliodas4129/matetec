import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../theme/app_theme.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nombreController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePass = true;

  // ───────────────────────── Helpers ─────────────────────────
  /// Documento base que guardamos en Firestore para un usuario nuevo
  Map<String, dynamic> _datosNuevoUsuario({
    required String nombre,
    required String email,
  }) {
    return {
      'nombre': nombre,
      'email': email,
      // 🔥 IA lo asignará después
      'grado': 'Pendiente',
      'grado_num': 0,
      // 📊 Datos para IA
      'aciertos': 0,
      'errores': 0,
      'intentos': 0,
      'tiempo_total': 0,
      // 📚 Progreso por tema
      'temas': {
        'sumas': {'aciertos': 0, 'intentos': 0},
        'restas': {'aciertos': 0, 'intentos': 0},
        'multiplicacion': {'aciertos': 0, 'intentos': 0},
        'division': {'aciertos': 0, 'intentos': 0},
      },
      // extras
      'racha': 0,
      'puntos': 0,
      'rol': 'estudiante',
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  String _mensajeErrorAuth(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'Ese correo ya está registrado';
      case 'invalid-email':
        return 'Correo inválido';
      case 'weak-password':
        return 'La contraseña es muy débil';
      case 'operation-not-allowed':
        return 'Registro con correo no habilitado';
      case 'network-request-failed':
        return 'Sin conexión a internet';
      default:
        return 'Error: ${e.code}';
    }
  }

  // 🔐 REGISTRO CON CORREO Y CONTRASEÑA
  Future<void> _registerUser() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    UserCredential? credential;
    try {
      // 1️⃣ Crear cuenta en Firebase Auth
      credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final uid = credential.user!.uid;

      // 2️⃣ Crear documento en Firestore
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .set(
              _datosNuevoUsuario(
                nombre: _nombreController.text.trim(),
                email: _emailController.text.trim(),
              ),
            );
      } catch (e) {
        // Si Firestore falla, sí tiene sentido borrar el Auth para que pueda
        // volver a intentar. Pero solo en este caso específico.
        await credential.user?.delete();
        rethrow;
      }

      _showSnack('Ahora realiza el diagnóstico 🧠', isError: false);

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/diagnostico');
    } on FirebaseAuthException catch (e) {
      _showSnack(_mensajeErrorAuth(e));
    } catch (e) {
      debugPrint('Error registro: $e');
      _showSnack('Error al registrar, intenta de nuevo');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 🔥 GOOGLE LOGIN (funciona en Web y en Android/iOS)
  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);

    try {
      UserCredential userCredential;

      if (kIsWeb) {
        // 🌐 Flutter Web → popup
        final provider = GoogleAuthProvider();
        userCredential = await FirebaseAuth.instance.signInWithPopup(provider);
      } else {
        // 📱 Android / iOS → google_sign_in
        final googleUser = await GoogleSignIn().signIn();
        if (googleUser == null) {
          // El usuario canceló el diálogo
          if (mounted) setState(() => _isLoading = false);
          return;
        }
        final googleAuth = await googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        userCredential = await FirebaseAuth.instance.signInWithCredential(
          credential,
        );
      }

      final user = userCredential.user!;
      final uid = user.uid;

      final docRef = FirebaseFirestore.instance.collection('users').doc(uid);
      final doc = await docRef.get();

      // 🔥 Si es nuevo usuario, creamos el documento
      bool esNuevo = false;
      if (!doc.exists) {
        await docRef.set(
          _datosNuevoUsuario(
            nombre: user.displayName ?? 'Usuario',
            email: user.email ?? '',
          ),
        );
        esNuevo = true;
      }

      _showSnack('Bienvenido 🚀', isError: false);

      if (!mounted) return;

      // 🔥 Decidir destino: si es nuevo o no hizo diagnóstico → diagnóstico
      final data = (await docRef.get()).data();
      final grado = (data?['grado'] ?? 'Pendiente') as String;
      if (esNuevo || grado == 'Pendiente' || grado.isEmpty) {
        Navigator.pushReplacementNamed(context, '/diagnostico');
      } else {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } on FirebaseAuthException catch (e) {
      _showSnack(_mensajeErrorAuth(e));
    } catch (e) {
      debugPrint('ERROR GOOGLE: $e');
      _showSnack('Error con Google');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? AppColors.danger : AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // ── Logo ──────────────────────────────────────────────
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.person_add_alt_1_rounded,
                    color: AppColors.primary,
                    size: 36,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Crear cuenta',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Empieza a aprender hoy mismo',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 32),

                _buildInput(
                  _nombreController,
                  'Nombre',
                  Icons.person_outline,
                  (v) => v!.isEmpty ? 'Requerido' : null,
                ),
                const SizedBox(height: 14),

                _buildInput(
                  _emailController,
                  'Correo',
                  Icons.email_outlined,
                  (v) => !v!.contains('@') ? 'Correo inválido' : null,
                ),
                const SizedBox(height: 14),

                _buildInput(
                  _passwordController,
                  'Contraseña',
                  Icons.lock_outline,
                  (v) => v!.length < 6 ? 'Mínimo 6 caracteres' : null,
                  obscure: _obscurePass,
                  suffix: IconButton(
                    icon: Icon(
                      _obscurePass
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePass = !_obscurePass),
                  ),
                ),

                const SizedBox(height: 24),

                _buildButton(),

                const SizedBox(height: 16),

                // ── Divisor "o" ───────────────────────────────────────
                Row(
                  children: const [
                    Expanded(child: Divider(color: AppColors.border)),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'o',
                        style: TextStyle(color: AppColors.textMuted),
                      ),
                    ),
                    Expanded(child: Divider(color: AppColors.border)),
                  ],
                ),

                const SizedBox(height: 16),

                // ── Google ────────────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: OutlinedButton.icon(
                    onPressed: _isLoading ? null : _signInWithGoogle,
                    icon: const Icon(
                      Icons.g_mobiledata_rounded,
                      size: 28,
                    ),
                    label: const Text(
                      'Continuar con Google',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      side: const BorderSide(
                        color: AppColors.border,
                        width: 1.5,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      '¿Ya tienes cuenta? ',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Text(
                        'Inicia sesión',
                        style: TextStyle(
                          color: AppColors.primaryLight,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInput(
    TextEditingController controller,
    String label,
    IconData icon,
    String? Function(String?) validator, {
    bool obscure = false,
    Widget? suffix,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      validator: validator,
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        suffixIcon: suffix,
      ),
    );
  }

  Widget _buildButton() => SizedBox(
    width: double.infinity,
    height: 54,
    child: _isLoading
        ? const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          )
        : ElevatedButton(
            onPressed: _registerUser,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text(
              'Crear cuenta',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
  );
}
