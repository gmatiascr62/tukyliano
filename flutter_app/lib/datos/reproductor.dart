import 'dart:async';

import 'package:just_audio/just_audio.dart';

/// Reproduce el audio grabado de un episodio.
///
/// Es la contraparte de [Voz] para los episodios que tienen audio: la pantalla
/// no sabe cuál de los dos la está haciendo sonar, y por eso puede usar el
/// mismo recorrido de frases con los dos.
///
/// La diferencia de fondo entre los dos no es cómo suena sino quién manda. Con
/// el motor de voz la pantalla dice una frase y espera a que termine, así que
/// sabe en todo momento cuál está sonando. Con un archivo grabado el que manda
/// es el reloj del reproductor: la pantalla pregunta en qué segundo va y
/// deduce la frase de la tabla de tiempos. Por eso [porDonde].
abstract class Reproductor {
  /// Carga un archivo de assets/audio/. False si no está o no se pudo abrir.
  Future<bool> cargar(String archivo);

  Future<void> reproducir();
  Future<void> pausar();
  Future<void> irA(Duration donde);

  /// Lento es 0,75: se entiende cada palabra y no suena a cinta estirada.
  Future<void> usarVelocidadLenta(bool lenta);

  /// En qué segundo va. Emite seguido mientras suena.
  Stream<Duration> get porDonde;

  /// Emite una vez cuando llegó al final del episodio.
  Stream<void> get termino;

  Future<void> soltar();
}

class ReproductorDeVerdad implements Reproductor {
  final AudioPlayer _player = AudioPlayer();

  @override
  Future<bool> cargar(String archivo) async {
    try {
      await _player.setAsset('assets/audio/$archivo');
      return true;
    } catch (_) {
      // Un episodio al que le falta el archivo no tiene que tirar abajo la
      // pantalla: se cae al motor de voz, que siempre está.
      return false;
    }
  }

  @override
  Future<void> reproducir() => _player.play();

  @override
  Future<void> pausar() => _player.pause();

  @override
  Future<void> irA(Duration donde) => _player.seek(donde);

  @override
  Future<void> usarVelocidadLenta(bool lenta) =>
      _player.setSpeed(lenta ? 0.75 : 1.0);

  @override
  Stream<Duration> get porDonde => _player.positionStream;

  @override
  Stream<void> get termino => _player.processingStateStream
      .where((estado) => estado == ProcessingState.completed);

  @override
  Future<void> soltar() => _player.dispose();
}
