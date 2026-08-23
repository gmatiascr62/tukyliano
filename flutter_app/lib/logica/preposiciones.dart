/// Las preposiciones simples del italiano que entran en la práctica.
///
/// Las primeras cinco se pegan con el artículo determinado (a + il = al).
/// [per] y [con] no se pegan nunca, y están justamente por eso: escribir
/// "perla nonna" es un error clásico del que viene del español.
const preposicionesSimples = ['di', 'a', 'da', 'in', 'su', 'per', 'con'];

/// Las que se contraen, en el orden de la tabla.
const preposicionesQueSeContraen = ['di', 'a', 'da', 'in', 'su'];

/// Los artículos determinados, en el orden de la tabla.
const articulosDeterminados = ['il', 'lo', 'la', "l'", 'i', 'gli', 'le'];

/// La tabla entera de preposizioni articolate.
///
/// No tiene ninguna excepción: son cinco filas por siete columnas y salen
/// todas del mismo patrón. La fila de "di" es la que ya se practica en
/// Articoli como partitivo.
const _tabla = <String, Map<String, String>>{
  'di': {
    'il': 'del', 'lo': 'dello', 'la': 'della', "l'": "dell'",
    'i': 'dei', 'gli': 'degli', 'le': 'delle',
  },
  'a': {
    'il': 'al', 'lo': 'allo', 'la': 'alla', "l'": "all'",
    'i': 'ai', 'gli': 'agli', 'le': 'alle',
  },
  'da': {
    'il': 'dal', 'lo': 'dallo', 'la': 'dalla', "l'": "dall'",
    'i': 'dai', 'gli': 'dagli', 'le': 'dalle',
  },
  'in': {
    'il': 'nel', 'lo': 'nello', 'la': 'nella', "l'": "nell'",
    'i': 'nei', 'gli': 'negli', 'le': 'nelle',
  },
  'su': {
    'il': 'sul', 'lo': 'sullo', 'la': 'sulla', "l'": "sull'",
    'i': 'sui', 'gli': 'sugli', 'le': 'sulle',
  },
};

/// Pega una preposición con un artículo: contraer('in', 'la') → 'nella'.
///
/// Devuelve null cuando esa combinación no se contrae, que es el caso de
/// [per] y [con]: ahí las dos palabras van separadas.
String? contraer(String preposicion, String articulo) =>
    _tabla[preposicion]?[articulo];

/// Todas las formas que puede tomar una preposición: la simple y, si se
/// contrae, las siete articuladas.
List<String> formasDe(String preposicion) => [
      preposicion,
      ...?_tabla[preposicion]?.values,
    ];

/// Lo contrario de [contraer]: de una forma escrita saca de qué preposición
/// viene y con qué artículo, si es que lleva alguno.
///
/// 'nella' → (in, la);  'in' → (in, null);  'perla' → null porque no existe.
({String preposicion, String? articulo})? separar(String forma) {
  if (preposicionesSimples.contains(forma)) {
    return (preposicion: forma, articulo: null);
  }
  for (final fila in _tabla.entries) {
    for (final celda in fila.value.entries) {
      if (celda.value == forma) {
        return (preposicion: fila.key, articulo: celda.key);
      }
    }
  }
  return null;
}

/// Igual que [separar], pero también entiende las que no se contraen y por eso
/// se escriben en dos palabras: "per la" → per + la.
({String preposicion, String? articulo})? analizar(String respuesta) {
  final palabras = respuesta.split(' ');
  if (palabras.length == 1) return separar(respuesta);
  if (palabras.length != 2) return null;
  if (!preposicionesSimples.contains(palabras[0])) return null;
  if (!articulosDeterminados.contains(palabras[1])) return null;
  return (preposicion: palabras[0], articulo: palabras[1]);
}

/// De qué preposición viene una respuesta: "nella" y "in" son las dos de in.
/// Es lo que deja practicar de a una preposición por vez.
String? preposicionDe(String respuesta) => analizar(respuesta)?.preposicion;

/// Cómo se explica una contracción en una línea: "in + la = nella".
String? cuentaDe(String forma) {
  final partes = separar(forma);
  if (partes == null || partes.articulo == null) return null;
  return '${partes.preposicion} + ${partes.articulo} = $forma';
}
