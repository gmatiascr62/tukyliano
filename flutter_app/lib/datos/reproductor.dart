import 'dart:async';

import 'package:just_audio/just_audio.dart';

import 'android.dart';
import 'audio_de_fondo.dart';

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
///
/// **Hay uno solo en toda la app**, y lo crea main.dart. No es una elección
/// de estilo: para que el audio siga sonando con la pantalla bloqueada hace
/// falta un servicio de Android, y el que lo hace —just_audio_background—
/// dice en su primera línea que sirve para "el caso simple de una app con un
/// solo AudioPlayer". Con dos, la notificación y los botones del auricular no
/// saben a cuál le hablan.
///
/// Por eso las pantallas lo reciben y no lo crean, y al salir lo pausan en vez
/// de soltarlo: el que lo suelta es el que lo creó.
abstract class Reproductor {
  /// Carga un archivo de assets/audio/. False si no está o no se pudo abrir.
  ///
  /// [titulo] y [deQuien] son lo que se lee en la notificación y en la
  /// pantalla bloqueada. Sin ellos no hay notificación, y sin notificación
  /// Android corta el audio apenas se bloquea el celular.
  Future<bool> cargar(String archivo, {String? titulo, String? deQuien});

  /// Carga un archivo que ya está guardado en el celular.
  ///
  /// Es lo que suena cuando se bajó una fábula: no viaja en el APK ni sale
  /// de internet cada vez, está en la carpeta de la app.
  Future<bool> cargarGuardado(
    String ruta, {
    String? titulo,
    String? deQuien,
  });

  /// Carga algo que está en internet: una radio en vivo, por ejemplo.
  ///
  /// Es aparte de [cargar] porque no se parecen: un archivo del APK está o no
  /// está y se sabe al instante, y una radio puede tardar, cortarse a la
  /// mitad o no existir más desde ayer.
  Future<bool> cargarDesdeInternet(
    String url, {
    String? titulo,
    String? deQuien,
  });

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

  /// Qué está pasando con el audio, en una línea.
  ///
  /// Existe para poder mirarlo desde la app. Cuando el audio se cortaba a los
  /// treinta segundos no había forma de saber desde afuera si el servicio
  /// estaba prendido o no, y la única manera de avanzar fue ir preguntando.
  String get comoVa;
}

class ReproductorDeVerdad implements Reproductor {
  /// Usa el reproductor que creó AudioDeFondo, que es el que el servicio de
  /// Android tiene envuelto. Si el servicio no se pudo prender, se arma uno
  /// propio: el audio suena igual, nada más que sin notificación y sin
  /// segundo plano.
  ReproductorDeVerdad()
      : _player = AudioDeFondo.elReproductor ?? AudioPlayer(),
        _manejador = AudioDeFondo.manejador;

  final AudioPlayer _player;

  /// Quien le cuenta a Android qué está sonando. Null cuando el servicio no
  /// se pudo prender.
  final ManejadorDeAudio? _manejador;

  String? _falla;

  /// True cuando lo cargado es una radio en vivo y no un archivo del celular.
  /// Solo la radio necesita que alguien le sostenga el Wi-Fi.
  bool _esRadio = false;

  /// just_audio no reproduce el asset directamente: lo copia a un archivo de
  /// cache y toca esa copia. Y la identifica SOLO por el nombre, con un
  /// `if (!file.existsSync())`, asi que si ya existe nunca la reescribe.
  ///
  /// Al actualizar la app con un audio nuevo bajo el mismo nombre, seguia
  /// sonando el viejo. Paso de verdad: el episodio nuevo sonaba igual que el
  /// anterior, el reloj marcaba 9:36 en vez de 8:05, y el archivo dentro del
  /// APK era el correcto. La biblioteca trae el remedio y dice para que es:
  /// "llamá a esto cuando los recursos de la app cambiaron".
  ///
  /// Se hace una vez por arranque. Volver a copiar unos megas del APK es
  /// barato; escuchar el episodio equivocado no.
  static bool _cacheVaciada = false;

  @override
  String? get porQueFallo => _falla;

  @override
  Duration? get duracion => _player.duration;

  /// Le dice a Android qué está sonando.
  ///
  /// Esto es lo que hace aparecer la notificación, y la notificación es lo
  /// que deja seguir sonando con la pantalla bloqueada. El id tiene que ser
  /// distinto por cosa que suena, o el sistema cree que es la misma de antes
  /// y deja el título viejo.
  void _avisarQueSuena(String id, String? titulo, String? deQuien) {
    if (titulo == null) return;
    _manejador?.ahoraSuena(
      id: id,
      titulo: titulo,
      deQuien: deQuien ?? 'Tukyliano',
      cuantoDura: _player.duration,
    );
  }

  @override
  Future<bool> cargar(String archivo, {String? titulo, String? deQuien}) async {
    try {
      if (!_cacheVaciada) {
        _cacheVaciada = true;
        await AudioPlayer.clearAssetCache();
      }
      _esRadio = false;
      await _player.setAsset('assets/audio/$archivo');
      _avisarQueSuena('episodio:$archivo', titulo, deQuien);
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
  Future<bool> cargarGuardado(
    String ruta, {
    String? titulo,
    String? deQuien,
  }) async {
    try {
      _esRadio = false;
      await _player.setFilePath(ruta);
      _avisarQueSuena('guardado:$ruta', titulo, deQuien);
      _falla = null;
      return true;
    } catch (e) {
      _falla = '$e';
      return false;
    }
  }

  @override
  Future<bool> cargarDesdeInternet(
    String url, {
    String? titulo,
    String? deQuien,
  }) async {
    try {
      _esRadio = true;
      await _player.setUrl(url);
      _avisarQueSuena('radio:$url', titulo, deQuien);
      _falla = null;
      return true;
    } catch (e) {
      _falla = '$e';
      return false;
    }
  }

  @override
  Future<void> reproducir() async {
    // El Wi-Fi se sostiene solo mientras suena una radio: con la pantalla
    // apagada la antena entra en ahorro y el stream se queda sin datos.
    if (_esRadio) await Android.agarrarElWifi();
    await _player.play();
  }

  @override
  Future<void> pausar() async {
    await _player.pause();
    if (_esRadio) await Android.soltarElWifi();
  }

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
  Future<void> soltar() async {
    await Android.soltarElWifi();
    await _player.dispose();
  }

  /// Qué está pasando con el audio, en una línea, para poder mirarlo desde la
  /// app cuando algo no suena como debería.
  @override
  String get comoVa {
    final manejador = _manejador;
    if (manejador == null) return 'sin servicio de audio';
    final notificaciones = Android.puedeNotificar ? 'notif. sí' : 'notif. NO';
    final roto = AudioDeFondo.seRompio;
    return '$notificaciones · reproductor: '
        '${_player.processingState.name}/'
        '${_player.playing ? "sonando" : "quieto"}\n'
        '${manejador.loQuePublique}'
        '${roto == null ? "" : "\nse rompió: $roto"}';
  }
}
