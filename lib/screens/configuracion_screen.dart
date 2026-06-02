import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'welcome_screen.dart';
import '../services/notification_service.dart';
import '../services/theme_service.dart';
import '../services/ia_service.dart';

class ConfiguracionScreen extends StatefulWidget {
  const ConfiguracionScreen({super.key});

  @override
  State<ConfiguracionScreen> createState() => _ConfiguracionScreenState();
}

class _ConfiguracionScreenState extends State<ConfiguracionScreen> {
  bool _notificacionesActivas = true;
  bool _rachaActiva           = true;
  bool _sonidoActivo          = true;
  bool _enviandoCorreo        = false;

  int  _notifHora   = 18;
  int  _notifMinuto = 0;

  @override
  void initState() {
    super.initState();
    _cargarPreferencias();
  }

  Future<void> _cargarPreferencias() async {
    final prefs = await SharedPreferences.getInstance();
    final cfg   = await NotificationService.leerConfig();
    if (mounted) {
      setState(() {
        _notificacionesActivas = cfg.activo;
        _rachaActiva           = cfg.rachaActivo;
        _notifHora             = cfg.hora;
        _notifMinuto           = cfg.minuto;
        _sonidoActivo          = prefs.getBool('sonido') ?? true;
      });
    }
  }

  Future<void> _guardarSonido(bool value) async {
    setState(() => _sonidoActivo = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('sonido', value);
  }

  Future<void> _toggleRecordatorio(bool activo) async {
    setState(() => _notificacionesActivas = activo);
    await NotificationService.programarRecordatorioDiario(
      hora:   _notifHora,
      minuto: _notifMinuto,
      activo: activo,
    );
  }

  Future<void> _toggleRacha(bool activo) async {
    setState(() => _rachaActiva = activo);
    await NotificationService.programarAlertaRacha(activo: activo);
  }

  Future<void> _elegirHora() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _notifHora, minute: _notifMinuto),
      helpText: 'Hora del recordatorio diario',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _notifHora   = picked.hour;
      _notifMinuto = picked.minute;
    });
    await NotificationService.programarRecordatorioDiario(
      hora:   _notifHora,
      minuto: _notifMinuto,
      activo: _notificacionesActivas,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Recordatorio a las ${picked.format(context)}'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(12),
      ));
    }
  }

  Future<void> _enviarResumenSemanal() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Necesitas iniciar sesión.')),
      );
      return;
    }
    setState(() => _enviandoCorreo = true);
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users').doc(user.uid).get();
      if (!doc.exists) throw Exception('Perfil no encontrado');
      final email = user.email ?? '';
      if (email.isEmpty) throw Exception('Sin correo registrado');
      final ok = await IAService.enviarResumen(destino: email, datos: doc.data() ?? {});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? '✅ Resumen enviado a $email' : '❌ Error al enviar'),
        backgroundColor: ok ? Colors.green[700] : Colors.red[700],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(12),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error: $e'),
        backgroundColor: Colors.red[700],
      ));
    } finally {
      if (mounted) setState(() => _enviandoCorreo = false);
    }
  }

  Future<void> _cerrarSesion() async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cerrar Sesión'),
        content: const Text('¿Estás seguro de que quieres cerrar sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
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
            child: const Text('Cerrar Sesión',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // ── Helpers de UI ──────────────────────────────────────────────────────────

  Widget _seccionTitulo(String titulo) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
    child: Text(
      titulo.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.3,
        color: AppColors.textMuted,
      ),
    ),
  );

  Widget _card({required List<Widget> children}) => ClipRRect(
    borderRadius: BorderRadius.circular(16),
    child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: children,
      ),
    ),
  );

  Widget _divider() => const Divider(height: 1, color: AppColors.border, indent: 56);

  Widget _iconBox(IconData icon, Color color, Color bg) => Container(
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Icon(icon, color: color, size: 20),
  );

  @override
  Widget build(BuildContext context) {
    final horaStr =
        '${_notifHora.toString().padLeft(2, '0')}:${_notifMinuto.toString().padLeft(2, '0')}';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Configuración'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 40),
        children: [

          // ── NOTIFICACIONES ─────────────────────────────────────────────────
          _seccionTitulo('Notificaciones'),
          _card(children: [
            // Recordatorio diario
            SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
              secondary: _iconBox(Icons.notifications_rounded,
                  AppColors.primary, AppColors.primarySoft),
              title: const Text('Recordatorio diario',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary)),
              subtitle: Text(
                _notificacionesActivas ? 'Activo a las $horaStr' : 'Desactivado',
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary),
              ),
              value: _notificacionesActivas,
              onChanged: _toggleRecordatorio,
              activeColor: AppColors.primary,
            ),
            _divider(),
            // Elegir hora
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              leading: _iconBox(Icons.schedule_rounded,
                  AppColors.textSecondary, AppColors.surfaceVariant),
              title: const Text('Hora del recordatorio',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w500)),
              subtitle: const Text('Toca para cambiar',
                  style: TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
              trailing: Text(
                horaStr,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary),
              ),
              onTap: _notificacionesActivas ? _elegirHora : null,
            ),
            _divider(),
            // Alerta racha
            SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
              secondary: _iconBox(Icons.local_fire_department,
                  Colors.orange, Colors.orange.withValues(alpha: 0.12)),
              title: const Text('Alerta de racha',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary)),
              subtitle: const Text('Aviso a las 20:00 si no practicaste',
                  style: TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
              value: _rachaActiva,
              onChanged: _toggleRacha,
              activeColor: Colors.orange,
            ),
          ]),

          // ── SONIDO ─────────────────────────────────────────────────────────
          _seccionTitulo('Sonido'),
          _card(children: [
            SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
              secondary: _iconBox(Icons.volume_up_rounded,
                  AppColors.primary, AppColors.primarySoft),
              title: const Text('Sonido en logros',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary)),
              subtitle: const Text('Al alcanzar objetivos',
                  style: TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
              value: _sonidoActivo,
              onChanged: _guardarSonido,
              activeColor: AppColors.primary,
            ),
          ]),

          // ── PROGRESO ───────────────────────────────────────────────────────
          _seccionTitulo('Progreso'),
          _card(children: [
            ListTile(
              leading: _enviandoCorreo
                  ? const SizedBox(
                      width: 36, height: 36,
                      child: Padding(
                        padding: EdgeInsets.all(8),
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: AppColors.primary),
                      ))
                  : _iconBox(Icons.email_outlined,
                      AppColors.primary, AppColors.primarySoft),
              title: const Text('Enviar resumen semanal',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w500)),
              subtitle: const Text('Recibe tus estadísticas por correo',
                  style: TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
              trailing: const Icon(Icons.send_rounded,
                  size: 18, color: AppColors.textMuted),
              onTap: _enviandoCorreo ? null : _enviarResumenSemanal,
            ),
          ]),

          // ── INFORMACIÓN ────────────────────────────────────────────────────
          _seccionTitulo('Información'),
          _card(children: [
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              leading: _iconBox(Icons.privacy_tip_outlined,
                  AppColors.textSecondary, AppColors.surfaceVariant),
              title: const Text('Política de Privacidad',
                  style: TextStyle(color: AppColors.textPrimary)),
              trailing: const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textMuted),
              onTap: () => _mostrarDialogo('Política de Privacidad',
                  'MateTec respeta tu privacidad. Tus datos se usan solo para mejorar tu aprendizaje.\n\n'
                  'No compartimos datos con terceros sin tu consentimiento.\n\n'
                  'Contacto: info@matetec.com'),
            ),
            _divider(),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              leading: _iconBox(Icons.description_outlined,
                  AppColors.textSecondary, AppColors.surfaceVariant),
              title: const Text('Términos de Servicio',
                  style: TextStyle(color: AppColors.textPrimary)),
              trailing: const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textMuted),
              onTap: () => _mostrarDialogo('Términos de Servicio',
                  'Al usar MateTec aceptas nuestros términos.\n\n'
                  'Nos reservamos el derecho de actualizarlos.\n\n'
                  'Consultas: info@matetec.com'),
            ),
            _divider(),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              leading: _iconBox(Icons.info_outline_rounded,
                  AppColors.textSecondary, AppColors.surfaceVariant),
              title: const Text('Acerca de MateTec',
                  style: TextStyle(color: AppColors.textPrimary)),
              trailing: const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textMuted),
              onTap: () => showAboutDialog(
                context: context,
                applicationName: 'MateTec',
                applicationVersion: '1.0.0',
                applicationLegalese: '© 2024 MateTec. Todos los derechos reservados.',
              ),
            ),
          ]),

          // ── SESIÓN ─────────────────────────────────────────────────────────
          _seccionTitulo('Sesión'),
          _card(children: [
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              leading: _iconBox(Icons.logout_rounded,
                  Colors.red, Colors.red.withValues(alpha: 0.12)),
              title: const Text('Cerrar Sesión',
                  style: TextStyle(
                      color: Colors.red, fontWeight: FontWeight.w600)),
              trailing: const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textMuted),
              onTap: _cerrarSesion,
            ),
          ]),

          const SizedBox(height: 32),
          // Footer
          Center(
            child: Text(
              'MateTec v1.0.0 · Desarrollado con ❤️',
              style: TextStyle(color: AppColors.textMuted, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  void _mostrarDialogo(String titulo, String contenido) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(titulo),
        content: SingleChildScrollView(child: Text(contenido)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }
}
