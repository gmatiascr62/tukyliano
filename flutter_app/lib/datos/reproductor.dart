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

  /// Por qué falló el último [cargar], si falló. Null si anduvo.
  ///
  /// Existe porque la primera vez que esto fallo de verdad —en el celular,
  /// con el archivo bien puesto adentro del APK— la app se cayó al motor de
  /// voz sin decir una palabra, y desde afuera parecía que el audio nuevo no
  /// se había instalado. Un error que no se ve cuesta horas.
  String? get porQueFallo;

  /// Cuánto dura el archivo cargado, si se pudo saber.
  Duration? get duracion;

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
  String? _falla;

  @override
  String? get porQueFallo => _falla;

  @override
  Duration? get duracion => _player.duration;

  @override
  Future<bool> cargar(String archivo) async {
    try {
      await _player.setAsset('assets/audio/$archivo');
      _falla = null;
      return true;
    } catch (e) {
      // Un episodio al que no se le puede abrir el audio no tiene que tirar
      // abajo la pantalla: se cae al motor de voz, que siempre está. Pero el
      // motivo se guarda y se muestra, en vez de desaparecer.
      _falla = '$e';
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
