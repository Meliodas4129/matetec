// lib/screens/admin_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  String _busqueda = '';
  String _filtroRol = 'todos';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text(
          'Panel de administrador',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          // Filtro de rol
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: DropdownButton<String>(
              value: _filtroRol,
              underline: const SizedBox(),
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
              items: const [
                DropdownMenuItem(value: 'todos',      child: Text('Todos')),
                DropdownMenuItem(value: 'estudiante', child: Text('Estudiantes')),
                DropdownMenuItem(value: 'admin',      child: Text('Admins')),
              ],
              onChanged: (v) => setState(() => _filtroRol = v!),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Buscador ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: TextField(
              onChanged: (v) => setState(() => _busqueda = v.toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Buscar por nombre o correo…',
                hintStyle: TextStyle(fontSize: 13, color: AppColors.textMuted),
                prefixIcon: Icon(Icons.search, size: 20, color: AppColors.textSecondary),
                filled: true,
                fillColor: AppColors.surfaceVariant,
                contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
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
            ),
          ),

          // ── Lista de usuarios ─────────────────────────────────────────────
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text('Sin usuarios registrados',
                        style: TextStyle(color: AppColors.textSecondary)),
                  );
                }

                // Filtrar por rol y búsqueda
                final docs = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final nombre = (data['nombre'] ?? '').toString().toLowerCase();
                  final email  = (data['email']  ?? '').toString().toLowerCase();
                  final rol    = (data['rol']    ?? 'estudiante').toString();

                  final matchBusqueda = _busqueda.isEmpty ||
                      nombre.contains(_busqueda) ||
                      email.contains(_busqueda);
                  final matchRol = _filtroRol == 'todos' || rol == _filtroRol;

                  return matchBusqueda && matchRol;
                }).toList();

                if (docs.isEmpty) {
                  return const Center(
                    child: Text('Sin resultados',
                        style: TextStyle(color: AppColors.textSecondary)),
                  );
                }

                return Column(
                  children: [
                    // Contador
                    Padding(
                      padding: const EdgeInsets.only(left: 16, bottom: 8),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '${docs.length} usuario${docs.length != 1 ? 's' : ''}',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        itemCount: docs.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, i) {
                          final data = docs[i].data() as Map<String, dynamic>;
                          return _UserCard(data: data, docId: docs[i].id);
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tarjeta de usuario ────────────────────────────────────────────────────────
class _UserCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final String docId;
  const _UserCard({required this.data, required this.docId});

  @override
  Widget build(BuildContext context) {
    final nombre      = data['nombre']       ?? 'Sin nombre';
    final email       = data['email']        ?? '';
    final grado       = data['grado']        ?? 'Sin nivel';
    final gradoEsc    = data['grado_escolar'] ?? '';
    final rol         = data['rol']          ?? 'estudiante';
    final aciertos    = data['aciertos']     ?? 0;
    final intentos    = data['intentos']     ?? 0;
    final racha       = data['racha']        ?? 0;
    final puntos      = data['puntos']       ?? 0;
    final pct         = intentos > 0 ? (aciertos / intentos * 100).toStringAsFixed(0) : '—';
    final bloqueado   = data['bloqueado']    ?? false;

    final isAdmin = rol == 'admin';
    final initial = nombre.isNotEmpty ? nombre[0].toUpperCase() : '?';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bloqueado ? Colors.grey.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: bloqueado
              ? AppColors.border
              : isAdmin
                  ? AppColors.primary.withValues(alpha: 0.4)
                  : AppColors.border,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          CircleAvatar(
            radius: 22,
            backgroundColor: isAdmin
                ? AppColors.primary.withValues(alpha: 0.15)
                : const Color(0xFFFFCDD2),
            child: Text(
              initial,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: isAdmin ? AppColors.primary : AppColors.danger,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Datos
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        nombre,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    // Chip de rol
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: isAdmin
                            ? AppColors.primary.withValues(alpha: 0.12)
                            : const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        isAdmin ? 'Admin' : 'Estudiante',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isAdmin ? AppColors.primary : Colors.green.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  email,
                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 6),
                // Nivel AI + grado escolar
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _Tag(grado, color: AppColors.primary),
                    if (gradoEsc.isNotEmpty) _Tag(gradoEsc, color: Colors.indigo),
                  ],
                ),
                const SizedBox(height: 8),
                // Estadísticas
                Row(
                  children: [
                    _Stat(Icons.check_circle_outline, '$aciertos', 'aciertos',
                        AppColors.success),
                    const SizedBox(width: 12),
                    _Stat(Icons.local_fire_department_outlined, '$racha', 'racha',
                        Colors.orange),
                    const SizedBox(width: 12),
                    _Stat(Icons.star_outline, '$puntos', 'pts',
                        Colors.amber.shade700),
                    const SizedBox(width: 12),
                    _Stat(Icons.percent, pct, 'exactitud',
                        const Color(0xFF1E88E5)),
                  ],
                ),
              ],
            ),
          ),

          // Badge bloqueado + botón de opciones
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (bloqueado)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('Bloqueado',
                      style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary)),
                ),
              PopupMenuButton<String>(
                icon:
                    Icon(Icons.more_vert, size: 18, color: AppColors.textMuted),
                onSelected: (value) => _onAction(context, value),
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'admin',
                    child: Row(children: [
                      Icon(Icons.admin_panel_settings_outlined,
                          size: 16,
                          color: isAdmin ? Colors.grey : AppColors.primary),
                      const SizedBox(width: 8),
                      Text(isAdmin ? 'Quitar admin' : 'Hacer admin',
                          style: TextStyle(
                              fontSize: 13,
                              color:
                                  isAdmin ? Colors.grey : AppColors.primary)),
                    ]),
                  ),
                  PopupMenuItem(
                    value: 'bloquear',
                    child: Row(children: [
                      Icon(
                          bloqueado
                              ? Icons.lock_open_rounded
                              : Icons.block_rounded,
                          size: 16,
                          color: bloqueado ? Colors.green : Colors.red),
                      const SizedBox(width: 8),
                      Text(bloqueado ? 'Desbloquear' : 'Bloquear',
                          style: TextStyle(
                              fontSize: 13,
                              color: bloqueado ? Colors.green : Colors.red)),
                    ]),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _onAction(BuildContext context, String action) async {
    final ref = FirebaseFirestore.instance.collection('users').doc(docId);

    if (action == 'admin') {
      final current = data['rol'] ?? 'estudiante';
      final nuevoRol = current == 'admin' ? 'estudiante' : 'admin';
      await ref.update({'rol': nuevoRol});
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(nuevoRol == 'admin'
              ? '${data['nombre']} ahora es administrador'
              : '${data['nombre']} ya no es administrador'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(12),
        ));
      }
    } else if (action == 'bloquear') {
      final estaBloqueado = data['bloqueado'] ?? false;
      final nuevoBloqueado = !estaBloqueado;

      // Confirmar antes de bloquear
      if (nuevoBloqueado && context.mounted) {
        final confirmar = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            title: const Text('Bloquear cuenta',
                style:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            content: Text(
              '¿Bloquear la cuenta de ${data['nombre']}?\n'
              'No podrá iniciar sesión hasta que lo desbloquees.',
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar',
                    style: TextStyle(color: Colors.grey)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Bloquear',
                    style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        );
        if (confirmar != true) return;
      }

      await ref.update({'bloqueado': nuevoBloqueado});

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(nuevoBloqueado
              ? '${data['nombre']} ha sido bloqueado'
              : '${data['nombre']} ha sido desbloqueado'),
          backgroundColor: nuevoBloqueado ? Colors.red : AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(12),
        ));
      }
    }
  }
}

class _Tag extends StatelessWidget {
  final String label;
  final Color color;
  const _Tag(this.label, {required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  const _Stat(this.icon, this.value, this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 3),
        Text(
          '$value $label',
          style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
