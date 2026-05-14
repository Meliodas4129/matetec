// lib/services/sync_service.dart
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

enum SyncState { offline, online, syncing, synced }

/// Servicio global que rastrea el estado de sincronización con la nube.
///
/// Uso:
///   SyncService.notify(SyncState.syncing);   // antes de escribir en Firestore
///   SyncService.notify(SyncState.synced);    // después de escribir
class SyncService {
  SyncService._();

  static final ValueNotifier<SyncState> stateNotifier =
      ValueNotifier(SyncState.online);

  static bool _initialized = false;

  /// Llama esto una sola vez en main() para escuchar cambios de conectividad.
  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    // Estado inicial
    final result = await Connectivity().checkConnectivity();
    _applyConnectivity(result);

    // Escuchar cambios en tiempo real
    Connectivity().onConnectivityChanged.listen((results) {
      _applyConnectivity(results);
    });
  }

  static void _applyConnectivity(List<ConnectivityResult> results) {
    final isOnline = results.any((r) => r != ConnectivityResult.none);
    if (!isOnline) {
      stateNotifier.value = SyncState.offline;
    } else if (stateNotifier.value == SyncState.offline) {
      stateNotifier.value = SyncState.online;
    }
  }

  /// Notifica un cambio de estado manualmente (p.ej. al guardar en Firestore).
  static void notify(SyncState state) {
    stateNotifier.value = state;
  }

  /// Wrapper de conveniencia: envuelve una operación async y
  /// actualiza el estado de sincronización automáticamente.
  static Future<T> wrap<T>(Future<T> Function() operation) async {
    if (stateNotifier.value == SyncState.offline) {
      return operation(); // offline: Firestore guarda en caché, no animamos
    }
    notify(SyncState.syncing);
    try {
      final result = await operation();
      notify(SyncState.synced);
      // Volver a "online" pasados 2s para que el usuario vea el check
      Future.delayed(const Duration(seconds: 2), () {
        if (stateNotifier.value == SyncState.synced) {
          notify(SyncState.online);
        }
      });
      return result;
    } catch (e) {
      notify(SyncState.online);
      rethrow;
    }
  }

  static bool get isOnline =>
      stateNotifier.value != SyncState.offline;
}
