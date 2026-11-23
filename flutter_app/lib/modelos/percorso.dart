/// El camino: las ciudades y sus lecciones, en orden.
///
/// La app nació para Matías, que ya sabía algo, así que cada sección es una
/// herramienta suelta: los cuentos, la gramática, el chat. Para el que sabe
/// qué necesita hoy está perfecto. Para el que no sabe nada son seis puertas
/// y ninguna dice por dónde empezar.
///
/// Esto es la puerta que faltaba: una ciudad por nivel, una fila de
/// lecciones adentro de cada una, y una sola cosa para hacer ahora. No
/// reemplaza nada —la radio, el chat y los cuentos siguen donde estaban—:
/// es el orden que no existía.
library;

/// Una palabra que se enseña, con su traducción.
class PalabraDeLeccion {
  const PalabraDeLeccion({required this.italiano, required this.espanol});

  final String italiano;
  final String espanol;

  static PalabraDeLeccion? desdeJson(Object? item) {
    if (item is! Map<String, dynamic>) return null;
    final italiano = (item['it'] as String? ?? '').trim();
    if (italiano.isEmpty) return null;
    return PalabraDeLeccion(
      italiano: italiano,
      espanol: (item['es'] as String? ?? '').trim(),
    );
  }
}

/// Una frase de ejemplo, de las que cierran una lección.
///
/// Son lo que hace que una lección no sea una lista de palabras: cada una
/// termina en algo que de verdad se puede decir, y armado solo con lo que
/// ya se vio.
class FraseDeLeccion {
  const FraseDeLeccion({required this.italiano, required this.espanol});

  final String italiano;
  final String espanol;

  static FraseDeLeccion? desdeJson(Object? item) {
    if (item is! Map<String, dynamic>) return null;
    final italiano = (item['it'] as String? ?? '').trim();
    if (italiano.isEmpty) return null;
    return FraseDeLeccion(
      italiano: italiano,
      espanol: (item['es'] as String? ?? '').trim(),
    );
  }
}

/// Un escalón del camino.
///
/// Hay tres clases y se distinguen por lo que traen, no por un campo que
/// diga de qué tipo son: la que enseña palabras trae palabras, la que manda
/// a leer trae el id de un cuento, y la prueba trae su marca.
class Leccion {
  const Leccion({
    required this.id,
    required this.titulo,
    this.deQueVa = '',
    this.palabras = const [],
    this.frases = const [],
    this.racconto = '',
    this.esPrueba = false,
    this.paraAprobar = 0,
    this.cuantas = 0,
  });

  final String id;
  final String titulo;

  /// El renglón chico de abajo, que dice para qué sirve.
  final String deQueVa;

  final List<PalabraDeLeccion> palabras;
  final List<FraseDeLeccion> frases;

  /// El cuento que toca leer, cuando la lección es leer.
  final String racconto;

  final bool esPrueba;

  /// Cuántas hay que acertar y sobre cuántas, en la prueba.
  final int paraAprobar;
  final int cuantas;

  bool get enseniaPalabras => palabras.isNotEmpty;
  bool get esLectura => racconto.isNotEmpty;

  static Leccion? desdeJson(Object? item) {
    if (item is! Map<String, dynamic>) return null;
    final id = (item['id'] as String? ?? '').trim();
    if (id.isEmpty) return null;
    return Leccion(
      id: id,
      titulo: (item['titulo'] as String? ?? '').trim(),
      deQueVa: (item['deQueVa'] as String? ?? '').trim(),
      palabras: [
        for (final p in (item['palabras'] as List? ?? const []))
          ?PalabraDeLeccion.desdeJson(p),
      ],
      frases: [
        for (final f in (item['frases'] as List? ?? const []))
          ?FraseDeLeccion.desdeJson(f),
      ],
      racconto: (item['racconto'] as String? ?? '').trim(),
      esPrueba: item['prueba'] as bool? ?? false,
      paraAprobar: (item['paraAprobar'] as num?)?.toInt() ?? 0,
      cuantas: (item['cuantas'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Una ciudad del mapa.
class Ciudad {
  const Ciudad({
    required this.id,
    required this.nombre,
    required this.lecciones,
    this.subtitulo = '',
    this.nivel = 1,
    this.icono = '',
    this.x = 0,
    this.y = 0,
  });

  final String id;
  final String nombre;
  final String subtitulo;
  final int nivel;

  /// Qué dibujo le toca en el mapa.
  final String icono;

  /// Dónde va en el mapa, en partes del ancho y del alto del dibujo (no de
  /// la pantalla: el mapa se recorta de los costados y si fueran de la
  /// pantalla las ciudades se correrían).
  final double x;
  final double y;

  final List<Leccion> lecciones;

  /// Las que se hacen, sin contar la prueba. Es el denominador del "2 de 5".
  int get cuantasLecciones => lecciones.where((l) => !l.esPrueba).length;

  static Ciudad? desdeJson(Object? item) {
    if (item is! Map<String, dynamic>) return null;
    final id = (item['id'] as String? ?? '').trim();
    if (id.isEmpty) return null;
    final lecciones = [
      for (final l in (item['lecciones'] as List? ?? const []))
        ?Leccion.desdeJson(l),
    ];

    return Ciudad(
      id: id,
      nombre: (item['nombre'] as String? ?? '').trim(),
      subtitulo: (item['subtitulo'] as String? ?? '').trim(),
      nivel: (item['nivel'] as num?)?.toInt() ?? 1,
      icono: (item['icono'] as String? ?? '').trim(),
      x: (item['x'] as num?)?.toDouble() ?? 0,
      y: (item['y'] as num?)?.toDouble() ?? 0,
      lecciones: lecciones,
    );
  }
}

/// El camino entero.
class Percorso {
  const Percorso({this.version = 0, this.ciudades = const []});

  final int version;
  final List<Ciudad> ciudades;

  static const Percorso vacio = Percorso();

  static Percorso desdeJson(Map<String, dynamic> json) => Percorso(
    version: (json['version'] as num?)?.toInt() ?? 0,
    ciudades: [
      for (final c in (json['ciudades'] as List? ?? const []))
        ?Ciudad.desdeJson(c),
    ],
  );
}
