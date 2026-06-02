import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

class PerfilEditableScreen extends StatefulWidget {
  final String nombre;
  final String email;
  final String? ciudad;
  final String? fotoUrl;

  const PerfilEditableScreen({
    super.key,
    required this.nombre,
    required this.email,
    this.ciudad,
    this.fotoUrl,
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

  @override
  void initState() {
    super.initState();
    _nombreCtrl = TextEditingController(text: widget.nombre);
    _ciudadCtrl = TextEditingController(text: widget.ciudad ?? '');
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

      // Actualizar en Firestore
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'nombre': _nombreCtrl.text.trim(),
        'ciudad': _ciudadCtrl.text.trim(),
        'ultimaActualizacion': FieldValue.serverTimestamp(),
      });

      // Actualizar displayName en Firebase Auth
      await user.updateDisplayName(_nombreCtrl.text.trim());

      setState(() {
        _mensaje = '✅ Perfil actualizado correctamente';
        _exito = true;
      });

      // Cerrar después de 2 segundos
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        Navigator.pop(context, true); // Retorna true para refrescar datos
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

  void _mostrarDialogoFoto() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('📸 Cambiar Foto'),
        content: const Text('¿De dónde quieres subir tu foto?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _seleccionarFoto(ImageSource.gallery);
            },
            child: const Text('📱 Galería'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _seleccionarFoto(ImageSource.camera);
            },
            child: const Text('📷 Cámara'),
          ),
        ],
      ),
    );
  }

  Future<void> _seleccionarFoto(ImageSource source) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? photo = await picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 512,
        maxHeight: 512,
      );

      if (photo == null) return;

      setState(() {
        _guardando = true;
        _mensaje = '⬆️ Subiendo foto...';
        _exito = false;
      });

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('Usuario no autenticado');
      }

      // Subir a Firebase Storage
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('perfiles/${user.uid}/foto.jpg');

      final bytes = await photo.readAsBytes();
      await storageRef.putData(bytes);

      // Obtener URL de descarga
      final url = await storageRef.getDownloadURL();

      // Actualizar en Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({'fotoUrl': url});

      setState(() {
        _mensaje = '✅ Foto actualizada correctamente';
        _exito = true;
      });

      // Cerrar después de 2 segundos
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
            // FOTO DE PERFIL
            Center(
              child: GestureDetector(
                onTap: _mostrarDialogoFoto,
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundColor: const Color(0xFFFFCDD2),
                      child: widget.fotoUrl != null &&
                              widget.fotoUrl!.isNotEmpty
                          ? ClipOval(
                              child: Image.network(
                                widget.fotoUrl!,
                                fit: BoxFit.cover,
                                width: 120,
                                height: 120,
                                errorBuilder: (context, error, stackTrace) {
                                  return const Icon(
                                    Icons.person,
                                    size: 60,
                                    color: Color(0xFFB71C1C),
                                  );
                                },
                              ),
                            )
                          : Icon(
                              Icons.person,
                              size: 60,
                              color: const Color(0xFFB71C1C),
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
                          Icons.camera_alt,
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
              'Toca para cambiar foto',
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
