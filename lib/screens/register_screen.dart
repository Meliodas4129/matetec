import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

// 🔴 Colores globales
class AppColors {
  static const Color rojo = Color(0xFFE53935);
  static const Color negro = Colors.black;
}

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
        backgroundColor: isError ? Colors.red : Colors.green,
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
      backgroundColor: const Color(0xFFF4F3FF),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(),

            Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    _buildInput(
                      _nombreController,
                      'NOMBRE',
                      Icons.person,
                      (v) => v!.isEmpty ? 'Requerido' : null,
                    ),

                    const SizedBox(height: 16),

                    _buildInput(
                      _emailController,
                      'CORREO',
                      Icons.email,
                      (v) => !v!.contains('@') ? 'Correo inválido' : null,
                    ),

                    const SizedBox(height: 16),

                    _buildInput(
                      _passwordController,
                      'CONTRASEÑA',
                      Icons.lock,
                      (v) => v!.length < 6 ? 'Mínimo 6 caracteres' : null,
                      obscure: _obscurePass,
                      suffix: IconButton(
                        icon: Icon(
                          _obscurePass
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () =>
                            setState(() => _obscurePass = !_obscurePass),
                      ),
                    ),

                    const SizedBox(height: 25),

                    _buildButton(),
                    const SizedBox(height: 10),

                    // 🔥 GOOGLE
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _signInWithGoogle,
                      icon: const Icon(Icons.login),
                      label: const Text("Continuar con Google"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        side: const BorderSide(color: Colors.grey),
                        minimumSize: const Size(double.infinity, 50),
                      ),
                    ),

                    const SizedBox(height: 20),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('¿Ya tienes cuenta? '),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: const Text(
                            'Inicia sesión',
                            style: TextStyle(
                              color: AppColors.negro,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 🔴 HEADER
  Widget _buildHeader() => Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(24, 60, 24, 30),
    decoration: const BoxDecoration(
      color: AppColors.rojo,
      borderRadius: BorderRadius.only(
        bottomLeft: Radius.circular(30),
        bottomRight: Radius.circular(30),
      ),
    ),
    child: const Column(
      children: [
        Icon(Icons.school, color: Colors.white, size: 40),
        SizedBox(height: 10),
        Text(
          'Crear cuenta',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    ),
  );

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
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        suffixIcon: suffix,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: AppColors.rojo),
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _buildButton() => SizedBox(
    width: double.infinity,
    height: 50,
    child: _isLoading
        ? const Center(child: CircularProgressIndicator(color: AppColors.rojo))
        : ElevatedButton(
            onPressed: _registerUser,
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.rojo),
            child: const Text('Registrarse'),
          ),
  );
}
