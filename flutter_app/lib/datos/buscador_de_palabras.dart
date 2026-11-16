import '../ia/servidor.dart';
import '../logica/diccionario_buscar.dart';
import '../modelos/diccionario.dart';
import 'quien_soy.dart';

/// Busca qué quiere decir una palabra, donde sea que esté.
///
/// Son tres escalones, del más barato al más caro:
///
///     1. el diccionario que viaja en el APK  → sin internet, instantáneo
///     2. lo que este celular ya preguntó     → sin internet, instantáneo
///     3. el servidor                         → una vez por palabra, y nunca más
///
/// El tercero no es "preguntarle a la IA cada vez". Del otro lado el servidor
/// primero mira su propia base, y solo le pregunta a la IA si **nadie** buscó
/// esa palabra antes. O sea que se le pregunta una vez en la historia del
/// servidor, no una vez por persona: el segundo que busque "lumicino" la
/// recibe de la base, gratis.
///
/// Y la del medio existe porque sin ella, tocar dos veces la misma palabra en
/// la misma pantalla serían dos viajes a internet para la misma respuesta.
class BuscadorDePalabras {
  BuscadorDePalabras({Servidor? servidor, QuienSoy? quienSoy})
      : _servidor = servidor ?? Servidor(),
        _quienSoy = quienSoy ?? QuienSoy();

  final Servidor _servidor;
  final QuienSoy _quienSoy;

  /// Lo que ya se preguntó en esta sesión. Se pierde al cerrar la app, y
  /// está bien que se pierda: lo que vale la pena guardar para siempre se
  /// guarda del lado del servidor, donde le sirve a todos.
  final Map<String, Traduccion?> _loQueYaSe = {};

  /// Qué quiere decir, o null si no lo sabe nadie.
  ///
  /// [donde] es el renglón donde apareció y es lo que desambigua:
  /// "lumicino" solo es "lucecita", y en "ridotto al lumicino" es "en las
  /// últimas".
  Future<Traduccion?> buscar(
    Diccionario diccionario,
    String palabra, {
    String donde = '',
  }) async {
    final deAca = traducir(diccionario, palabra);
    if (deAca != null) return deAca;

    final clave = palabra.toLowerCase();
    if (_loQueYaSe.containsKey(clave)) return _loQueYaSe[clave];

    final quien = await _quienSoy.cual();
    final delServidor = await _servidor.queQuiereDecir(
      quien: quien,
      palabra: palabra,
      donde: donde,
    );

    final hallada = delServidor.hay
        ? Traduccion(
            pedido: palabra,
            comoSeDice: delServidor.es.join(', '),
            desdeItaliano: true,
            completa: true,
            vieneDe: delServidor.vieneDe,
          )
        : null;
    _loQueYaSe[clave] = hallada;
    return hallada;
  }

  /// Si esta palabra se puede contestar sin salir a internet.
  ///
  /// Sirve para no mostrar "buscando…" un instante cuando la respuesta ya
  /// está acá: ese parpadeo se nota y molesta.
  bool laSabeSinInternet(Diccionario diccionario, String palabra) =>
      traducir(diccionario, palabra) != null ||
      _loQueYaSe.containsKey(palabra.toLowerCase());
}
