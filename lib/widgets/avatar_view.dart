import 'package:flutter/material.dart';

/// Un artículo de la tienda (avatar premium, marco/borde o insignia).
class ItemTienda {
  final String id; // identificador único, ej. 'av_dragon', 'marco_oro'
  final String tipo; // 'avatar' | 'marco' | 'insignia'
  final String emoji; // visual del avatar/insignia; '' para marcos
  final int precio; // costo en puntos
  final Color color; // color del borde (solo marcos)

  const ItemTienda({
    required this.id,
    required this.tipo,
    this.emoji = '',
    required this.precio,
    this.color = Colors.transparent,
  });
}

// ── Catálogo ────────────────────────────────────────────────────────────────
// Los avatares GRATIS están en kAvatares (perfil_editable_screen.dart).
// Estos son los que se compran con puntos.
const List<ItemTienda> avataresTienda = [
  ItemTienda(id: 'av_dragon', tipo: 'avatar', emoji: '🐉', precio: 200),
  ItemTienda(id: 'av_robot', tipo: 'avatar', emoji: '🤖', precio: 150),
  ItemTienda(id: 'av_alien', tipo: 'avatar', emoji: '👽', precio: 150),
  ItemTienda(id: 'av_dino', tipo: 'avatar', emoji: '🦖', precio: 250),
  ItemTienda(id: 'av_rey', tipo: 'avatar', emoji: '🤴', precio: 300),
  ItemTienda(id: 'av_aguila', tipo: 'avatar', emoji: '🦅', precio: 200),
  ItemTienda(id: 'av_tiburon', tipo: 'avatar', emoji: '🦈', precio: 220),
  ItemTienda(id: 'av_unicornio', tipo: 'avatar', emoji: '🦓', precio: 350),
];

const List<ItemTienda> marcosTienda = [
  ItemTienda(id: 'marco_rojo', tipo: 'marco', precio: 100, color: Color(0xFFE53935)),
  ItemTienda(id: 'marco_azul', tipo: 'marco', precio: 150, color: Color(0xFF2979FF)),
  ItemTienda(id: 'marco_oro', tipo: 'marco', precio: 250, color: Color(0xFFFFC107)),
  ItemTienda(id: 'marco_neon', tipo: 'marco', precio: 280, color: Color(0xFF00E676)),
  ItemTienda(id: 'marco_morado', tipo: 'marco', precio: 320, color: Color(0xFF8E24AA)),
];

const List<ItemTienda> insigniasTienda = [
  ItemTienda(id: 'ins_estrella', tipo: 'insignia', emoji: '⭐', precio: 100),
  ItemTienda(id: 'ins_rayo', tipo: 'insignia', emoji: '⚡', precio: 120),
  ItemTienda(id: 'ins_fuego', tipo: 'insignia', emoji: '🔥', precio: 150),
  ItemTienda(id: 'ins_corona', tipo: 'insignia', emoji: '👑', precio: 200),
  ItemTienda(id: 'ins_trofeo', tipo: 'insignia', emoji: '🏆', precio: 250),
  ItemTienda(id: 'ins_diamante', tipo: 'insignia', emoji: '💎', precio: 300),
];

/// Color del borde según el id del marco equipado (null = sin marco).
Color? marcoColor(String id) {
  for (final m in marcosTienda) {
    if (m.id == id) return m.color;
  }
  return null;
}

/// Emoji de la insignia equipada según su id ('' = sin insignia).
String insigniaEmoji(String id) {
  for (final i in insigniasTienda) {
    if (i.id == id) return i.emoji;
  }
  return '';
}

/// Dibuja el avatar con su marco (borde) e insignia equipados.
/// Reutilizable en Inicio, Perfil, edición de perfil y la tienda.
class AvatarView extends StatelessWidget {
  final String avatar; // emoji equipado
  final String marco; // id del marco o ''
  final String insignia; // id de la insignia o ''
  final double radius; // radio del círculo
  final String fallback; // texto si no hay avatar (ej. inicial del nombre)

  const AvatarView({
    super.key,
    required this.avatar,
    this.marco = '',
    this.insignia = '',
    this.radius = 28,
    this.fallback = '?',
  });

  @override
  Widget build(BuildContext context) {
    final borde = marcoColor(marco);
    final ins = insigniaEmoji(insignia);
    final size = radius * 2;
    final outer = size + 10; // espacio para borde e insignia

    return SizedBox(
      width: outer,
      height: outer,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFFFCDD2),
              border: borde != null ? Border.all(color: borde, width: 3.5) : null,
            ),
            alignment: Alignment.center,
            child: avatar.isNotEmpty
                ? Text(avatar, style: TextStyle(fontSize: radius * 1.05))
                : Text(
                    fallback,
                    style: TextStyle(
                      fontSize: radius * 0.85,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFB71C1C),
                    ),
                  ),
          ),
          if (ins.isNotEmpty)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Text(ins, style: TextStyle(fontSize: radius * 0.5)),
              ),
            ),
        ],
      ),
    );
  }
}
