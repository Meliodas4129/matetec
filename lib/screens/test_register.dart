import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TestRegister extends StatefulWidget {
  const TestRegister({super.key});

  @override
  State<TestRegister> createState() => _TestRegisterState();
}

class _TestRegisterState extends State<TestRegister> {
  final emailController = TextEditingController();
  final passController = TextEditingController();

  bool loading = false;

  Future<void> register() async {
    setState(() => loading = true);

    try {
      print("🚀 Iniciando registro...");

      // 🔐 Crear usuario
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: emailController.text.trim(),
            password: passController.text.trim(),
          );

      final uid = credential.user!.uid;
      print("✅ Usuario creado en Auth: $uid");

      // 🗂️ Guardar en Firestore
      print("📦 Guardando en Firestore...");

      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'email': emailController.text.trim(),
        'nombre': 'Usuario prueba',
        'grado': '1° Primaria',
        'rol': 'estudiante',
        'createdAt': FieldValue.serverTimestamp(),
      });

      print("🔥 Datos guardados en Firestore correctamente");

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Registro completo ✅")));
    } catch (e) {
      print("❌ ERROR: $e");

      // 🔥 eliminar usuario si falla Firestore
      try {
        await FirebaseAuth.instance.currentUser?.delete();
        print("🧹 Usuario eliminado por error");
      } catch (_) {}

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Error en registro ❌")));
    }

    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Test Firebase')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: 'Correo'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: passController,
              decoration: const InputDecoration(labelText: 'Contraseña'),
              obscureText: true,
            ),
            const SizedBox(height: 20),

            loading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: register,
                    child: const Text("Registrar"),
                  ),
          ],
        ),
      ),
    );
  }
}
