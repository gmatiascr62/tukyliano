/// De qué va la tanda de palabras. Se elige con las pastillas de arriba.
enum GrupoHabla { sonidos, numeros }

extension EtiquetaGrupoHabla on GrupoHabla {
  String get etiqueta => switch (this) {
        GrupoHabla.sonidos => 'Sonidos',
        GrupoHabla.numeros => 'Números',
      };
}

/// Una palabra para decir en voz alta.
class PalabraHablada {
  const PalabraHablada({
    required this.italiano,
    required this.espanol,
    required this.pista,
    required this.sonido,
    this.grupo = GrupoHabla.sonidos,
  });

  final String italiano;
  final String espanol;

  /// Cómo suena, escrito como lo leería un argentino: "chín-cue".
  final String pista;

  /// Lo que hay que mirar de esta palabra: el sonido que se practica
  /// ("ci = ch", "gn = ñ") o, en los números, la cifra.
  final String sonido;

  final GrupoHabla grupo;
}
