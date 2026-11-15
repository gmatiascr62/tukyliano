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

  /// Lo último que explotó del lado de Android, si explotó algo.
  ///
  /// audio_service publica en un stream las excepciones que pasan al hablar
  /// con el servicio —entre ellas las de startForeground, que es la que deja
  /// al servicio corriendo pero en segundo plano—. No escucharlo fue tirar a
  /// la basura justo el mensaje que decía qué estaba mal.
  static String? get seRompio => _seRompio;
  static String? _seRompio;

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
          // El número al final no es decorativo. Un canal de notificaciones
          // en Android es para siempre: una vez creado, la app no puede
          // cambiarle la importancia ni reactivarlo. Si el canal quedó
          // apagado —porque lo creó una versión anterior, o porque el
          // sistema lo silenció—, la notificación no se muestra nunca y no
          // hay forma de arreglarlo desde el código salvo estrenar un canal
          // nuevo. Esto es el canal nuevo.
          androidNotificationChannelId: 'org.gmatiascr62.tukyliano.audio2',
          androidNotificationChannelName: 'Audio de Tukyliano',
          // Mientras algo suena, la notificación no se puede descartar: si se
          // va la notificación, se va el permiso de seguir sonando. Al pausar
          // vuelve a ser descartable sola.
          // Un ícono propio, monocromo. El de la app es un PNG a color sin
          // transparencia, y Android dibuja el ícono de la notificación como
          // silueta: de ese sale un cuadrado blanco macizo, y hay sistemas
          // que directamente no lo aceptan.
          androidNotificationIcon: 'drawable/ic_audio',
          androidNotificationOngoing: true,
          androidStopForegroundOnPause: true,
          // Tocar la notificación vuelve a la app que ya está abierta en vez
          // de abrir una copia nueva.
          androidNotificationClickStartsActivity: true,
        ),
      );
      _reproductor = reproductor;
      _porQueNo = null;
      AudioService.asyncError.listen((e) => _seRompio = '$e');
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
    // **playerEventStream y no playbackEventStream.** Esta línea fue el bug
    // que tuvo el audio en segundo plano sin andar durante cuatro versiones,
    // y la diferencia no se ve mirándola.
    //
    // Adentro de just_audio:
    //
    //   _playbackEventSubject.addStream(
    //       playerEventStream.map((event) => event.playbackEvent).distinct());
    //
    // El dato de si está sonando NO vive en playbackEvent, vive un nivel más
    // arriba, en playerEvent. Así que al tocar play el playbackEvent no
    // cambia, el .distinct() se come el evento, y playbackEventStream no
    // emite nada.
    //
    // Del otro lado, el servicio de Android levanta la notificación y se pone
    // en primer plano SOLO en la transición de "no sonando" a "sonando". Como
    // esa transición nunca le llegaba, nunca había notificación, y sin
    // notificación Android cortaba el audio a los treinta segundos de dejar
    // la app. Todos los síntomas salían de acá.
    reproductor?.playerEventStream.listen(
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
      // Sin el botón de parar, a propósito.
      //
      // Desde Android 13, audio_service convierte el de parar en una
      // "CustomAction", y una CustomAction sin ícono tira una excepción que
      // revienta el aviso entero —antes de llegar al startForeground, que es
      // lo que hace falta—. Los de reproducir y pausar no pasan por ahí: sin
      // ícono quedan feos, pero no rompen nada.
      //
      // Para una radio y un podcast, play y pausa alcanzan.
      controls: [
        if (r.playing) MediaControl.pause else MediaControl.play,
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

  /// Lo último que se le publicó a Android, para poder mirarlo desde la app.
  ///
  /// Es el eslabón del medio: si acá dice que está sonando pero Android dice
  /// que el servicio no corre, el problema está del lado de Android; si acá
  /// dice que no, el problema es de este archivo.
  String get loQuePublique {
    final estado = playbackState.valueOrNull;
    final que = mediaItem.valueOrNull?.title ?? 'nada';
    if (estado == null) return 'publicado: todavía nada';
    return 'publicado: ${estado.playing ? "sonando" : "quieto"} · $que';
  }

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
