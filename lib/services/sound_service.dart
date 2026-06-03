import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

/// Reproduce sonidos cortos y vibración para el feedback del juego.
/// Los .wav viven en assets/sounds/ (declarados en pubspec.yaml).
class SoundService {
  static final AudioPlayer _player = AudioPlayer()
    ..setPlayerMode(PlayerMode.lowLatency);

  static Future<void> _play(String archivo) async {
    try {
      await _player.stop();
      await _player.play(AssetSource('sounds/$archivo'));
    } catch (_) {
      // Si por algún motivo no hay audio disponible, no rompemos el juego.
    }
  }

  /// Respuesta correcta: nota alegre + vibración suave.
  static void correcto() {
    HapticFeedback.lightImpact();
    _play('correcto.wav');
  }

  /// Respuesta incorrecta: nota grave + vibración más marcada.
  static void error() {
    HapticFeedback.heavyImpact();
    _play('error.wav');
  }

  /// Subida de nivel: arpegio de celebración.
  static void nivel() {
    HapticFeedback.mediumImpact();
    _play('nivel.wav');
  }

  /// Compra en la tienda: sonido brillante.
  static void compra() {
    HapticFeedback.selectionClick();
    _play('compra.wav');
  }
}
