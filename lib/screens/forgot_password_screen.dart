// lib/screens/forgot_password_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_theme.dart';
import '../services/ia_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  /// Si se pasa, pre-rellena el campo de correo.
  final String initialEmail;

  const ForgotPasswordScreen({super.key, this.initialEmail = ''});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  late final TextEditingController _emailCtrl;
  final _formKey = GlobalKey<FormState>();

  bool   _loading    = false;
  bool   _enviado    = false;   // true cuando ya se envió el correo
  String _emailEnviado = '';

  int    _cooldown   = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _emailCtrl = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _timer?.cancel();
    super.dispose();
  }

  // ── Enviar correo de recuperación ─────────────────────────────────────────
  Future<void> _enviar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    final email = _emailCtrl.text.trim();

    try {
      // ── Intento 1: correo con diseño MateTec vía Flask ──────────────────
      bool envioPorFlask = false;
      try {
        await IAService.enviarReset(email: email);
        envioPorFlask = true;
      } catch (_) {
        // Flask no disponible → fallback a Firebase
      }

      // ── Fallback: Firebase (genérico, siempre funciona) ─────────────────
      if (!envioPorFlask) {
        await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      }

      if (!mounted) return;
      setState(() {
        _enviado      = true;
        _emailEnviado = email;
        _cooldown     = 60;
      });
      _iniciarCooldown();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      final msgs = {
        'user-not-found':         'No encontramos una cuenta con ese correo',
        'invalid-email':          'El correo no tiene un formato válido',
        'too-many-requests':      'Demasiados intentos, espera un momento',
        'network-request-failed': 'Sin conexión a internet',
      };
      _showSnack(msgs[e.code] ?? 'Error: ${e.code}');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _iniciarCooldown() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_cooldown > 0) _cooldown--;
      });
    });
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: AppColors.danger,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(12),
      duration: const Duration(seconds: 4),
    ));
  }

  // ── UI ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // ── Header rojo ───────────────────────────────────────────────
          Container(
            height: MediaQuery.of(context).size.height * 0.38,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFE53935), Color(0xFFC62828)],
              ),
            ),
          ),

          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Flecha atrás
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new,
                      color: Colors.white, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),

                // Ícono + título
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.lock_reset_rounded,
                            color: Colors.white, size: 28),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        _enviado
                            ? '¡Correo\nenviado!'
                            : 'Recuperar\ncontraseña',
                        style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _enviado
                            ? 'Revisa tu bandeja de entrada'
                            : 'Te enviaremos un enlace para restablecer tu contraseña',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ── Tarjeta blanca ────────────────────────────────────────
                Expanded(
                  child: Container(
                    decoration: const BoxDecoration(
                      color: AppColors.background,
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(32)),
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
                      child: _enviado
                          ? _buildSuccessView()
                          : _buildFormView(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Vista del formulario ──────────────────────────────────────────────────
  Widget _buildFormView() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('Correo electrónico'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Ingresa tu correo';
              if (!v.contains('@')) return 'Correo no válido';
              return null;
            },
            decoration: InputDecoration(
              hintText: 'ejemplo@correo.com',
              hintStyle:
                  TextStyle(color: AppColors.textMuted, fontSize: 14),
              prefixIcon: Icon(Icons.email_outlined,
                  size: 20, color: AppColors.textSecondary),
              filled: true,
              fillColor: AppColors.surfaceVariant,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    const BorderSide(color: AppColors.primary, width: 1.5),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    const BorderSide(color: AppColors.danger, width: 1.5),
              ),
            ),
          ),

          const SizedBox(height: 28),

          // Botón enviar
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _loading ? null : _enviar,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: _loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5),
                    )
                  : const Text(
                      'Enviar enlace de recuperación',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600),
                    ),
            ),
          ),

          const SizedBox(height: 20),

          Center(
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Text(
                '← Volver al inicio de sesión',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Vista de éxito ────────────────────────────────────────────────────────
  Widget _buildSuccessView() {
    return Column(
      children: [
        // Ícono de éxito
        Container(
          width: 90,
          height: 90,
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.mark_email_read_rounded,
              size: 44, color: Colors.green),
        ),
        const SizedBox(height: 20),

        // Correo al que se envió
        const Text(
          'Enviamos un enlace a:',
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 6),
        Text(
          _emailEnviado,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
          ),
        ),

        const SizedBox(height: 24),

        // Tips para encontrar el correo
        _TipCard(
          icon: Icons.warning_amber_rounded,
          color: Colors.orange,
          titulo: '¿No lo ves? Revisa spam',
          cuerpo:
              'Firebase envía desde una dirección automática que algunos '
              'correos marcan como spam o no deseado. Busca en esa carpeta.',
        ),
        const SizedBox(height: 10),
        _TipCard(
          icon: Icons.search,
          color: Colors.blue,
          titulo: 'Busca por remitente',
          cuerpo:
              'El correo viene de "noreply@..." — escribe "MateTec" o '
              '"firebase" en el buscador de tu bandeja para encontrarlo.',
        ),
        const SizedBox(height: 10),
        _TipCard(
          icon: Icons.timer_outlined,
          color: Colors.purple,
          titulo: 'El enlace expira en 1 hora',
          cuerpo:
              'Si no lo usas a tiempo, pide otro desde esta pantalla.',
        ),

        const SizedBox(height: 28),

        // Botón reenviar con cooldown
        SizedBox(
          width: double.infinity,
          height: 54,
          child: OutlinedButton.icon(
            onPressed: (_loading || _cooldown > 0) ? null : _enviar,
            style: OutlinedButton.styleFrom(
              side: BorderSide(
                color: _cooldown > 0
                    ? AppColors.border
                    : AppColors.textMuted,
                width: 1.5,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            icon: _loading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.primary))
                : Icon(
                    Icons.refresh_rounded,
                    color: _cooldown > 0
                        ? AppColors.textMuted
                        : AppColors.textSecondary,
                  ),
            label: Text(
              _cooldown > 0
                  ? 'Reenviar en ${_cooldown}s'
                  : 'Reenviar correo',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: _cooldown > 0
                    ? AppColors.textMuted
                    : AppColors.textSecondary,
              ),
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Botón volver al login
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
            child: const Text(
              'Volver al inicio de sesión',
              style:
                  TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }

  Widget _label(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
      );
}

// ── Tarjeta de tip ────────────────────────────────────────────────────────────
class _TipCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String titulo;
  final String cuerpo;

  const _TipCard({
    required this.icon,
    required this.color,
    required this.titulo,
    required this.cuerpo,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: color)),
                const SizedBox(height: 3),
                Text(cuerpo,
                    style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
