// lib/widgets/sync_indicator.dart
import 'package:flutter/material.dart';
import '../services/sync_service.dart';

/// Pequeño icono de nube en la esquina superior derecha del Home.
/// - Gris + X  → sin conexión (offline)
/// - Verde      → sincronizado (online / synced)
/// - Girando    → guardando datos en la nube (syncing)
class SyncIndicator extends StatefulWidget {
  const SyncIndicator({super.key});

  @override
  State<SyncIndicator> createState() => _SyncIndicatorState();
}

class _SyncIndicatorState extends State<SyncIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin;

  @override
  void initState() {
    super.initState();
    _spin = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    SyncService.stateNotifier.addListener(_onStateChange);
    _onStateChange(); // estado inicial
  }

  void _onStateChange() {
    if (!mounted) return;
    final state = SyncService.stateNotifier.value;
    if (state == SyncState.syncing) {
      _spin.repeat();
    } else {
      _spin.stop();
      _spin.reset();
    }
    setState(() {});
  }

  @override
  void dispose() {
    SyncService.stateNotifier.removeListener(_onStateChange);
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = SyncService.stateNotifier.value;

    Color color;
    IconData icon;
    String tooltip;

    switch (state) {
      case SyncState.offline:
        color   = Colors.grey.shade500;
        icon    = Icons.cloud_off_rounded;
        tooltip = 'Sin conexión — los datos se guardarán cuando vuelva internet';
        break;
      case SyncState.syncing:
        color   = const Color(0xFF1976D2);
        icon    = Icons.sync_rounded;
        tooltip = 'Guardando en la nube…';
        break;
      case SyncState.synced:
        color   = Colors.green.shade600;
        icon    = Icons.cloud_done_rounded;
        tooltip = '¡Datos guardados!';
        break;
      case SyncState.online:
      default:
        color   = Colors.green.shade400;
        icon    = Icons.cloud_rounded;
        tooltip = 'Conectado a la nube';
    }

    return Tooltip(
      message: tooltip,
      child: AnimatedBuilder(
        animation: _spin,
        builder: (_, child) {
          return Transform.rotate(
            angle: state == SyncState.syncing
                ? _spin.value * 2 * 3.14159
                : 0,
            child: child,
          );
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
      ),
    );
  }
}
