import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

  // 🔐 REGISTRO NORMAL
  Future<void> _registerUser() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
          );

      final uid = credential.user!.uid;

      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'nombre': _nombreController.text.trim(),
        'email': _emailController.text.trim(),

        // 🔥 IA lo asignará después
        'grado': 'Pendiente',
        'grado_num': 0,

        // 📊 Datos para IA
        'aciertos': 0,
        'errores': 0,
        'intentos': 0,
        'tiempo_total': 0,

        // extras
        'racha': 0,
        'puntos': 0,
        'rol': 'estudiante',

        'createdAt': FieldValue.serverTimestamp(),
      });

      _showSnack('Ahora realiza el diagnóstico 🧠', isError: false);

      if (!mounted) return;

      // 🔥 IR A DIAGNÓSTICO
      Navigator.pushReplacementNamed(context, '/diagnostico');
    } catch (e) {
      await FirebaseAuth.instance.currentUser?.delete();
      _showSnack('Error al registrar');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 🔥 GOOGLE LOGIN
  Future<void> _signInWithGoogle() async {
    try {
      setState(() => _isLoading = true);

      final provider = GoogleAuthProvider();

      final userCredential = await FirebaseAuth.instance.signInWithPopup(
        provider,
      );

      final user = userCredential.user!;
      final uid = user.uid;

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      // 🔥 Si es nuevo usuario
      if (!doc.exists) {
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'nombre': user.displayName ?? 'Usuario',
          'email': user.email,

          // 🔥 IA lo asignará
          'grado': 'Pendiente',
          'grado_num': 0,

          // 📊 IA
          'aciertos': 0,
          'errores': 0,
          'intentos': 0,
          'tiempo_total': 0,

          'racha': 0,
          'puntos': 0,
          'rol': 'estudiante',

          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      _showSnack('Bienvenido 🚀', isError: false);

      if (!mounted) return;

      // 🔥 IR A DIAGNÓSTICO
      Navigator.pushReplacementNamed(context, '/diagnostico');
    } catch (e) {
      print("ERROR GOOGLE: $e");
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
                      onPressed: _signInWithGoogle,
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
