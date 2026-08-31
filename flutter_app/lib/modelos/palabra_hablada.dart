/// De qué va la tanda de palabras. Se elige con las pastillas de arriba.
enum GrupoHabla { sonidos, numeros, frases }

extension EtiquetaGrupoHabla on GrupoHabla {
  String get etiqueta => switch (this) {
        GrupoHabla.sonidos => 'Sonidos',
        GrupoHabla.numeros => 'Números',
        GrupoHabla.frases => 'Frases',
      };

  /// Cómo se llama lo que aparece, para los textos de la pantalla.
  String get cosa => this == GrupoHabla.frases ? 'frase' : 'palabra';
}

/// Algo para decir en voz alta: una palabra suelta o una frase entera.
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

  /// Lo que hay que mirar: el sonido que se practica ("ci = ch", "gn = ñ"),
  /// la cifra en los números, o de qué va la frase ("en el bar").
  final String sonido;

  final GrupoHabla grupo;
}
