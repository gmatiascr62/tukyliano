import 'package:flutter_tts/flutter_tts.dart';

/// El idioma que se pronuncia.
const idiomaItaliano = 'it-IT';

/// Lee italiano en voz alta usando el motor que ya trae el celular.
///
/// No hay archivos de audio ni servicio en la nube: se le pasa el texto y lo
/// pronuncia. Eso significa que no hace falta ninguna clave, no gasta datos, y
/// los cuentos nuevos hablan solos sin agregar nada.
///
/// Lo único delicado es que la voz italiana tiene que estar instalada en el
/// celular. Si no está, el motor lee el italiano con los sonidos del idioma
/// que sí tiene, y eso enseña mal: diría "gli" como se lee en español en vez
/// de "lli". Por eso [preparar] chequea primero y, si no está, la pantalla
/// avisa en lugar de hablar.
abstract class Voz {
  /// Chequea si se puede pronunciar italiano. Hay que llamarla antes de
  /// [decir]; mientras devuelva false no se habla.
  Future<bool> preparar();

  Future<void> decir(String texto);

  Future<void> callar();

  /// Más lento que lo normal, para poder seguir las palabras.
  Future<void> usarVelocidadLenta(bool lenta);
}

class VozDelSistema implements Voz {
  VozDelSistema({FlutterTts? motor}) : _motor = motor ?? FlutterTts();

  final FlutterTts _motor;
  bool _listo = false;

  /// Normal es 0.5 en la escala del motor, no 1.0: arriba de eso el italiano
  /// se vuelve difícil de seguir incluso para quien lo habla.
  static const _velocidadNormal = 0.5;
  static const _velocidadLenta = 0.32;

  @override
  Future<bool> preparar() async {
    if (_listo) return true;
    try {
      // isLanguageAvailable devuelve false cuando la voz no está bajada, que
      // es el caso que hay que atajar.
      final disponible = await _motor.isLanguageAvailable(idiomaItaliano);
      if (disponible != true) return false;

      await _motor.setLanguage(idiomaItaliano);
      await _motor.setSpeechRate(_velocidadNormal);
      _listo = true;
      return true;
    } catch (_) {
      // Sin motor de voz en el celular no se habla, pero la app sigue.
      return false;
    }
  }

  @override
  Future<void> decir(String texto) async {
    if (!_listo || texto.isEmpty) return;
    try {
      // Cortar lo anterior evita que dos renglones se pisen si se toca rápido.
      await _motor.stop();
      await _motor.speak(texto);
    } catch (_) {
      // Que falle una frase no tiene que romper la lectura.
    }
  }

  @override
  Future<void> callar() async {
    if (!_listo) return;
    try {
      await _motor.stop();
    } catch (_) {}
  }

  @override
  Future<void> usarVelocidadLenta(bool lenta) async {
    if (!_listo) return;
    try {
      await _motor
          .setSpeechRate(lenta ? _velocidadLenta : _velocidadNormal);
    } catch (_) {}
  }
}
