import '../modelos/diccionario.dart';
import 'pronunciacion.dart' show normalizar;

/// Lo que se encontró para un pedido de traducción.
class Traduccion {
  const Traduccion({
    required this.pedido,
    required this.comoSeDice,
    required this.desdeItaliano,
    required this.completa,
    this.vieneDe = '',
  });

  /// Lo que se pidió traducir, tal como se escribió.
  final String pedido;

  /// Cómo se dice del otro lado.
  final String comoSeDice;

  /// True si lo que se pidió era italiano. Sirve para no tener que adivinar
  /// después en qué idioma leerlo en voz alta.
  final bool desdeItaliano;

  /// False cuando era una frase y alguna palabra no estaba: lo que se
  /// devuelve es palabra por palabra, con los huecos tal como vinieron.
  final bool completa;

  /// La palabra de diccionario que se usó, cuando lo que se pidió era una
  /// forma conjugada. Vacío cuando se encontró la palabra tal cual.
  ///
  /// Se muestra, no se esconde: ver "abbia → avere: haber, tener" enseña
  /// algo que "abbia: haber, tener" no enseña. Y si la forma está mal
  /// resuelta, se nota, en vez de quedar como una traducción rara.
  final String vieneDe;
}

/// Busca lo que está entre almohadillas.
///
/// Primero prueba en italiano y después en español. El orden importa con las
/// que existen en los dos idiomas —"carta", "burro"— y gana el italiano
/// porque es el idioma que se está leyendo: quien marca una palabra está
/// leyendo italiano y quiere saber qué dice.
///
/// Null cuando no encontró absolutamente nada.
Traduccion? traducir(Diccionario diccionario, String pedido) {
  final limpio = pedido.trim();
  if (limpio.isEmpty) return null;

  // Primero la frase entera: hay entradas de más de una palabra ("ieri
  // sera"), y si la frase está, es mejor que armarla pedazo por pedazo.
  final entera = _buscarUna(diccionario, limpio);
  if (entera != null) {
    return Traduccion(
      pedido: limpio,
      comoSeDice: entera.$1,
      desdeItaliano: entera.$2,
      completa: true,
      vieneDe: entera.$3,
    );
  }

  final palabras = limpio.split(RegExp(r'\s+'));
  if (palabras.length < 2) return null;

  // Una frase que no está entera se arma palabra por palabra. No es una
  // traducción buena, pero alcanza para entender de qué habla, que es lo que
  // se pidió. Las que no están quedan como vinieron, a la vista.
  final partes = <String>[];
  var encontradas = 0;
  var italianas = 0;
  for (final palabra in palabras) {
    final hallada = _buscarUna(diccionario, palabra);
    if (hallada == null) {
      partes.add(palabra);
    } else {
      partes.add(hallada.$1);
      encontradas++;
      if (hallada.$2) italianas++;
    }
    // En una frase no se dice de qué palabra viene cada pedazo: sería un
    // renglón por palabra para algo que se lee de un vistazo.
  }
  if (encontradas == 0) return null;

  return Traduccion(
    pedido: limpio,
    comoSeDice: partes.join(' '),
    desdeItaliano: italianas * 2 >= encontradas,
    completa: encontradas == palabras.length,
  );
}

/// (cómo se dice, era italiano, de qué palabra vino) para una palabra sola.
///
/// Null cuando no está de ninguna manera.
(String, bool, String)? _buscarUna(Diccionario diccionario, String palabra) {
  final clave = normalizar(palabra);
  if (clave.isEmpty) return null;

  for (final (mapa, esItaliano, formas) in [
    (diccionario.italiano, true, _comoPodriaSerEnItaliano),
    (diccionario.espanol, false, _comoPodriaSerEnEspanol),
  ]) {
    for (final forma in formas(clave)) {
      final encontrada = mapa[forma];
      if (encontrada != null && encontrada.isNotEmpty) {
        return (encontrada.join(', '), esItaliano, '');
      }
    }
  }

  // Último recurso: la tabla de formas conjugadas, que sabe de verdad de
  // qué palabra viene cada una. Va al final y no al principio porque
  // cuando la palabra está tal cual en el diccionario, esa es la buena:
  // "vale" es una palabra italiana y además una forma de "valere", y lo
  // que corresponde mostrar es lo primero.
  final base = diccionario.formas[clave];
  if (base != null) {
    final encontrada = diccionario.italiano[base];
    if (encontrada != null && encontrada.isNotEmpty) {
      return (encontrada.join(', '), true, base);
    }
  }
  return null;
}

/// Las formas con las que vale la pena buscar una palabra italiana.
///
/// Un diccionario lista lemas: trae "bambino" y no "bambini", "nuovo" y no
/// "nuove". Y la elisión pega dos palabras en una ("dall'Italia"), así que
/// también se prueban los pedazos.
///
/// Son intentos, no gramática: se prueban en orden y gana el primero que esté
/// en el diccionario, así que una forma inventada que no existe no molesta a
/// nadie.
Iterable<String> _comoPodriaSerEnItaliano(String palabra) sync* {
  yield palabra;

  if (palabra.contains("'")) {
    for (final pedazo in palabra.split("'")) {
      if (pedazo.length > 1) yield pedazo;
    }
  }

  if (palabra.length < 3) return;
  final sinUltima = palabra.substring(0, palabra.length - 1);

  switch (palabra[palabra.length - 1]) {
    case 'i':
      // bambini → bambino, chiavi → chiave, amiche → amica
      if (palabra.endsWith('hi')) yield '${palabra.substring(0, palabra.length - 2)}co';
      yield '${sinUltima}o';
      yield '${sinUltima}e';
      yield '${sinUltima}a';
    case 'e':
      if (palabra.endsWith('he')) yield '${palabra.substring(0, palabra.length - 2)}ca';
      yield '${sinUltima}a';
      yield '${sinUltima}o';
    case 'a':
      // nuova → nuovo
      yield '${sinUltima}o';
  }
}

/// Lo mismo para el español, donde el plural es más fácil: se saca la s.
Iterable<String> _comoPodriaSerEnEspanol(String palabra) sync* {
  yield palabra;
  if (palabra.endsWith('es') && palabra.length > 3) {
    yield palabra.substring(0, palabra.length - 2);
  }
  if (palabra.endsWith('s') && palabra.length > 2) {
    yield palabra.substring(0, palabra.length - 1);
  }
}
