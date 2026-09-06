/// Cada una de las prácticas de la app.
///
/// Antes eran los botones de una barra que se deslizaba arriba de todo; ahora
/// se llega a ellas desde el inicio, y las de gramática desde su propia
/// pantalla. El enum queda porque sigue siendo la forma de nombrar a cada una.
enum Seccion {
  racconti,
  hablar,
  frases,
  verbos,
  articoli,
  preposizioni,
  via,
  ci,
  ne,
  chat,
}

extension EtiquetaSeccion on Seccion {
  /// Cómo se llama en pantalla. Casi todas van en italiano, aunque el resto de
  /// la app le hable al alumno en español: son los nombres de los temas.
  String get etiqueta => switch (this) {
        Seccion.frases => 'Frasi',
        Seccion.verbos => 'Verbi',
        Seccion.articoli => 'Articoli',
        Seccion.preposizioni => 'Preposizioni',
        Seccion.via => 'Via',
        Seccion.ci => 'Ci',
        Seccion.ne => 'Ne',
        Seccion.racconti => 'Racconti',
        Seccion.hablar => 'Parlare',
        Seccion.chat => 'Chat',
      };
}
