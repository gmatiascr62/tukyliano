import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:just_audio/just_audio.dart';

/// Lo que hace que el podcast y la radio sigan sonando con la pantalla
/// bloqueada.
///
/// Android no deja que una app en segundo plano reproduzca audio porque sí:
/// hace falta un servicio en primer plano, y un servicio en primer plano es
/// una notificación con los controles. Esto lo prende.
///
/// **Esta es la segunda versión.** La primera usaba just_audio_background,
/// que hace todo esto solo con tres renglones. No anduvo: el servicio
/// arrancaba sin error, el audio sonaba, y la notificación no aparecía nunca
/// —así que Android cortaba el audio a los treinta segundos de dejar la app—.
/// Ese paquete lleva años en beta (0.0.1-beta.17) y funciona metiéndose en el
/// medio de just_audio para adivinar qué está sonando; cuando esa adivinanza
/// falla, falla en silencio y no hay dónde mirar.
///
/// Su propio README dice que para cualquier cosa que no sea el caso más
/// simple conviene usar audio_service directo. Eso es esto: unas líneas más,
/// pero acá se ve exactamente qué se le dice a Android y cuándo.
class AudioDeFondo {
  const AudioDeFondo._();

  /// El reproductor de verdad, uno solo para toda la app.
  ///
  /// Se crea acá y no adentro de las pantallas porque el servicio de Android
  /// tiene que envolverlo: primero existe el reproductor, después el servicio
  /// que lo muestra.
  static AudioPlayer? get elReproductor => _reproductor;
  static AudioPlayer? _reproductor;

  /// Quien le habla a Android: publica qué está sonando y recibe los toques
  /// en la notificación y en los botones del auricular.
  static ManejadorDeAudio? get manejador => _manejador;
  static ManejadorDeAudio? _manejador;

  /// True cuando el servicio quedó prendido.
  static bool get anda => _manejador != null;

  /// Por qué no se pudo prender, si no se pudo. Null cuando anduvo.
  ///
  /// Se guarda y se muestra en pantalla. La primera versión lo escribía con
  /// debugPrint, que en un APK instalado no lo lee nadie: el audio se cortaba
  /// a los treinta segundos y desde afuera no había forma de saber por qué.
  static String? get porQueNo => _porQueNo;
  static String? _porQueNo;

  /// Prende el servicio. Se llama una vez, al arrancar la app.
  ///
  /// Si falla, la app arranca igual: el audio suena mientras la pantalla esté
  /// encendida, que es como andaba antes de todo esto. Lo que no hace es
  /// fallar en silencio.
  static Future<void> prender() async {
    if (_manejador != null) return;
    try {
      final reproductor = AudioPlayer();
      _manejador = await AudioService.init(
        builder: () => ManejadorDeAudio(reproductor),
        config: const AudioServiceConfig(
          androidNotificationChannelId: 'org.gmatiascr62.tukyliano.audio',
          androidNotificationChannelName: 'Audio de Tukyliano',
          // Mientras algo suena, la notificación no se puede descartar: si se
          // va la notificación, se va el permiso de seguir sonando. Al pausar
          // vuelve a ser descartable sola.
          androidNotificationOngoing: true,
          androidStopForegroundOnPause: true,
          // Tocar la notificación vuelve a la app que ya está abierta en vez
          // de abrir una copia nueva.
          androidNotificationClickStartsActivity: true,
        ),
      );
      _reproductor = reproductor;
      _porQueNo = null;
    } catch (e) {
      _manejador = null;
      _reproductor = null;
      _porQueNo = '$e';
    }
  }

  /// Para los tests: hacer de cuenta que el servicio no anduvo, sin tener que
  /// prender nada de verdad.
  @visibleForTesting
  static void comoSi({required bool anda, String? porQue}) {
    _manejador = anda ? _manejador ?? ManejadorDeAudio.deMentira() : null;
    _porQueNo = porQue;
  }
}

/// El que le habla a Android sobre lo que está sonando.
///
/// Tiene dos trabajos y los dos son de traducción:
///
/// - Hacia afuera: cada vez que el reproductor cambia de estado, le cuenta a
///   Android si está sonando, en qué segundo va y qué botones mostrar. **Esto
///   es lo que hace aparecer la notificación**, y la notificación es lo que
///   deja seguir sonando en segundo plano. Sin esta cuenta no hay nada.
/// - Hacia adentro: cuando se toca play o pausa en la notificación, en la
///   pantalla bloqueada o en el auricular, Android llama a estos métodos y
///   acá se los pasa al reproductor.
class ManejadorDeAudio extends BaseAudioHandler with SeekHandler {
  ManejadorDeAudio(this.reproductor) {
    // Un solo lugar que escucha y cuenta. Antes de esto no había ninguno: por
    // eso Android no se enteraba nunca de que había algo sonando.
    reproductor?.playbackEventStream.listen(
      (_) => _contarComoVa(),
      onError: (Object _) => _contarComoVa(),
    );
    reproductor?.durationStream.listen(_anotarCuantoDura);
  }

  /// Para los tests, que no pueden crear un AudioPlayer de verdad.
  ManejadorDeAudio.deMentira() : reproductor = null;

  final AudioPlayer? reproductor;

  /// Dice en pantalla qué está sonando.
  ///
  /// Hay que llamarlo cada vez que cambia lo que suena: es lo que pone el
  /// título en la notificación y en la pantalla bloqueada.
  void ahoraSuena({
    required String id,
    required String titulo,
    required String deQuien,
    Duration? cuantoDura,
  }) {
    mediaItem.add(MediaItem(
      id: id,
      title: titulo,
      artist: deQuien,
      album: 'Tukyliano',
      duration: cuantoDura,
    ));
  }

  /// Una radio en vivo no tiene duración, pero un episodio sí, y recién se
  /// sabe cuando el archivo se abrió. Sin esto la notificación no dibuja la
  /// barra de progreso.
  void _anotarCuantoDura(Duration? dura) {
    final actual = mediaItem.valueOrNull;
    if (actual == null || dura == null || actual.duration == dura) return;
    mediaItem.add(actual.copyWith(duration: dura));
  }

  void _contarComoVa() {
    final r = reproductor;
    if (r == null) return;

    playbackState.add(PlaybackState(
      // Lo que se ve en la notificación. Un solo botón que alterna: es un
      // reproductor de una cosa por vez, no una lista.
      controls: [
        if (r.playing) MediaControl.pause else MediaControl.play,
        MediaControl.stop,
      ],
      systemActions: const {MediaAction.seek},
      androidCompactActionIndices: const [0],
      processingState: _comoLoLlamaAndroid(r.processingState),
      playing: r.playing,
      updatePosition: r.position,
      bufferedPosition: r.bufferedPosition,
      speed: r.speed,
    ));
  }

  static AudioProcessingState _comoLoLlamaAndroid(ProcessingState estado) =>
      switch (estado) {
        ProcessingState.idle => AudioProcessingState.idle,
        ProcessingState.loading => AudioProcessingState.loading,
        ProcessingState.buffering => AudioProcessingState.buffering,
        ProcessingState.ready => AudioProcessingState.ready,
        ProcessingState.completed => AudioProcessingState.completed,
      };

  @override
  Future<void> play() async => reproductor?.play();

  @override
  Future<void> pause() async => reproductor?.pause();

  @override
  Future<void> seek(Duration position) async => reproductor?.seek(position);

  @override
  Future<void> stop() async {
    await reproductor?.stop();
    await super.stop();
  }
}
