/// Una palabra para decir en voz alta.
class PalabraHablada {
  const PalabraHablada({
    required this.italiano,
    required this.espanol,
    required this.pista,
    required this.sonido,
  });

  final String italiano;
  final String espanol;

  /// Cómo suena, escrito como lo leería un argentino: "chín-cue".
  final String pista;

  /// El sonido que se está practicando: "ci = ch", "gn = ñ".
  final String sonido;
}
