import 'package:flutter/material.dart';

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  int numero1 = 8;
  int numero2 = 4;
  int respuesta = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F2A2E),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "$numero1 x $numero2 = ?",
              style: const TextStyle(fontSize: 28, color: Colors.white),
            ),

            const SizedBox(height: 20),

            SizedBox(
              width: 150,
              child: TextField(
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  respuesta = int.tryParse(value) ?? 0;
                },
                decoration: const InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
            ),

            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: () {
                if (respuesta == numero1 * numero2) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text("Correcto ✅")));
                } else {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text("Incorrecto ❌")));
                }
              },
              child: const Text("Responder"),
            ),
          ],
        ),
      ),
    );
  }
}
