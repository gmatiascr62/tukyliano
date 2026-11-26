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
  const PalabraDeLeccion({
    required this.italiano,
    required this.espanol,
    this.suena = '',
  });

  final String italiano;
  final String espanol;

  /// Cómo se pronuncia, escrito como lo leería un argentino: "chao",
  /// "ñoqui", "peshe". Vacío cuando se lee igual que en castellano.
  ///
  /// No es alfabeto fonético a propósito. Un principiante no sabe leer
  /// /ˈtʃao/ y no tiene por qué aprenderlo antes de poder decir "ciao".
  final String suena;

  static PalabraDeLeccion? desdeJson(Object? item) {
    if (item is! Map<String, dynamic>) return null;
    final italiano = (item['it'] as String? ?? '').trim();
    if (italiano.isEmpty) return null;
    return PalabraDeLeccion(
      italiano: italiano,
      espanol: (item['es'] as String? ?? '').trim(),
      suena: (item['suena'] as String? ?? '').trim(),
    );
  }
}

/// Una frase de ejemplo, de las que cierran una lección.
///
/// Son lo que hace que una lección no sea una lista de palabras: cada una
/// termina en algo que de verdad se puede decir, y armado solo con lo que
/// ya se vio.
class FraseDeLeccion {
  const FraseDeLeccion({
    required this.italiano,
    required this.espanol,
    this.suena = '',
  });

  final String italiano;
  final String espanol;

  /// Cómo suena, igual que en [PalabraDeLeccion.suena].
  final String suena;

  static FraseDeLeccion? desdeJson(Object? item) {
    if (item is! Map<String, dynamic>) return null;
    final italiano = (item['it'] as String? ?? '').trim();
    if (italiano.isEmpty) return null;
    return FraseDeLeccion(
      italiano: italiano,
      espanol: (item['es'] as String? ?? '').trim(),
      suena: (item['suena'] as String? ?? '').trim(),
    );
  }
}

/// Una regla explicada, con sus ejemplos.
///
/// Es lo que le faltaba a la app para poder empezar de cero. Una lección
/// que solo muestra palabras sirve para el que ya sabe leer italiano; el
/// que no, pronuncia "ciao" como lo ve escrito y nadie lo corrige.
///
/// Una idea por tarjeta y tres ejemplos: si es un párrafo, no se lee.
class Explicacion {
  const Explicacion({
    required this.titulo,
    required this.texto,
    this.ejemplos = const [],
  });

  final String titulo;
  final String texto;
  final List<FraseDeLeccion> ejemplos;

  static Explicacion? desdeJson(Object? item) {
    if (item is! Map<String, dynamic>) return null;
    final titulo = (item['titulo'] as String? ?? '').trim();
    final texto = (item['texto'] as String? ?? '').trim();
    if (titulo.isEmpty && texto.isEmpty) return null;
    return Explicacion(
      titulo: titulo,
      texto: texto,
      ejemplos: [
        for (final e in (item['ejemplos'] as List? ?? const []))
          ?FraseDeLeccion.desdeJson(e),
      ],
    );
  }
}

/// Un renglón de un diálogo: quién habla y qué dice.
class RenglonDeDialogo {
  const RenglonDeDialogo({
    required this.quien,
    required this.italiano,
    required this.espanol,
  });

  final String quien;
  final String italiano;
  final String espanol;

  static RenglonDeDialogo? desdeJson(Object? item) {
    if (item is! Map<String, dynamic>) return null;
    final italiano = (item['it'] as String? ?? '').trim();
    if (italiano.isEmpty) return null;
    return RenglonDeDialogo(
      quien: (item['quien'] as String? ?? '').trim(),
      italiano: italiano,
      espanol: (item['es'] as String? ?? '').trim(),
    );
  }
}

/// Una conversación corta de una situación real.
class Dialogo {
  const Dialogo({
    required this.situacion,
    required this.renglones,
    this.preguntas = const [],
  });

  /// Dónde pasa: "En el bar", "En la calle". Es lo que le da sentido.
  final String situacion;

  final List<RenglonDeDialogo> renglones;

  /// Las de comprensión, que se hacen después de leerlo.
  final List<Pregunta> preguntas;

  static Dialogo? desdeJson(Object? item) {
    if (item is! Map<String, dynamic>) return null;
    final renglones = [
      for (final r in (item['renglones'] as List? ?? const []))
        ?RenglonDeDialogo.desdeJson(r),
    ];
    if (renglones.isEmpty) return null;
    return Dialogo(
      situacion: (item['situacion'] as String? ?? '').trim(),
      renglones: renglones,
      preguntas: [
        for (final p in (item['preguntas'] as List? ?? const []))
          ?Pregunta.desdeJson(p),
      ],
    );
  }
}

