import 'dart:async';

import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// El idioma que se escucha, como lo nombra Android (con guion bajo, al revés
/// que el de la voz). Solo se usa a ciegas: si el celular sabe listar sus
/// idiomas, se usa el que él mismo reporta.
const idiomaEscuchado = 'it_IT';

/// Lo que el celular creyó escuchar.
class LoEscuchado {
  const LoEscuchado({required this.mejor, this.alternativas = const []});

  /// La transcripción en la que más confía.
  final String mejor;

  /// Las otras que consideró, de la más probable a la menos. Sirven para
  /// distinguir "no te entendió" de "te entendió, pero en segundo lugar".
  final List<String> alternativas;

  bool get vacio => mejor.trim().isEmpty;
}

/// El micrófono del celular escuchando italiano.
///
/// No mide la pronunciación como un profesor: devuelve la palabra que el
/// reconocedor de Android creyó oír. Eso alcanza para lo que se practica acá,
/// que es hacerse entender: si el reconocedor italiano entendió "cinque", un
/// italiano también.
///
/// Está detrás de una interfaz por lo mismo que [Voz]: en los tests no hay
/// micrófono ni plugin, así que se inyecta uno de mentira.
abstract class Escucha {
  /// Pide permiso al micrófono y prende el motor. Hasta que devuelva true no
  /// se puede escuchar.
  Future<bool> preparar();

  bool get listo;

  /// Qué salió mal la última vez, en castellano y para mostrar. Vacío si no
  /// hay nada que avisar.
  String get problema;

  /// Detalle técnico de la última escucha: qué idioma se usó, en qué estado
  /// quedó el motor y qué código de error tiró Android. No es para el alumno;
  /// es para poder averiguar por qué un celular no escucha.
  String get diagnostico;

  /// Escucha una vez y devuelve lo que oyó, o null si no oyó nada.
  ///
  /// [alOir] va recibiendo lo que se entiende mientras se habla, y [alSonido]
  /// cuánto ruido entra por el micrófono (0 a 1). Los dos son para mostrar en
  /// pantalla que el micrófono está vivo.
  Future<LoEscuchado?> escuchar({
    void Function(String parcial)? alOir,
    void Function(double volumen)? alSonido,
  });

  /// Corta una escucha a mitad de camino.
  Future<void> cortar();
}

class EscuchaDelCelular implements Escucha {
  EscuchaDelCelular({SpeechToText? motor}) : _motor = motor ?? SpeechToText();

  final SpeechToText _motor;

  /// Cuánto se deja hablar y cuánto silencio corta la escucha. Android tiene
  /// además su propio corte por pausa, más corto, que no se puede cambiar.
  static const _cuantoEscucha = Duration(seconds: 12);
  static const _cuantoSilencio = Duration(seconds: 4);

  bool _listo = false;
  String _problema = '';

  /// El idioma que se le termina pidiendo al reconocedor: el que reporta el
  /// celular, porque no todos lo nombran igual ("it_IT", "it-IT", "it").
  String _idiomaUsado = '';
  String _ultimoEstado = '';
  String _ultimoError = '';

  /// La escucha en curso y lo último que se entendió mientras se hablaba.
  Completer<LoEscuchado?>? _turno;
  LoEscuchado? _ultimoParcial;
  Timer? _vigia;

  /// Recién cuando se escuchó una vez hay algo técnico que contar; antes, el
  /// detalle sería inventado.
  bool _huboEscucha = false;

  @override
  bool get listo => _listo;

  @override
  String get problema => _problema;

  @override
  String get diagnostico => !_huboEscucha
      ? ''
      : [
          'idioma: ${_idiomaUsado.isEmpty ? 'el del celular' : _idiomaUsado}',
          if (_ultimoEstado.isNotEmpty) 'estado: $_ultimoEstado',
          if (_ultimoError.isNotEmpty) 'error: $_ultimoError',
        ].join(' · ');

  @override
  Future<bool> preparar() async {
    if (_listo) return true;
    try {
      // initialize es también lo que pide el permiso del micrófono la primera
      // vez; si el usuario lo niega, devuelve false.
      _listo = await _motor.initialize(
        onError: _alFallar,
        onStatus: _alCambiarEstado,
      );
    } catch (_) {
      _listo = false;
    }
    if (!_listo) {
      _problema = 'Este celular no puede escuchar: o no tiene reconocimiento '
          'de voz, o no le diste permiso al micrófono.';
      return false;
    }
    _problema = await _buscarElItaliano();
    return true;
  }

  /// Averigua cómo llama este celular al italiano.
  ///
  /// Pedirle "it_IT" a ciegas no siempre anda: algunos lo llaman "it-IT" y
  /// otros "it", y con un código que no conoce el reconocedor puede escuchar
  /// en el idioma del celular, que acá es castellano. Ahí "cinque" nunca daría
  /// bien por más que se diga perfecto.
  ///
  /// Cuando el celular no sabe listar sus idiomas devuelve una lista vacía.
  /// Eso no significa que falte el italiano, así que se lo pide igual.
  Future<String> _buscarElItaliano() async {
    try {
      final idiomas = await _motor.locales();
      if (idiomas.isEmpty) {
        _idiomaUsado = idiomaEscuchado;
        return '';
      }

      for (final idioma in idiomas) {
        if (idioma.localeId.toLowerCase().startsWith('it')) {
          _idiomaUsado = idioma.localeId;
          return '';
        }
      }

      _idiomaUsado = '';
      return 'Este celular no tiene el italiano para escuchar, así que va a '
          'entender cualquier cosa. Se baja desde Ajustes de Android, en los '
          'idiomas del teclado de Google.';
    } catch (_) {
      _idiomaUsado = idiomaEscuchado;
      return '';
    }
  }

