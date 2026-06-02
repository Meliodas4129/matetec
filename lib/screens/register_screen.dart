// lib/screens/register_screen.dart
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../services/local_storage_service.dart';
import '../services/ia_service.dart';
import '../theme/app_theme.dart';
import 'verify_email_screen.dart';
import 'diagnostico_screen.dart';
import 'home_inicio.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  bool _loading = false;
  bool _obscurePass = true;

  // ── Grado escolar ─────────────────────────────────────────────────────────
  static const List<String> _gradosEscolares = [
    'Preescolar',
    '1° Primaria',
    '2° Primaria',
    '3° Primaria',
    '4° Primaria',
    '5° Primaria',
    '6° Primaria',
  ];
  String? _gradoEscolar;

  // ── Migrar datos del invitado a Firestore ────────────────────────────────
  Future<void> _migrarDatosInvitado(String uid) async {
    if (!LocalStorageService.hasGuestData) return;
    try {
      final guestData = LocalStorageService.getDataForMigration();
      // Solo migramos si el invitado ya completó el diagnóstico
      if ((guestData['grado_num'] ?? 0) > 0) {
        // Excluir campos de identidad para no sobreescribir el nombre/email real
        guestData.remove('nombre');
        guestData.remove('email');
        guestData.remove('rol');
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .update(guestData);
      }
      await LocalStorageService.clearGuestData();
    } catch (e) {
      debugPrint('Error migrando datos del invitado: $e');
    }
  }

  // ── Datos base nuevo usuario ──────────────────────────────────────────────
  Map<String, dynamic> _datosNuevo({
    required String nombre,
    required String email,
    String? gradoEscolar,
  }) =>
      {
        'nombre': nombre,
        'email': email,
        'grado_escolar': gradoEscolar ?? '',
        'grado': 'Pendiente',
        'grado_num': 0,
        'aciertos': 0,
        'errores': 0,
        'intentos': 0,
        'tiempo_total': 0,
        'temas': {
          'sumas': {
            'aciertos': 0,
            'intentos': 0,
            'eval_desde_intentos': 10,
            'eval_aprobada': false,
          },
          'restas': {
            'aciertos': 0,
            'intentos': 0,
            'eval_desde_intentos': 10,
            'eval_aprobada': false,
          },
          'multiplicacion': {
            'aciertos': 0,
            'intentos': 0,
            'eval_desde_intentos': 10,
            'eval_aprobada': false,
          },
          'division': {
            'aciertos': 0,
            'intentos': 0,
            'eval_desde_intentos': 10,
            'eval_aprobada': false,
          },
        },
        'temas_desbloqueados': ['sumas'],
        'racha': 0,
        'puntos': 0,
        'rol': email.toLowerCase().endsWith('@matetec.com') ? 'admin' : 'estudiante',
        'createdAt': FieldValue.serverTimestamp(),
      };

  // ── Registro con correo ───────────────────────────────────────────────────
  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    UserCredential? cred;
    try {
      cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text.trim(),
      );
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(cred.user!.uid)
            .set(_datosNuevo(
              nombre: _nombreCtrl.text.trim(),
              email: _emailCtrl.text.trim(),
              gradoEscolar: _gradoEscolar,
            ));
        // Fusionar progreso previo del invitado, si existía
        await _migrarDatosInvitado(cred.user!.uid);
      } catch (e) {
        await cred.user?.delete();
        rethrow;
      }

      // ── Enviar verificación de correo ─────────────────────────────────
      final email = cred.user!.email ?? _emailCtrl.text.trim();
      final esAdmin = email.toLowerCase().endsWith('@matetec.com');

      if (esAdmin) {
        // Los admins @matetec.com no necesitan verificar correo → home directo
        await LocalStorageService.endGuestSession();
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      } else {
        // ── Correo de verificación con diseño MateTec (Flask) ─────────────
        // Si Flask no está disponible, fallback a Firebase automáticamente.
        final nombre = _nombreCtrl.text.trim();
        bool envioPorFlask = false;
        try {
          await IAService.enviarVerificacion(email: email, nombre: nombre);
          envioPorFlask = true;
        } catch (_) {
          // Flask no disponible
        }
        if (!envioPorFlask) {
          await cred.user!.sendEmailVerification();
        }

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => VerifyEmailScreen(email: email, nombre: nombre),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      final msgs = {
        'email-already-in-use': 'Ese correo ya está registrado',
        'invalid-email': 'Correo inválido',
        'weak-password': 'La contraseña es muy débil',
        'network-request-failed': 'Sin conexión a internet',
      };
      _showSnack(msgs[e.code] ?? 'Error: ${e.code}');
    } catch (e) {
      _showSnack('Error al registrar, intenta de nuevo');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Google Sign-In ────────────────────────────────────────────────────────
  Future<void> _signInWithGoogle() async {
    setState(() => _loading = true);
    try {
      UserCredential userCredential;

      if (kIsWeb) {
        final provider = GoogleAuthProvider()
          ..addScope('email')
          ..addScope('profile')
          ..setCustomParameters({'prompt': 'select_account'});
        try {
          userCredential =
              await FirebaseAuth.instance.signInWithPopup(provider);
        } on FirebaseAuthException catch (e) {
          if (e.code == 'popup-blocked') {
            await FirebaseAuth.instance.signInWithRedirect(provider);
            return;
          }
          rethrow;
        }
      } else {
        // Limpiar credenciales en caché para evitar tokens obsoletos
        final googleSignIn =
            GoogleSignIn(scopes: ['email', 'profile']);
        try {
          await googleSignIn.signOut();
        } catch (_) {}

        final googleUser = await googleSignIn.signIn();
        if (googleUser == null) {
          if (mounted) setState(() => _loading = false);
          return;
        }
        final googleAuth = await googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        userCredential =
            await FirebaseAuth.instance.signInWithCredential(credential);
      }

      final user = userCredential.user!;
      final docRef =
          FirebaseFirestore.instance.collection('users').doc(user.uid);
      final doc = await docRef.get();

      bool esNuevo = false;
      if (!doc.exists) {
        await docRef.set(_datosNuevo(
          nombre: user.displayName ?? 'Usuario',
          email: user.email ?? '',
        ));
        await _migrarDatosInvitado(user.uid);
        esNuevo = true;
      }

      // Limpiar sesión de invitado si había una activa
      await LocalStorageService.endGuestSession();

      if (!mounted) return;
      final data = (await docRef.get()).data();
      final grado = (data?['grado'] ?? 'Pendiente') as String;
      final rol   = (data?['rol']   ?? 'estudiante') as String;
      // Admins @matetec.com → home directo, sin diagnóstico
      if (rol != 'admin' && (esNuevo || grado == 'Pendiente' || grado.isEmpty)) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const DiagnosticoScreen()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    } on FirebaseAuthException catch (e) {
      final msgs = {
        'popup-closed-by-user':     'Cerraste la ventana de Google',
        'cancelled-popup-request':  'Solicitud cancelada, intenta de nuevo',
        'popup-blocked':            'Popup bloqueado — permite popups para localhost',
        'unauthorized-domain':      'Dominio no autorizado en Firebase Console',
        'operation-not-allowed':    'Google Sign-In no está habilitado en Firebase',
        'account-exists-with-different-credential':
            'Ya existe una cuenta con ese correo',
        'network-request-failed':   'Sin conexión a internet',
      };
      final msg = msgs[e.code] ?? '[${e.code}] ${e.message ?? "sin detalle"}';
      _showSnack(msg, duration: const Duration(seconds: 6));
      debugPrint('GOOGLE REGISTER ERROR code=${e.code}  msg=${e.message}');
    } catch (e) {
      debugPrint('GOOGLE REGISTER ERROR: $e');
      final txt = e.toString();
      _showSnack(
        txt.length > 120 ? txt.substring(0, 120) : txt,
        duration: const Duration(seconds: 6),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showSnack(String msg, {bool isError = true, Duration duration = const Duration(seconds: 3)}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? AppColors.danger : AppColors.success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(12),
      duration: duration,
    ));
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  // ── UI ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // ── Header rojo ───────────────────────────────────────────────
          Container(
            height: MediaQuery.of(context).size.height * 0.36,
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
                // Flecha atrás
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new,
                        color: Colors.white, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),

                // Ícono + título en zona roja
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
                        child: const Icon(Icons.person_add_alt_1_rounded,
                            color: Colors.white, size: 28),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Crear\ntu cuenta',
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Empieza a aprender matemáticas hoy',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Tarjeta blanca con formulario
                Expanded(
                  child: Container(
                    decoration: const BoxDecoration(
                      color: AppColors.background,
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(32)),
                    ),
                    child: SingleChildScrollView(
                      padding:
                          const EdgeInsets.fromLTRB(28, 32, 28, 24),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ── Nombre ──────────────────────────────
                            _buildLabel('Nombre completo'),
                            const SizedBox(height: 8),
                            _buildField(
                              controller: _nombreCtrl,
                              hint: 'Tu nombre',
                              icon: Icons.person_outline,
                              validator: (v) =>
                                  v!.isEmpty ? 'Requerido' : null,
                            ),
                            const SizedBox(height: 18),

                            // ── Correo ───────────────────────────────
                            _buildLabel('Correo electrónico'),
                            const SizedBox(height: 8),
                            _buildField(
                              controller: _emailCtrl,
                              hint: 'ejemplo@correo.com',
                              icon: Icons.email_outlined,
                              keyboard: TextInputType.emailAddress,
                              validator: (v) => !v!.contains('@')
                                  ? 'Correo inválido'
                                  : null,
                            ),
                            const SizedBox(height: 18),

                            // ── Contraseña ───────────────────────────
                            _buildLabel('Contraseña'),
                            const SizedBox(height: 8),
                            _buildField(
                              controller: _passCtrl,
                              hint: 'Mínimo 6 caracteres',
                              icon: Icons.lock_outline,
                              obscure: _obscurePass,
                              validator: (v) => v!.length < 6
                                  ? 'Mínimo 6 caracteres'
                                  : null,
                              suffix: IconButton(
                                icon: Icon(
                                  _obscurePass
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  size: 20,
                                  color: AppColors.textSecondary,
                                ),
                                onPressed: () => setState(
                                    () => _obscurePass = !_obscurePass),
                              ),
                            ),

                            const SizedBox(height: 18),

                            // ── Grado escolar ────────────────────────
                            _buildLabel('Grado escolar'),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              value: _gradoEscolar,
                              decoration: InputDecoration(
                                hintText: 'Selecciona tu grado',
                                hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 14),
                                prefixIcon: Icon(Icons.school_outlined, size: 20, color: AppColors.textSecondary),
                                filled: true,
                                fillColor: AppColors.surfaceVariant,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
                                  borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                                ),
                              ),
                              items: _gradosEscolares.map((g) => DropdownMenuItem(
                                value: g,
                                child: Text(g, style: const TextStyle(fontSize: 15)),
                              )).toList(),
                              onChanged: _loading ? null : (v) => setState(() => _gradoEscolar = v),
                              // No obligatorio: el alumno puede omitirlo
                            ),

                            const SizedBox(height: 24),

                            // ── Botón crear cuenta ───────────────────
                            SizedBox(
                              width: double.infinity,
                              height: 54,
                              child: ElevatedButton(
                                onPressed: _loading ? null : _register,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(16),
                                  ),
                                  elevation: 0,
                                ),
                                child: _loading
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2.5,
                                        ),
                                      )
                                    : const Text(
                                        'Crear cuenta',
                                        style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600),
                                      ),
                              ),
                            ),

                            const SizedBox(height: 20),

                            // ── Divisor ──────────────────────────────
                            Row(
                              children: [
                                Expanded(
                                    child: Divider(
                                        color: AppColors.border)),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14),
                                  child: Text(
                                    'o',
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: AppColors.textSecondary),
                                  ),
                                ),
                                Expanded(
                                    child: Divider(
                                        color: AppColors.border)),
                              ],
                            ),

                            const SizedBox(height: 16),

                            // ── Botón Google ─────────────────────────
                            _GoogleButton(
                              onPressed:
                                  _loading ? null : _signInWithGoogle,
                              loading: _loading,
                            ),

                            const SizedBox(height: 24),

                            // ── Link login ───────────────────────────
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.center,
                              children: [
                                Text(
                                  '¿Ya tienes cuenta? ',
                                  style: TextStyle(
                                      fontSize: 14,
                                      color: AppColors.textSecondary),
                                ),
                                GestureDetector(
                                  onTap: _loading
                                      ? null
                                      : () => Navigator.pop(context),
                                  child: const Text(
                                    'Inicia sesión',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primary,
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
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
      );

  Widget _buildField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboard = TextInputType.text,
    bool obscure = false,
    Widget? suffix,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboard,
      validator: validator,
      style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 14),
        prefixIcon: Icon(icon, size: 20, color: AppColors.textSecondary),
        suffixIcon: suffix,
        filled: true,
        fillColor: AppColors.surfaceVariant,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              const BorderSide(color: AppColors.danger, width: 1.5),
        ),
      ),
    );
  }
}

// ── Botón Google ──────────────────────────────────────────────────────────────
class _GoogleButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool loading;
  const _GoogleButton({required this.onPressed, this.loading = false});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.textSecondary,
          side: BorderSide(color: AppColors.border, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5, color: AppColors.primary),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _GoogleLogo(),
                  const SizedBox(width: 12),
                  const Text(
                    'Continuar con Google',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary),
                  ),
                ],
              ),
      ),
    );
  }
}

class _GoogleLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.border),
        color: Colors.white,
      ),
      child: const Center(
        child: Text(
          'G',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w900,
            color: Color(0xFF4285F4),
            height: 1,
          ),
        ),
      ),
    );
  }
}
