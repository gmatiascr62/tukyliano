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

/// Las dos voces que se ofrecen, por el lugar que ocupan en la lista ordenada
/// que da el celular.
///
/// El celular reporta muchas voces italianas, pero varias suenan casi igual y
/// otras suenan mal. Estas dos están escuchadas y elegidas: son las que antes
/// se llamaban Milano (de mujer) y Firenze (de varón). Ahora que se sabe de
/// quién es cada una llevan nombre de persona en vez de nombre de ciudad.
///
/// Va por posición y no por el código de Android ("it-it-x-itc-local") porque
/// esos códigos no son los mismos en todos los celulares. La lista se ordena
/// siempre igual, así que la posición sí es estable.
const vocesOfrecidas = <int, String>{1: 'Giulia', 4: 'Lorenzo'};

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
      // Se fija la primera en el acto: si no, la pastilla mostraría una voz y
      // el motor hablaría con la que él tiene de fábrica, que es otra.
      if (_voces.isNotEmpty) await usarVoz(_voces.first);
      return true;
    } catch (_) {
      // Sin motor de voz en el celular no se habla, pero la app sigue.
      return false;
    }
  }

  /// Las dos voces elegidas, con su nombre puesto.
  ///
  /// Se ordenan por id antes de buscarlas para que la misma voz sea siempre la
  /// misma: si el motor las devolviera en otro orden, Giulia pasaría a ser otra
  /// y el alumno no entendería por qué cambió.
  ///
  /// Si el celular tiene menos voces de las esperadas quedan menos de dos, o
  /// ninguna. Eso no rompe nada: sin nada que elegir no aparece el selector y
  /// se habla con la voz de fábrica.
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
          if (vocesOfrecidas[i] case final nombre?)
            VozItaliana(id: id, nombre: nombre),
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