  @override
  Future<LoEscuchado?> escuchar({
    void Function(String parcial)? alOir,
    void Function(double volumen)? alSonido,
  }) async {
    if (!await preparar()) return null;
    await cortar();

    final turno = Completer<LoEscuchado?>();
    _turno = turno;
    _huboEscucha = true;
    _ultimoParcial = null;
    _ultimoError = '';
    _problema = '';

    try {
      await _motor.listen(
        onResult: (resultado) {
          final oido = LoEscuchado(
            mejor: resultado.recognizedWords,
            alternativas: [
              for (final otra in resultado.alternates) otra.recognizedWords,
            ],
          );
          if (!oido.vacio) {
            _ultimoParcial = oido;
            alOir?.call(oido.mejor);
          }
          if (resultado.finalResult) _terminar(oido);
        },
        onSoundLevelChange: alSonido == null ? null : (n) => alSonido(_nivel(n)),
        listenOptions: SpeechListenOptions(
          // Vacío significa "el idioma del celular": es lo último que queda si
          // no se pudo averiguar cuál es el italiano.
          localeId: _idiomaUsado.isEmpty ? null : _idiomaUsado,
          // Los parciales son los que muestran en pantalla que el micrófono
          // está entendiendo algo, y son la respuesta si Android nunca manda
          // el resultado final.
          partialResults: true,
          cancelOnError: false,
          listenFor: _cuantoEscucha,
          pauseFor: _cuantoSilencio,
        ),
      );
    } catch (_) {
      _problema = 'No se pudo abrir el micrófono.';
      _terminar(null);
      return turno.future;
    }

    _vigilar();
    // Red de seguridad por si el motor se cuelga sin contestar ni fallar.
    return turno.future.timeout(
      _cuantoEscucha + const Duration(seconds: 8),
      onTimeout: () {
        cortar();
        return _ultimoParcial;
      },
    );
  }

  /// Se fija sola cuándo terminó la escucha.
  ///
  /// El plugin avisa "done" únicamente cuando Android manda un resultado
  /// final. Si no manda ninguno —pasa seguido: ruido, una palabra que no
  /// reconoce, o el celular que corta por su cuenta— no avisa nada y la
  /// pantalla se quedaría escuchando para siempre. Mirar si el motor sigue
  /// escuchando es lo único que no depende de eso.
  void _vigilar() {
    _vigia?.cancel();
    // Un rato antes de empezar a mirar: el motor tarda en arrancar y si no
    // parecería que terminó apenas empezó.
    var quieto = 0;
    _vigia = Timer(const Duration(milliseconds: 1200), () {
      _vigia = Timer.periodic(const Duration(milliseconds: 400), (reloj) {
        if (_turno == null) {
          reloj.cancel();
          return;
        }
        if (_motor.isListening) {
          quieto = 0;
          return;
        }
        quieto++;
        // Dos vueltas quieto: terminó. Se contesta con lo último que se
        // entendió mientras se hablaba, que es mejor que nada.
        if (quieto >= 2) _terminar(_ultimoParcial);
      });
    });
  }

  @override
  Future<void> cortar() async {
    try {
      if (_motor.isListening) await _motor.cancel();
    } catch (_) {
      // Cortar algo que ya estaba cortado no es un problema.
    }
    _terminar(_ultimoParcial);
  }

  void _terminar(LoEscuchado? oido) {
    _vigia?.cancel();
    _vigia = null;
    final turno = _turno;
    _turno = null;
    if (turno != null && !turno.isCompleted) turno.complete(oido);
  }

  /// Android manda el volumen en una escala rara que va más o menos de -2 a
  /// 10. Acá se lo lleva a 0 a 1, que es lo que necesita la barrita.
  double _nivel(double crudo) {
    final normalizado = (crudo + 2) / 12;
    return normalizado.clamp(0, 1).toDouble();
  }

  void _alCambiarEstado(String estado) => _ultimoEstado = estado;

  void _alFallar(SpeechRecognitionError error) {
    _ultimoError = error.errorMsg;
    _problema = _explicar(error.errorMsg);
    // Los errores permanentes cortan la escucha; los pasajeros no, que el
    // motor sigue intentando.
    if (error.permanent) _terminar(_ultimoParcial);
  }

  /// Traduce los códigos de Android a algo que se pueda leer.
  ///
  /// Los dos primeros no son fallas: son "no te escuché", y la pantalla ya lo
  /// dice sola, así que no se muestra nada.
  String _explicar(String codigo) => switch (codigo) {
        'error_no_match' || 'error_speech_timeout' => '',
        'error_network' || 'error_network_timeout' =>
          'Para escucharte necesita internet. Con datos o wifi anda; sin eso, '
              'hay que bajar el italiano offline desde Ajustes de Android.',
        'error_permission' =>
          'Falta el permiso del micrófono. Se da desde Ajustes de Android, en '
              'los permisos de Tukyliano.',
        'error_busy' => 'El micrófono está ocupado por otra app.',
        'error_audio' => 'No se pudo grabar el audio.',
        'error_language_not_supported' || 'error_language_unavailable' =>
          'Este celular no tiene el italiano para escuchar. Se baja desde '
              'Ajustes de Android, en los idiomas del teclado de Google.',
        _ => 'No se pudo escuchar ($codigo).',
      };
}
