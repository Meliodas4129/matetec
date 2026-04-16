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

  String? _gradoSeleccionado;
  bool _isLoading = false;
  bool _obscurePass = true;

  static const Map<String, List<String>> _grados = {
    'Primaria': [
      '1° Primaria',
      '2° Primaria',
      '3° Primaria',
      '4° Primaria',
      '5° Primaria',
      '6° Primaria',
    ],
  };

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
        'grado': _gradoSeleccionado,
        'rol': 'estudiante',
        'progreso': {},
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      _showSnack('¡Registro exitoso! 🎉', isError: false);
      Navigator.pushReplacementNamed(context, '/home');
    } on FirebaseAuthException catch (e) {
      final errores = {
        'email-already-in-use': 'El correo ya está registrado',
        'invalid-email': 'Correo inválido',
        'weak-password': 'Contraseña muy débil',
        'network-request-failed': 'Sin internet',
      };
      _showSnack(errores[e.code] ?? 'Error: ${e.code}');
    } catch (e) {
      _showSnack('Error al guardar datos');
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
                        onPressed: () {
                          setState(() => _obscurePass = !_obscurePass);
                        },
                      ),
                    ),
                    const SizedBox(height: 16),

                    _buildDropdown(),
                    const SizedBox(height: 30),

                    _buildButton(),
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

  // 🔴 HEADER ROJO
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

  Widget _buildDropdown() => DropdownButtonFormField<String>(
    value: _gradoSeleccionado,
    hint: const Text('Selecciona grado'),
    items: _grados.entries.expand((e) {
      return e.value.map((grado) {
        return DropdownMenuItem(value: grado, child: Text(grado));
      });
    }).toList(),
    onChanged: (val) => setState(() => _gradoSeleccionado = val),
    validator: (v) => v == null ? 'Selecciona grado' : null,
  );

  // 🔴 BOTÓN ROJO
  Widget _buildButton() => SizedBox(
    width: double.infinity,
    height: 50,
    child: _isLoading
        ? const Center(child: CircularProgressIndicator(color: AppColors.rojo))
        : ElevatedButton(
            onPressed: _registerUser,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.rojo,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Registrarse',
              style: TextStyle(fontSize: 16, color: Colors.white),
            ),
          ),
  );
}
