import 'dart:async';

import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// El idioma que se escucha. Va con guion bajo porque así lo nombra Android,
/// al revés que el de la voz ("it-IT").
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

  /// Escucha una vez y devuelve lo que oyó, o null si no oyó nada.
  Future<LoEscuchado?> escuchar();

  /// Corta una escucha a mitad de camino.
  Future<void> cortar();
}

class EscuchaDelCelular implements Escucha {
  EscuchaDelCelular({SpeechToText? motor}) : _motor = motor ?? SpeechToText();

  final SpeechToText _motor;

  /// Cuánto se deja hablar y cuánto silencio corta la escucha. Son palabras
  /// sueltas: de más, cada intento termina esperando al pedo.
  static const _cuantoEscucha = Duration(seconds: 6);
  static const _cuantoSilencio = Duration(seconds: 2);

  bool _listo = false;
  String _problema = '';

  /// La escucha en curso. Se completa con el resultado, con null si no se oyó
  /// nada, o por el timeout de abajo.
  Completer<LoEscuchado?>? _turno;

  @override
  bool get listo => _listo;

  @override
  String get problema => _problema;

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
    _problema = await _avisoDelIdioma();
    return true;
  }

  /// Avisa si el celular no tiene el italiano entre los idiomas que reconoce.
  ///
  /// Si no lo tiene, escucha igual pero con otro idioma, y ahí "cinque" nunca
  /// va a dar bien por más que se diga perfecto. Cuando el celular no sabe
  /// listar los idiomas devuelve una lista vacía: eso no es que falte el
  /// italiano, así que no se avisa nada.
  Future<String> _avisoDelIdioma() async {
    try {
      final idiomas = await _motor.locales();
      if (idiomas.isEmpty) return '';
      final hay = idiomas.any(
        (i) => i.localeId.toLowerCase().startsWith('it'),
      );
      if (hay) return '';
      return 'Este celular no tiene el italiano para escuchar. Se baja desde '
          'Ajustes de Android, en el teclado de Google.';
    } catch (_) {
      return '';
    }
  }

  @override
  Future<LoEscuchado?> escuchar() async {
    if (!await preparar()) return null;
    await cortar();

    final turno = Completer<LoEscuchado?>();
    _turno = turno;
    _problema = '';

    try {
      await _motor.listen(
        onResult: (resultado) {
          // Los parciales cambian mientras se habla; el bueno es el último.
          if (!resultado.finalResult) return;
          _terminar(LoEscuchado(
            mejor: resultado.recognizedWords,
            alternativas: [
              for (final otra in resultado.alternates) otra.recognizedWords,
            ],
          ));
        },
        listenOptions: SpeechListenOptions(
          localeId: idiomaEscuchado,
          partialResults: false,
          cancelOnError: true,
          listenFor: _cuantoEscucha,
          pauseFor: _cuantoSilencio,
        ),
      );
    } catch (_) {
      _problema = 'No se pudo abrir el micrófono.';
      _terminar(null);
    }

    // Red de seguridad: si el motor se cuelga sin contestar ni fallar, la
    // pantalla no puede quedar escuchando para siempre.
    return turno.future.timeout(
      const Duration(seconds: 20),
      onTimeout: () {
        cortar();
        return null;
      },
    );
  }

  @override
  Future<void> cortar() async {
    try {
      if (_motor.isListening) await _motor.cancel();
    } catch (_) {
      // Cortar algo que ya estaba cortado no es un problema.
    }
    _terminar(null);
  }

  void _terminar(LoEscuchado? oido) {
    final turno = _turno;
    _turno = null;
    if (turno != null && !turno.isCompleted) turno.complete(oido);
  }

  void _alCambiarEstado(String estado) {
    if (estado != SpeechToText.doneStatus) return;
    // "done" llega después del resultado cuando hubo alguno. Si no llegó
    // ninguno (silencio), esto es lo único que destraba la pantalla; se espera
    // un momento por si el resultado viene atrás.
    Future.delayed(
      const Duration(milliseconds: 600),
      () => _terminar(null),
    );
  }

  void _alFallar(SpeechRecognitionError error) {
    _problema = _explicar(error.errorMsg);
    _terminar(null);
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
        _ => 'No se pudo escuchar ($codigo).',
      };
}
