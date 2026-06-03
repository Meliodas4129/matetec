import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Avatares disponibles (emojis). No necesitan Firebase Storage:
/// se guarda solo el emoji elegido en Firestore (gratis).
const List<String> kAvatares = [
  '🦊', '🐼', '🐶', '🐱',
  '🦁', '🐵', '🐸', '🦄',
  '🐯', '🐨', '🐰', '🐧',
  '🐙', '🐢', '🐝', '🦉',
];

class PerfilEditableScreen extends StatefulWidget {
  final String nombre;
  final String email;
  final String? ciudad;
  final String? avatar;

  const PerfilEditableScreen({
    super.key,
    required this.nombre,
    required this.email,
    this.ciudad,
    this.avatar,
  });

  @override
  State<PerfilEditableScreen> createState() => _PerfilEditableScreenState();
}

class _PerfilEditableScreenState extends State<PerfilEditableScreen> {
  late TextEditingController _nombreCtrl;
  late TextEditingController _ciudadCtrl;
  bool _guardando = false;
  String? _mensaje;
  bool _exito = false;
  String? _avatar; // emoji elegido

  @override
  void initState() {
    super.initState();
    _nombreCtrl = TextEditingController(text: widget.nombre);
    _ciudadCtrl = TextEditingController(text: widget.ciudad ?? '');
    _avatar = widget.avatar;
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _ciudadCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardarCambios() async {
    if (_nombreCtrl.text.trim().isEmpty) {
      setState(() {
        _mensaje = '❌ El nombre no puede estar vacío';
        _exito = false;
      });
      return;
    }

    setState(() {
      _guardando = true;
      _mensaje = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('Usuario no autenticado');
      }

      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'nombre': _nombreCtrl.text.trim(),
        'ciudad': _ciudadCtrl.text.trim(),
        'ultimaActualizacion': FieldValue.serverTimestamp(),
      });

      await user.updateDisplayName(_nombreCtrl.text.trim());

      setState(() {
        _mensaje = '✅ Perfil actualizado correctamente';
        _exito = true;
      });

      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() {
        _mensaje = '❌ Error: ${e.toString()}';
        _exito = false;
      });
    } finally {
      if (mounted) {
        setState(() => _guardando = false);
      }
    }
  }

  // ── Selector de avatar (bottom sheet) ──────────────────────────────────────
  void _elegirAvatar() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade700,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Elige tu avatar',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 18),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 4,
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              children: kAvatares.map((emoji) {
                final seleccionado = emoji == _avatar;
                return GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    _guardarAvatar(emoji);
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFCDD2),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: seleccionado
                            ? const Color(0xFFE53935)
                            : Colors.transparent,
                        width: 3,
                      ),
                    ),
                    child: Center(
                      child: Text(emoji, style: const TextStyle(fontSize: 30)),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _guardarAvatar(String emoji) async {
    setState(() {
      _avatar = emoji;
      _mensaje = null;
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return; // invitado: solo vista previa

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({'avatar': emoji});
      setState(() {
        _mensaje = '✅ Avatar actualizado';
        _exito = true;
      });
    } catch (e) {
      setState(() {
        _mensaje = '❌ No se pudo guardar el avatar: ${e.toString()}';
        _exito = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar Perfil'),
        backgroundColor: const Color(0xFFE53935),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // AVATAR
            Center(
              child: GestureDetector(
                onTap: _elegirAvatar,
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundColor: const Color(0xFFFFCDD2),
                      child: _avatar != null && _avatar!.isNotEmpty
                          ? Text(
                              _avatar!,
                              style: const TextStyle(fontSize: 56),
                            )
                          : Text(
                              widget.nombre.isNotEmpty
                                  ? widget.nombre.substring(0, 1).toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                fontSize: 48,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFB71C1C),
                              ),
                            ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFE53935),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 4,
                            )
                          ],
                        ),
                        padding: const EdgeInsets.all(8),
                        child: const Icon(
                          Icons.edit,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Toca para elegir avatar',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 32),

            // CAMPO: NOMBRE
            TextField(
              controller: _nombreCtrl,
              decoration: InputDecoration(
                labelText: 'Nombre',
                hintText: 'Tu nombre completo',
                prefixIcon: const Icon(Icons.person, color: Color(0xFFE53935)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.grey, width: 1),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFFE53935),
                    width: 2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // CAMPO: CIUDAD
            TextField(
              controller: _ciudadCtrl,
              decoration: InputDecoration(
                labelText: 'Ciudad/Estado',
                hintText: 'Tu ciudad (opcional)',
                prefixIcon: const Icon(Icons.location_on, color: Color(0xFFE53935)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.grey, width: 1),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFFE53935),
                    width: 2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // EMAIL (NO EDITABLE)
            TextField(
              controller: TextEditingController(text: widget.email),
              enabled: false,
              decoration: InputDecoration(
                labelText: 'Correo Electrónico',
                prefixIcon: const Icon(Icons.email, color: Colors.grey),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.grey, width: 1),
                ),
                disabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.grey, width: 1),
                ),
              ),
            ),
            const SizedBox(height: 32),

            // MENSAJE DE ESTADO
            if (_mensaje != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _exito
                      ? Colors.green.withOpacity(0.1)
                      : Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _exito ? Colors.green : Colors.red,
                    width: 1,
                  ),
                ),
                child: Text(
                  _mensaje!,
                  style: TextStyle(
                    color: _exito ? Colors.green : Colors.red,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            if (_mensaje != null) const SizedBox(height: 20),

            // BOTÓN GUARDAR
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                onPressed: _guardando ? null : _guardarCambios,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE53935),
                  disabledBackgroundColor: Colors.grey,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: _guardando
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.save),
                label: Text(
                  _guardando ? 'Guardando...' : 'Guardar Cambios',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // BOTÓN CANCELAR
            SizedBox(
              width: double.infinity,
              height: 54,
              child: OutlinedButton(
                onPressed: _guardando ? null : () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Cancelar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