/// Un ejercicio escrito a mano: completar un hueco, elegir qué contestar,
/// entender un diálogo.
///
/// A diferencia de preguntar una palabra —que la arma sola la app— estos
/// hay que escribirlos: la gracia está en la situación y en las opciones
/// de al lado, que tienen que ser errores creíbles.
class Pregunta {
  const Pregunta({
    required this.enunciado,
    required this.opciones,
    required this.correcta,
    this.consigna = '',
    this.porque = '',
  });

  /// La consigna de arriba: "Completá", "¿Qué le contestás?".
  final String consigna;

  /// Lo que se lee en la tarjeta. Con ___ donde va el hueco.
  final String enunciado;

  final List<String> opciones;
  final String correcta;

  /// Por qué es esa. Se muestra después de contestar, bien o mal.
  final String porque;

  static Pregunta? desdeJson(Object? item) {
    if (item is! Map<String, dynamic>) return null;
    final enunciado = (item['enunciado'] as String? ?? '').trim();
    final correcta = (item['correcta'] as String? ?? '').trim();
    final opciones = [
      for (final o in (item['opciones'] as List? ?? const []))
        if (o is String && o.trim().isNotEmpty) o.trim(),
    ];
    if (enunciado.isEmpty || correcta.isEmpty || opciones.length < 2) {
      return null;
    }
    return Pregunta(
      consigna: (item['consigna'] as String? ?? '').trim(),
      enunciado: enunciado,
      opciones: opciones,
      correcta: correcta,
      porque: (item['porque'] as String? ?? '').trim(),
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
    this.explicaciones = const [],
    this.palabras = const [],
    this.frases = const [],
    this.dialogos = const [],
    this.preguntas = const [],
    this.racconto = '',
    this.esPrueba = false,
    this.integradora = false,
    this.paraAprobar = 0,
    this.cuantas = 0,
  });

  final String id;
  final String titulo;

  /// El renglón chico de abajo, que dice para qué sirve.
  final String deQueVa;

  /// Las reglas, que van primero: lo que hay que entender antes de
  /// practicar nada.
  final List<Explicacion> explicaciones;

  final List<PalabraDeLeccion> palabras;
  final List<FraseDeLeccion> frases;

  /// Las conversaciones de situación, que van después del vocabulario.
  final List<Dialogo> dialogos;

  /// Los ejercicios escritos a mano, que no se pueden generar solos.
  final List<Pregunta> preguntas;

  /// El cuento que toca leer, cuando la lección es leer.
  final String racconto;

  final bool esPrueba;

  /// La prueba que cierra un nivel entero: pregunta lo de todas las
  /// ciudades del nivel, no solo lo de la suya.
  final bool integradora;

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
      explicaciones: [
        for (final e in (item['explicaciones'] as List? ?? const []))
          ?Explicacion.desdeJson(e),
      ],
      dialogos: [
        for (final d in (item['dialogos'] as List? ?? const []))
          ?Dialogo.desdeJson(d),
      ],
      preguntas: [
        for (final p in (item['preguntas'] as List? ?? const []))
          ?Pregunta.desdeJson(p),
      ],
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
      integradora: item['integradora'] as bool? ?? false,
      paraAprobar: (item['paraAprobar'] as num?)?.toInt() ?? 0,
      cuantas: (item['cuantas'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Una foto del álbum del viaje: el premio de cada dos lecciones.
///
/// El archivo es el nombre pelado, sin carpeta: la pantalla sabe dónde
/// viven las fotos, el camino no tiene por qué.
class Foto {
  const Foto({required this.archivo, this.texto = ''});

  final String archivo;
  final String texto;

  static Foto? desdeJson(Object? item) {
    if (item is! Map<String, dynamic>) return null;
    final archivo = (item['archivo'] as String? ?? '').trim();
    if (archivo.isEmpty) return null;
    return Foto(
      archivo: archivo,
      texto: (item['texto'] as String? ?? '').trim(),
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
    this.racconto = '',
    this.album = const [],
    this.x = 0,
    this.y = 0,
  });

  final String id;
  final String nombre;
  final String subtitulo;
  final int nivel;

  /// Qué dibujo le toca en el mapa.
  final String icono;

  /// El cuento que abre la prueba de esta ciudad, por id.
  ///
  /// Los racconti son el premio del camino: están cerrados hasta que se
  /// aprueba la ciudad que los enseña. Leer uno antes no sería un premio,
  /// sería un examen con palabras que no se dieron.
  final String racconto;

  /// Dónde va en el mapa, en partes del ancho y del alto del dibujo (no de
  /// la pantalla: el mapa se recorta de los costados y si fueran de la
  /// pantalla las ciudades se correrían).
  final double x;
  final double y;

  /// Las fotos que el perrito saca en esta ciudad, en orden. Se abre una
  /// cada dos lecciones.
  final List<Foto> album;

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
      racconto: (item['racconto'] as String? ?? '').trim(),
      album: [
        for (final f in (item['album'] as List? ?? const [])) ?Foto.desdeJson(f),
      ],
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
