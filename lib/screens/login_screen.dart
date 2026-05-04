import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'home_inicio.dart'; // ✅ corregido (antes era home_inicio.dart)
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePass = true;

  // ── LOGIN ────────────────────────────────────────────────────────────────
  Future<void> loginUser() async {
    if (emailController.text.isEmpty || passwordController.text.isEmpty) {
      _showSnack('Completa todos los campos');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      _showSnack('Bienvenido ${credential.user?.email}', isError: false);

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } on FirebaseAuthException catch (e) {
      // Firebase SDK nuevo usa 'invalid-credential' para usuario/contraseña incorrectos
      final errores = {
        'user-not-found': 'Usuario no encontrado',
        'wrong-password': 'Contraseña incorrecta',
        'invalid-credential': 'Correo o contraseña incorrectos', // ✅ nuevo SDK
        'invalid-email': 'Correo inválido',
        'user-disabled': 'Usuario deshabilitado',
        'too-many-requests': 'Demasiados intentos, espera un momento',
        'network-request-failed': 'Sin conexión a internet',
      };

      _showSnack(errores[e.code] ?? 'Error: ${e.code}');
    } catch (e) {
      _showSnack('Error inesperado');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── RESET PASSWORD ───────────────────────────────────────────────────────
  Future<void> resetPassword() async {
    if (emailController.text.isEmpty) {
      _showSnack('Ingresa tu correo primero');
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: emailController.text.trim(),
      );
      _showSnack(
        'Correo enviado para restablecer contraseña 📩',
        isError: false,
      );
    } on FirebaseAuthException catch (e) {
      final errores = {
        'user-not-found': 'No existe ese correo',
        'invalid-email': 'Correo inválido',
      };
      _showSnack(errores[e.code] ?? 'Error: ${e.code}');
    } catch (e) {
      _showSnack('Error al enviar correo');
    }
  }

  void _showSnack(String msg, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
      ),
    );
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  // ── UI ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    const rojo = Color(0xFFE53935);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F3FF),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ── Logo / título ──────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFEBEE),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.school, color: rojo, size: 40),
                ),

                const SizedBox(height: 16),

                const Text(
                  'MateTec',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: rojo,
                  ),
                ),

                const SizedBox(height: 6),

                const Text(
                  'Iniciar sesión',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),

                const SizedBox(height: 30),

                // ── Email ──────────────────────────────────────────────
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Correo',
                    prefixIcon: const Icon(Icons.email_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: rojo),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // ── Password ───────────────────────────────────────────
                TextField(
                  controller: passwordController,
                  obscureText: _obscurePass,
                  decoration: InputDecoration(
                    labelText: 'Contraseña',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePass
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePass = !_obscurePass),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: rojo),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),

                // ── ¿Olvidaste? ────────────────────────────────────────
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: resetPassword,
                    child: const Text(
                      '¿Olvidaste tu contraseña?',
                      style: TextStyle(color: rojo),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // ── Botón login ────────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(color: rojo),
                        )
                      : ElevatedButton(
                          onPressed: loginUser,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: rojo,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Iniciar sesión',
                            style: TextStyle(fontSize: 15),
                          ),
                        ),
                ),

                const SizedBox(height: 20),

                // ── Ir a registro ──────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('¿No tienes cuenta? '),
                    GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const RegisterScreen(),
                        ),
                      ),
                      child: const Text(
                        'Regístrate',
                        style: TextStyle(
                          color: rojo,
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
      ),
    );
  }
}
