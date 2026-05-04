import 'package:flutter/material.dart';
import '../services/ia_service.dart';

class TestIAScreen extends StatefulWidget {
  const TestIAScreen({super.key});

  @override
  State<TestIAScreen> createState() => _TestIAScreenState();
}

class _TestIAScreenState extends State<TestIAScreen> {
  final aciertosCtrl = TextEditingController(text: "5");
  final erroresCtrl = TextEditingController(text: "2");
  final tiempoCtrl = TextEditingController(text: "30");
  final intentosCtrl = TextEditingController(text: "3");

  bool loading = false;
  String resultado = "";

  Future<void> probarIA() async {
    setState(() {
      loading = true;
      resultado = "";
    });

    try {
      final data = await IAService.clasificar(
        aciertos: int.parse(aciertosCtrl.text),
        errores: int.parse(erroresCtrl.text),
        tiempo: double.parse(tiempoCtrl.text),
        intentos: int.parse(intentosCtrl.text),
      );

      setState(() {
        resultado = "Nivel: ${data["descripcion"]}\n(Grado: ${data["grado"]})";
      });
    } catch (e) {
      setState(() {
        resultado = "Error: $e";
      });
    }

    setState(() {
      loading = false;
    });
  }

  Widget campo(String label, TextEditingController ctrl) {
    return TextField(
      controller: ctrl,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Probar IA - MateTec")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            campo("Aciertos", aciertosCtrl),
            const SizedBox(height: 10),
            campo("Errores", erroresCtrl),
            const SizedBox(height: 10),
            campo("Tiempo promedio", tiempoCtrl),
            const SizedBox(height: 10),
            campo("Intentos", intentosCtrl),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: loading ? null : probarIA,
                child: loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("PROBAR IA"),
              ),
            ),

            const SizedBox(height: 20),

            Text(
              resultado,
              style: const TextStyle(fontSize: 18),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
