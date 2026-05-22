import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'welcome_screen.dart';

class ConfiguracionScreen extends StatefulWidget {
  const ConfiguracionScreen({super.key});

  @override
  State<ConfiguracionScreen> createState() => _ConfiguracionScreenState();
}

class _ConfiguracionScreenState extends State<ConfiguracionScreen> {
  bool _notificacionesActivas = true;
  bool _sonidoActivo = true;
  bool _temaOscuro = false;

  @override
  void initState() {
    super.initState();
    _cargarPreferencias();
  }

  Future<void> _cargarPreferencias() async {
    final prefs = await SharedPreferences.getInstance();
    final notificaciones = prefs.getBool('notificaciones') ?? true;
    final sonido = prefs.getBool('sonido') ?? true;
    final tema = prefs.getBool('temaOscuro') ?? false;

    if (mounted) {
      setState(() {
        _notificacionesActivas = notificaciones;
        _sonidoActivo = sonido;
        _temaOscuro = tema;
      });
    }
  }

  Future<void> _guardarPreferencias() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notificaciones', _notificacionesActivas);
    await prefs.setBool('sonido', _sonidoActivo);
    await prefs.setBool('temaOscuro', _temaOscuro);
  }

  Future<void> _cerrarSesion() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar Sesión'),
        content: const Text('¿Estás seguro de que quieres cerrar sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                (route) => false,
              );
            },
            child: const Text(
              'Cerrar Sesión',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('⚙️ Configuración'),
        backgroundColor: const Color(0xFFE53935),
        elevation: 0,
      ),
      body: ListView(
        children: [
          // SECCIÓN: NOTIFICACIONES Y SONIDO
          Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                )
              ],
            ),
            child: Column(
              children: [
                // Notificaciones
                ListTile(
                  leading: const Icon(Icons.notifications, color: Color(0xFFE53935)),
                  title: const Text('Notificaciones'),
                  subtitle: const Text('Recibe alertas y recordatorios'),
                  trailing: Switch(
                    value: _notificacionesActivas,
                    onChanged: (value) {
                      setState(() => _notificacionesActivas = value);
                      _guardarPreferencias();
                    },
                    activeColor: const Color(0xFFE53935),
                  ),
                ),
                Divider(height: 1, indent: 56),
                // Sonido
                ListTile(
                  leading: const Icon(Icons.volume_up, color: Color(0xFFE53935)),
                  title: const Text('Sonido en Logros'),
                  subtitle: const Text('Reproduce sonido al alcanzar objetivos'),
                  trailing: Switch(
                    value: _sonidoActivo,
                    onChanged: (value) {
                      setState(() => _sonidoActivo = value);
                      _guardarPreferencias();
                    },
                    activeColor: const Color(0xFFE53935),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // SECCIÓN: APARIENCIA
          Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                )
              ],
            ),
            child: Column(
              children: [
                // Tema oscuro
                ListTile(
                  leading: const Icon(Icons.dark_mode, color: Color(0xFFE53935)),
                  title: const Text('Tema Oscuro'),
                  subtitle: const Text('Próximamente disponible'),
                  trailing: Switch(
                    value: _temaOscuro,
                    onChanged: (value) {
                      setState(() => _temaOscuro = value);
                      _guardarPreferencias();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Tema oscuro en desarrollo'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                    activeColor: const Color(0xFFE53935),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // SECCIÓN: INFORMACIÓN
          Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                )
              ],
            ),
            child: Column(
              children: [
                // Privacidad
                ListTile(
                  leading: const Icon(Icons.privacy_tip, color: Color(0xFFE53935)),
                  title: const Text('Política de Privacidad'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Política de Privacidad'),
                        content: const SingleChildScrollView(
                          child: Text(
                            'MateTec respeta tu privacidad. Tus datos personales se utilizan solo para mejorar tu experiencia de aprendizaje.\n\n'
                            'No compartimos tus datos con terceros sin tu consentimiento.\n\n'
                            'Para más información, contacta a: info@matetec.com',
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Entendido'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                Divider(height: 1, indent: 56),
                // Términos
                ListTile(
                  leading: const Icon(Icons.description, color: Color(0xFFE53935)),
                  title: const Text('Términos de Servicio'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Términos de Servicio'),
                        content: const SingleChildScrollView(
                          child: Text(
                            'Al usar MateTec aceptas nuestros términos de servicio.\n\n'
                            'Nos reservamos el derecho de actualizar estos términos en cualquier momento.\n\n'
                            'Para consultas: info@matetec.com',
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Aceptar'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                Divider(height: 1, indent: 56),
                // Acerca de
                ListTile(
                  leading: const Icon(Icons.info, color: Color(0xFFE53935)),
                  title: const Text('Acerca de MateTec'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    showAboutDialog(
                      context: context,
                      applicationName: 'MateTec',
                      applicationVersion: '1.0.0',
                      applicationLegalese:
                          '© 2024 MateTec. Todos los derechos reservados.\nDesarrollado con ❤️ para estudiantes.',
                      children: [
                        const SizedBox(height: 16),
                        const Text(
                          'MateTec es una plataforma de aprendizaje adaptativo que utiliza inteligencia artificial para personalizar la experiencia educativa de cada estudiante.',
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // SECCIÓN: SESIÓN
          Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                )
              ],
            ),
            child: ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text(
                'Cerrar Sesión',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
              ),
              onTap: _cerrarSesion,
            ),
          ),

          const SizedBox(height: 24),

          // Footer
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                Text(
                  'MateTec v1.0.0',
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  'Desarrollado con ❤️',
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
