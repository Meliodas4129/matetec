import 'package:flutter/material.dart';
import 'login_screen.dart';
import 'register_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  // Definimos los colores exactos para reusarlos
  static const Color colorRojoRegistro = Color(0xFFE53935);
  static const Color colorNegroLogin = Colors.black;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Mantenemos esto para que el fondo cubra todo, incluso detrás de la barra de estado
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent, // Barra transparente
        elevation: 0, // Sin sombra
        automaticallyImplyLeading: false, // Oculta el botón de "atrás"
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        // --- TU IMAGEN DE FONDO EXTRUCTURAL (fondo.jpg) ---
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/fondo.jpg'),
            fit: BoxFit.cover, // Cubre toda la pantalla
          ),
        ),
        // SafeArea protege el contenido de notches y barras del sistema
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30.0),
            child: Column(
              // Empuja todo el contenido hacia la parte inferior
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Este Spacer es clave. Ocupa todo el espacio de arriba,
                // empujando el texto y los botones hacia abajo.
                const Spacer(),

                // --- NUEVO BLOQUE DE TEXTO REPOSICIONADO (Más limpio) ---
                // TÍTULO "MateTec"
                const Text(
                  'MateTec',
                  style: TextStyle(
                    fontSize: 48, // Grande y prominente
                    fontWeight: FontWeight.bold,
                    color: Colors.black, // Color limpio
                    letterSpacing: 1.5,
                  ),
                ),

                const SizedBox(
                  height: 10,
                ), // Espacio corto entre título y descripción
                // TEXTO DESCRIPTIVO EN ESPAÑOL
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10.0),
                  child: Text(
                    '¡Una forma divertida y atractiva para que los niños descubran las matemáticas y la tecnología!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.black87, // Color limpio
                      fontWeight: FontWeight.w500,
                      height: 1.4, // Interlineado para mejor lectura
                    ),
                  ),
                ),

                const SizedBox(
                  height: 40,
                ), // Espacio generoso antes de los botones
                // --- BOTONES DE REGISTRO (ROJO) ---
                _buildMenuButton(
                  text: 'REGISTRARSE',
                  color: colorRojoRegistro,
                  textColor: Colors.white,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const RegisterScreen()),
                    );
                  },
                ),

                const SizedBox(height: 15), // Espacio entre botones
                // --- BOTÓN DE INICIO DE SESIÓN (NEGRO) ---
                _buildMenuButton(
                  text: 'INICIAR SESIÓN',
                  color: colorNegroLogin,
                  textColor: Colors.white,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                    );
                  },
                ),

                const SizedBox(height: 50), // Espacio final inferior
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- WIDGET AUXILIAR PARA CREAR LOS BOTONES ---
  Widget _buildMenuButton({
    required String text,
    required Color color,
    required Color textColor,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity, // Ocupa todo el ancho disponible
      height: 60, // Botones altos y robustos
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: textColor,
          elevation: 4, // Pequeña sombra
          // Shape rectangular con bordes ligeramente redondeados
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 20, // Texto grande y claro
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}
