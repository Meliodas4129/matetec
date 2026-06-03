import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';
import '../services/local_storage_service.dart';
import '../services/sound_service.dart';
import '../widgets/avatar_view.dart';

/// Tienda: gasta los puntos ganados en avatares, marcos e insignias.
/// Recibe los datos ya leídos por HomeScreen; al comprar/equipar escribe en
/// Firestore (o local si es invitado) y el StreamBuilder del Home refresca solo.
class TiendaTab extends StatelessWidget {
  final int puntos;
  final List<String> comprados;
  final String avatar; // emoji equipado
  final String marco; // id del marco equipado
  final String insignia; // id de la insignia equipada
  final bool isGuest;
  final String nombre;

  const TiendaTab({
    super.key,
    required this.puntos,
    required this.comprados,
    required this.avatar,
    required this.marco,
    required this.insignia,
    required this.isGuest,
    required this.nombre,
  });

  // ── Persistencia ───────────────────────────────────────────────────────────
  Future<void> _persist(Map<String, dynamic> updates) async {
    if (isGuest) {
      await LocalStorageService.updateFields(updates);
      return;
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .update(updates);
  }

  String _campoDe(ItemTienda it) =>
      it.tipo == 'avatar' ? 'avatar' : it.tipo; // 'avatar'|'marco'|'insignia'

  String _valorDe(ItemTienda it) => it.tipo == 'avatar' ? it.emoji : it.id;

  bool _equipado(ItemTienda it) {
    switch (it.tipo) {
      case 'avatar':
        return avatar == it.emoji;
      case 'marco':
        return marco == it.id;
      default:
        return insignia == it.id;
    }
  }

  void _snack(BuildContext ctx, String msg) {
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _comprar(BuildContext ctx, ItemTienda it) async {
    if (comprados.contains(it.id)) return;
    if (puntos < it.precio) {
      _snack(ctx, 'Te faltan ${it.precio - puntos} puntos ⭐');
      return;
    }
    await _persist({
      'puntos': puntos - it.precio,
      'comprados': [...comprados, it.id],
      _campoDe(it): _valorDe(it), // se equipa automáticamente al comprar
    });
    SoundService.compra();
    if (ctx.mounted) _snack(ctx, '¡Comprado y equipado! 🎉');
  }

  Future<void> _equipar(ItemTienda it) async {
    await _persist({_campoDe(it): _equipado(it) ? '' : _valorDe(it)});
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Encabezado: preview + puntos ──────────────────────────────────
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                AvatarView(
                  avatar: avatar,
                  marco: marco,
                  insignia: insignia,
                  radius: 34,
                  fallback: nombre.isNotEmpty
                      ? nombre.substring(0, 1).toUpperCase()
                      : '?',
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Tu personalización',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.star_rounded,
                              color: Colors.amber.shade600, size: 22),
                          const SizedBox(width: 6),
                          Text(
                            '$puntos puntos',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          _seccion(context, '🧑‍🚀 Avatares', avataresTienda),
          _seccion(context, '🖼️ Marcos', marcosTienda),
          _seccion(context, '🏅 Insignias', insigniasTienda),
        ],
      ),
    );
  }

  Widget _seccion(BuildContext context, String titulo, List<ItemTienda> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titulo,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.82,
          children: items.map((it) => _card(context, it)).toList(),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _card(BuildContext context, ItemTienda it) {
    final comprado = comprados.contains(it.id);
    final equipado = _equipado(it);
    final alcanza = puntos >= it.precio;

    // Vista previa del item
    Widget preview;
    if (it.tipo == 'marco') {
      preview = Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFFFFCDD2),
          border: Border.all(color: it.color, width: 4),
        ),
        alignment: Alignment.center,
        child: Text(avatar.isNotEmpty ? avatar : '🙂',
            style: const TextStyle(fontSize: 26)),
      );
    } else {
      preview = Container(
        width: 58,
        height: 58,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0xFFFFCDD2),
        ),
        alignment: Alignment.center,
        child: Text(it.emoji, style: const TextStyle(fontSize: 30)),
      );
    }

    // Botón según estado
    Widget boton;
    if (!comprado) {
      boton = SizedBox(
        width: double.infinity,
        height: 36,
        child: ElevatedButton(
          onPressed: () => _comprar(context, it),
          style: ElevatedButton.styleFrom(
            backgroundColor: alcanza ? AppColors.primary : AppColors.border,
            foregroundColor: alcanza ? Colors.white : AppColors.textMuted,
            elevation: 0,
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: Text(
            '⭐ ${it.precio}',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ),
      );
    } else if (equipado) {
      boton = SizedBox(
        width: double.infinity,
        height: 36,
        child: OutlinedButton(
          onPressed: () => _equipar(it), // toca para quitar
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.success,
            side: const BorderSide(color: AppColors.success),
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: const Text('✓ Equipado',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
        ),
      );
    } else {
      boton = SizedBox(
        width: double.infinity,
        height: 36,
        child: OutlinedButton(
          onPressed: () => _equipar(it),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textPrimary,
            side: const BorderSide(color: AppColors.border),
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: const Text('Equipar',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: equipado ? AppColors.success : AppColors.border,
          width: equipado ? 1.5 : 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          preview,
          boton,
        ],
      ),
    );
  }
}
