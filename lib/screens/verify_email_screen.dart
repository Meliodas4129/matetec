// lib/screens/verify_email_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';
import '../services/ia_service.dart';
import 'login_screen.dart';
import 'home_inicio.dart';
import 'diagnostico_screen.dart';

class VerifyEmailScreen extends StatefulWidget {
  /// El correo al que se envió la verificación (solo para mostrarlo).
  final String email;

  /// Nombre del alumno — se usa en el asunto del correo personalizado.
  final String nombre;

  const VerifyEmailScreen({
    super.key,
    required this.email,
    this.nombre = '',
  });

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  bool _enviando    = false;
  bool _verificando = false;
  bool _reenviado   = false;

  // Cuenta regresiva para no permitir reenviar cada segundo
  int  _segundosCooldown = 0;
  Timer? _cooldownTimer;

  // Revisión automática cada 4 segundos
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    // Verificar automáticamente en segundo plano
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) => _comprobarVerificacion(silencioso: true));
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  // ── Reenviar correo de verificación ──────────────────────────────────────
  Future<void> _reenviar() async {
    if (_segundosCooldown > 0 || _enviando) return;
    setState(() => _enviando = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) { _volverAlLogin(); return; }

      // ── Intento 1: correo con diseño MateTec vía Flask ────────────────────
      bool envioPorFlask = false;
      try {
        final nombre = widget.nombre.isNotEmpty
            ? widget.nombre
            : (user.displayName ?? widget.email.split('@').first);
        await IAService.enviarVerificacion(
          email:  widget.email,
          nombre: nombre,
        );
        envioPorFlask = true;
      } catch (_) {
        // Flask no disponible → fallback a Firebase
      }

      // ── Fallback: correo de Firebase (genérico pero siempre funciona) ─────
      if (!envioPorFlask) {
        await user.sendEmailVerification();
      }

      if (!mounted) return;
      setState(() {
        _reenviado        = true;
        _segundosCooldown = 60;
      });
      _iniciarCooldown();
      _showSnack('Correo enviado a ${widget.email} 📩', isError: false);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      _showSnack(e.code == 'too-many-requests'
          ? 'Espera un momento antes de reenviar'
          : 'Error al enviar: ${e.code}');
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  void _iniciarCooldown() {
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_segundosCooldown > 0) {
          _segundosCooldown--;
        } else {
          _cooldownTimer?.cancel();
        }
      });
    });
  }

  // ── Comprobar si ya verificó ──────────────────────────────────────────────
  Future<void> _comprobarVerificacion({bool silencioso = false}) async {
    if (_verificando) return;
    setState(() => _verificando = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) { _volverAlLogin(); return; }

      // Forzar actualización del token para leer el estado real de Firebase
      await user.reload();
      final fresh = FirebaseAuth.instance.currentUser;

      if (fresh == null) { _volverAlLogin(); return; }

      if (fresh.emailVerified) {
        _pollTimer?.cancel();
        if (!mounted) return;

        // Comprobar si ya tiene diagnóstico
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(fresh.uid)
            .get();
        final docData = doc.data() ?? {};
        final grado = (docData['grado'] ?? 'Pendiente') as String;
        final rol   = (docData['rol']   ?? 'estudiante') as String;

        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            // Admins no necesitan diagnóstico → home directo
            builder: (_) => (rol != 'admin' && (grado == 'Pendiente' || grado.isEmpty))
                ? const DiagnosticoScreen()
                : const HomeScreen(),
          ),
          (route) => false,
        );
      } else if (!silencioso) {
        _showSnack('Aún no verificaste el correo. Revisa tu bandeja de entrada.');
      }
    } catch (e) {
      if (!silencioso && mounted) {
        _showSnack('Error al comprobar verificación');
      }
    } finally {
      if (mounted) setState(() => _verificando = false);
    }
  }

  void _volverAlLogin() {
    FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  void _showSnack(String msg, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? AppColors.danger : AppColors.success,
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
          // Header rojo
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
              children: [
                // Flecha atrás → volver al login
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new,
                        color: Colors.white, size: 20),
                    onPressed: _volverAlLogin,
                  ),
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
                        child: const Icon(Icons.mark_email_unread_rounded,
                            color: Colors.white, size: 28),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Verifica\ntu correo',
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Revisa tu bandeja de entrada',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Tarjeta blanca
                Expanded(
                  child: Container(
                    decoration: const BoxDecoration(
                      color: AppColors.background,
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(32)),
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
                      child: Column(
                        children: [
                          // Ilustración
                          Container(
                            width: 90,
                            height: 90,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.08),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.email_outlined,
                              size: 44,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Mensaje
                          const Text(
                            'Te enviamos un enlace de verificación a:',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.email,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Haz clic en el enlace del correo para activar tu cuenta. '
                            'Si no lo ves, revisa tu carpeta de spam.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                              height: 1.5,
                            ),
                          ),

                          const SizedBox(height: 32),

                          // Botón principal: Ya verifiqué
                          SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: ElevatedButton(
                              onPressed: _verificando
                                  ? null
                                  : () => _comprobarVerificacion(),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 0,
                              ),
                              child: _verificando
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                          color: Colors.white, strokeWidth: 2.5),
                                    )
                                  : const Text(
                                      'Ya verifiqué mi correo',
                                      style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600),
                                    ),
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Botón secundario: Reenviar
                          SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: OutlinedButton(
                              onPressed: (_enviando || _segundosCooldown > 0)
                                  ? null
                                  : _reenviar,
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                    color: AppColors.border, width: 1.5),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: _enviando
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          color: AppColors.primary),
                                    )
                                  : Text(
                                      _segundosCooldown > 0
                                          ? 'Reenviar en ${_segundosCooldown}s'
                                          : _reenviado
                                              ? 'Reenviar correo'
                                              : 'Reenviar correo de verificación',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500,
                                        color: _segundosCooldown > 0
                                            ? AppColors.textMuted
                                            : AppColors.textSecondary,
                                      ),
                                    ),
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Link: Usar otro correo
                          GestureDetector(
                            onTap: _volverAlLogin,
                            child: Text(
                              '← Usar otro correo o cuenta',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),

                          // Verificación automática en curso
                          const SizedBox(height: 28),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                  strokeWidth: 1.5,
                                  color: AppColors.textMuted,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Verificando automáticamente…',
                                style: TextStyle(
                                    fontSize: 11, color: AppColors.textMuted),
                              ),
                            ],
                          ),
                        ],
                      ),
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
}
