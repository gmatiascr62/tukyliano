/// Las correcciones que no se le preguntan al modelo.
///
/// Un modelo de 0.6B corrige mal: a veces no ve el error, a veces "corrige"
/// una frase que estaba bien, y a veces inventa una regla. Para los errores
/// típicos de alguien que habla español —los que se repiten siempre, los que
/// son error sin discusión— no hace falta una IA: alcanza con buscarlos.
///
/// Lo que está acá es seguro: si salta, está mal. Lo dudoso no entra. Vale más
/// una regla que corrige diez cosas bien que veinte que corrigen quince bien y
/// cinco mal: una corrección equivocada le enseña mal a alguien, que es
/// exactamente lo que esto viene a evitar.
library;

/// Un error encontrado en lo que se escribió.
class ErrorDeEscritura {
  const ErrorDeEscritura({
    required this.escrito,
    required this.va,
    required this.porque,
  });

  /// La palabra tal como la escribió.
  final String escrito;

  /// La que va.
  final String va;

  /// Por qué, en una línea y en español.
  final String porque;
}

/// Una regla: qué buscar y en qué cambiarlo.
class ReglaItaliana {
  const ReglaItaliana({
    required this.busca,
    required this.cambia,
    required this.porque,
  });

  final RegExp busca;

  /// Qué poner en lugar de lo encontrado. Recibe el texto que casó.
  final String Function(Match) cambia;

  final String porque;
}

/// Palabras italianas que llevan acento y que todo el mundo escribe sin él.
///
/// El acento en italiano no es decoración: "e" es "y" y "è" es "es"; "si" es
/// "se" y "sì" es "sí". Escribirlo mal cambia lo que dice la frase.
const Map<String, String> palabrasConAcento = {
  'perche': 'perché',
  'piu': 'più',
  'gia': 'già',
  'pero': 'però',
  'cosi': 'così',
  'puo': 'può',
  'citta': 'città',
  'universita': 'università',
  'liberta': 'libertà',
  'verita': 'verità',
  'caffe': 'caffè',
  'lunedi': 'lunedì',
  'martedi': 'martedì',
  'mercoledi': 'mercoledì',
  'giovedi': 'giovedì',
  'venerdi': 'venerdì',
  'cioe': 'cioè',
  'finche': 'finché',
  'poiche': 'poiché',
};

/// Palabras en español que se cuelan en una frase en italiano.
///
/// Son las que no existen en italiano, así que encontrarlas no es una
/// interpretación: si está escrita, está mal.
const Map<String, String> palabrasEnEspanol = {
  'que': 'che',
  'y': 'e',
  'muy': 'molto',
  'de': 'di',
  'yo': 'io',
  'como': 'come',
  'mas': 'più',
  'entonces': 'allora',
  'siempre': 'sempre',
  'nunca': 'mai',
  'tambien': 'anche',
  'ahora': 'adesso',
  'manana': 'domani',
  'hoy': 'oggi',
  'ayer': 'ieri',
  'gracias': 'grazie',
  'hola': 'ciao',
};

/// Verbos y pronombres después de los cuales "no" es siempre "non".
///
/// En italiano "no" existe —"No, grazie"— pero nunca va pegado adelante de un
/// verbo: ahí va "non". Esta lista es la que separa un caso del otro.
const List<String> despuesDeNoVaNon = [
  'ho', 'hai', 'ha', 'abbiamo', 'avete', 'hanno',
  'sono', 'sei', 'siamo', 'siete',
  'capisco', 'capisci', 'capisce',
  'so', 'sai', 'sa', 'sappiamo',
  'voglio', 'vuoi', 'vuole',
  'posso', 'puoi', 'può',
  'parlo', 'parli', 'parla',
  'mangio', 'mangi', 'mangia',
  'vado', 'vai', 'va',
  'sto', 'stai', 'sta',
  'mi', 'ti', 'ci', 'lo', 'la', 'le', 'ne',
  'è', 'e',
];

/// Todas las reglas, en orden.
final List<ReglaItaliana> reglasItalianas = [
  for (final entrada in palabrasConAcento.entries)
    if (entrada.key != entrada.value)
      ReglaItaliana(
        busca: RegExp('\\b${entrada.key}\\b', caseSensitive: false),
        cambia: (_) => entrada.value,
        porque: 'En italiano va con acento: ${entrada.value}.',
      ),

  for (final entrada in palabrasEnEspanol.entries)
    ReglaItaliana(
      busca: RegExp('\\b${entrada.key}\\b', caseSensitive: false),
      cambia: (_) => entrada.value,
      porque: '"${entrada.key}" es español; en italiano se dice '
          '"${entrada.value}".',
    ),

  // "il amico" no existe: delante de vocal el artículo se come la vocal.
  ReglaItaliana(
    busca: RegExp(r'\b(il|lo)\s+([aeiou]\w+)', caseSensitive: false),
    cambia: (m) => "l'${m[2]}",
    porque: 'Delante de vocal, "il" y "lo" se vuelven "l\'".',
  ),
  ReglaItaliana(
    busca: RegExp(r'\bla\s+([aeiou]\w+)', caseSensitive: false),
    cambia: (m) => "l'${m[1]}",
    porque: 'Delante de vocal, "la" se vuelve "l\'".',
  ),

  // "no capisco" es el error más repetido de todos.
  ReglaItaliana(
    busca: RegExp(
      '\\bno\\s+(${despuesDeNoVaNon.join('|')})\\b',
      caseSensitive: false,
    ),
    cambia: (m) => 'non ${m[1]}',
    porque: 'Delante de un verbo, "no" es "non".',
  ),

  // La edad va con avere, igual que en español: "tengo 20 años".
  ReglaItaliana(
    busca: RegExp(r'\bsono\s+(\d+)\s+anni\b', caseSensitive: false),
    cambia: (m) => 'ho ${m[1]} anni',
    porque: 'La edad va con "avere": ho vent\'anni.',
  ),

  // "mi chiamo è Marco": se mezclan las dos formas de presentarse.
  ReglaItaliana(
    busca: RegExp(r'\bmi\s+chiamo\s+è\s+', caseSensitive: false),
    cambia: (_) => 'mi chiamo ',
    porque: 'Es "mi chiamo Marco" o "il mio nome è Marco", no las dos juntas.',
  ),
];

/// Los errores que tiene lo escrito.
///
/// Devuelve uno por error encontrado, sin repetir: si escribió "perche" tres
/// veces, se avisa una.
List<ErrorDeEscritura> revisarItaliano(String texto) {
  final encontrados = <ErrorDeEscritura>[];
  final yaAvisados = <String>{};

  for (final regla in reglasItalianas) {
    for (final caso in regla.busca.allMatches(texto)) {
      final escrito = caso[0]!;
      final va = regla.cambia(caso);
      if (escrito.toLowerCase() == va.toLowerCase()) continue;
      if (!yaAvisados.add(escrito.toLowerCase())) continue;
      encontrados.add(ErrorDeEscritura(
        escrito: escrito,
        va: va,
        porque: regla.porque,
      ));
    }
  }

  return encontrados;
}

/// Lo escrito con los errores arreglados.
///
/// Es lo que se muestra en el renglón "Correzione:". Se aplican todas las
/// reglas una tras otra; las que no encuentran nada no tocan el texto.
String italianoCorregido(String texto) {
  var salida = texto;
  for (final regla in reglasItalianas) {
    salida = salida.replaceAllMapped(regla.busca, regla.cambia);
  }
  return salida;
}

/// True si hay algo que corregir.
bool hayQueCorregir(String texto) => revisarItaliano(texto).isNotEmpty;
