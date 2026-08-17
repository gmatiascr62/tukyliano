import 'package:flutter_tts/flutter_tts.dart';

/// El idioma que se pronuncia.
const idiomaItaliano = 'it-IT';

/// Una de las voces italianas que tiene instaladas el celular.
class VozItaliana {
  const VozItaliana({required this.id, required this.nombre});

  /// Como la llama Android: "it-it-x-itc-local". No se muestra.
  final String id;

  /// Como la llamamos nosotros: "Roma".
  final String nombre;
}

/// Los nombres que se les ponen, en orden.
///
/// Son ciudades y no nombres de persona porque los códigos de Android no
/// dicen si la voz es de hombre o de mujer, y ponerle "Marco" a una voz
/// femenina sería peor que no ponerle nada.
const nombresDeVoces = [
  'Roma', 'Milano', 'Napoli', 'Torino',
  'Firenze', 'Venezia', 'Bologna', 'Palermo',
];

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
  /// Chequea si se puede pronunciar italiano y averigua qué voces hay. Hay
  /// que llamarla antes de [decir]; mientras devuelva false no se habla.
  Future<bool> preparar();

  /// Las voces italianas instaladas. Vacío o con una sola significa que no
  /// hay nada que elegir.
  List<VozItaliana> get voces;

  VozItaliana? get vozElegida;

  Future<void> usarVoz(VozItaliana voz);

  Future<void> decir(String texto);

  Future<void> callar();

  /// Más lento que lo normal, para poder seguir las palabras.
  Future<void> usarVelocidadLenta(bool lenta);
}

class VozDelSistema implements Voz {
  VozDelSistema({FlutterTts? motor}) : _motor = motor ?? FlutterTts();

  final FlutterTts _motor;
  bool _listo = false;
  List<VozItaliana> _voces = const [];
  VozItaliana? _elegida;

  /// Normal es 0.5 en la escala del motor, no 1.0: arriba de eso el italiano
  /// se vuelve difícil de seguir incluso para quien lo habla.
  static const _velocidadNormal = 0.5;
  static const _velocidadLenta = 0.32;

  @override
  List<VozItaliana> get voces => _voces;

  @override
  VozItaliana? get vozElegida => _elegida;

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
      _voces = await _buscarVoces();
      _listo = true;
      return true;
    } catch (_) {
      // Sin motor de voz en el celular no se habla, pero la app sigue.
      return false;
    }
  }

  /// Las voces italianas que reporta el motor, con nombre puesto.
  ///
  /// Se ordenan por id antes de nombrarlas para que la misma voz se llame
  /// siempre igual: si el motor las devolviera en otro orden, "Roma" pasaría
  /// a ser otra y el alumno no entendería por qué cambió.
  Future<List<VozItaliana>> _buscarVoces() async {
    try {
      final crudas = await _motor.getVoices;
      if (crudas is! List) return const [];

      final ids = <String>[];
      for (final voz in crudas) {
        if (voz is! Map) continue;
        final locale = voz['locale']?.toString() ?? '';
        final id = voz['name']?.toString() ?? '';
        if (id.isEmpty) continue;
        if (!locale.toLowerCase().startsWith('it')) continue;
        ids.add(id);
      }
      ids.sort();

      return [
        for (final (i, id) in ids.indexed)
          VozItaliana(
            id: id,
            nombre: i < nombresDeVoces.length ? nombresDeVoces[i] : id,
          ),
      ];
    } catch (_) {
      // Si el motor no sabe listar voces igual se puede hablar con la de
      // fábrica: simplemente no hay nada que elegir.
      return const [];
    }
  }

  @override
  Future<void> usarVoz(VozItaliana voz) async {
    if (!_listo) return;
    try {
      await _motor.stop();
      await _motor.setVoice({'name': voz.id, 'locale': idiomaItaliano});
      _elegida = voz;
    } catch (_) {
      // Si esa voz no se puede fijar se sigue con la anterior.
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
