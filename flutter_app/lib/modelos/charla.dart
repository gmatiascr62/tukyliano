/// Una charla guionada: una escena con sus pasos y sus ramas.
///
/// Es la contracara del chat con IA. La IA improvisa y a veces corrige mal; un
/// guion no improvisa pero no se equivoca nunca, porque la frase correcta está
/// escrita de antemano. Para alguien que recién arranca eso vale más: una
/// corrección equivocada con cara de autoridad enseña el error.
class Charla {
  const Charla({
    required this.id,
    required this.titulo,
    required this.donde,
    required this.primero,
    required this.pasos,
  });

  final String id;

  /// Cómo se llama la escena: "Al bar".
  final String titulo;

  /// Dónde estás parado, en castellano. Se muestra al empezar.
  final String donde;

  /// El paso con el que arranca.
  final String primero;

  final List<Paso> pasos;

  /// El paso con ese id, o null si el guion lo nombra y no existe.
  Paso? paso(String id) {
    for (final paso in pasos) {
      if (paso.id == id) return paso;
    }
    return null;
  }

  static Charla desdeJson(Map<String, dynamic> datos) => Charla(
        id: datos['id'] as String,
        titulo: datos['titulo'] as String,
        donde: datos['donde'] as String? ?? '',
        primero: datos['primero'] as String,
        pasos: [
          for (final paso in datos['pasos'] as List)
            Paso.desdeJson(paso as Map<String, dynamic>),
        ],
      );
}

/// Un turno: lo que dice Tuky y lo que se le puede contestar.
class Paso {
  const Paso({
    required this.id,
    required this.dice,
    required this.espanol,
    required this.respuestas,
  });

  final String id;

  /// Lo que dice Tuky, en italiano.
  final String dice;

  /// Qué quiere decir, en castellano.
  final String espanol;

  final List<Respuesta> respuestas;

  /// El último paso de la escena: Tuky se despide y no hay nada que contestar.
  bool get esElFinal => respuestas.isEmpty;

  static Paso desdeJson(Map<String, dynamic> datos) => Paso(
        id: datos['id'] as String,
        dice: datos['dice'] as String,
        espanol: datos['espanol'] as String? ?? '',
        respuestas: [
          for (final respuesta in datos['respuestas'] as List? ?? [])
            Respuesta.desdeJson(respuesta as Map<String, dynamic>),
        ],
      );
}

/// Una de las cosas que se pueden contestar en un paso.
class Respuesta {
  const Respuesta({
    required this.texto,
    required this.espanol,
    required this.claves,
    required this.sigue,
  });

  /// La frase bien dicha. Es la que se muestra como corrección, y por eso la
  /// corrección nunca puede estar mal: está escrita acá.
  final String texto;

  final String espanol;

  /// Las palabras que tienen que aparecer para saber que se quiso decir esto.
  ///
  /// No es la frase entera a propósito: con "caffe" alcanza para entender que
  /// pidió un café, haya escrito "un caffè per favore", "voglio un caffè" o
  /// "caffè". Lo que se escribió se compara después contra [texto] para ver si
  /// además lo dijo bien.
  final List<String> claves;

  /// A qué paso se va si contesta esto.
  final String sigue;

  static Respuesta desdeJson(Map<String, dynamic> datos) => Respuesta(
        texto: datos['texto'] as String,
        espanol: datos['espanol'] as String? ?? '',
        claves: [
          for (final clave in datos['claves'] as List? ?? []) '$clave',
        ],
        sigue: datos['sigue'] as String,
      );
}
