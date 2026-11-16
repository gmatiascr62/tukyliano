/// El diccionario italiano ↔ español que viaja adentro de la app.
///
/// Reemplaza a la IA para lo que está entre almohadillas. Una IA traduciendo
/// una palabra es matar una mosca a cañonazos: tarda, gasta cuota, necesita
/// internet y de vez en cuando inventa. Un diccionario contesta en el acto,
/// sin señal y siempre lo mismo.
///
/// Sale de tres lados: FreeDict/WikDict (de Wiktionary, CC BY-SA 3.0), las
/// formas conjugadas de verbos.json —que es lo que a FreeDict le falta, tiene
/// "andare" y no "andato"— y una lista escrita a mano con las palabras de
/// función y el español rioplatense, porque el de Wiktionary es neutro y dice
/// "coche".
class Diccionario {
  const Diccionario({
    this.italiano = const {},
    this.espanol = const {},
    this.formas = const {},
    this.credito = '',
    this.licencia = '',
    this.fuente = '',
    this.creditoDeLasFormas = '',
  });

  /// Palabra italiana (en minúsculas y sin tildes) → qué quiere decir.
  final Map<String, List<String>> italiano;

  /// Palabra española (en minúsculas y sin tildes) → cómo se dice.
  final Map<String, List<String>> espanol;

  /// Forma conjugada → de qué palabra viene. "abbia" → "avere".
  ///
  /// Es lo que convierte un diccionario de 14.000 lemas en algo que sirve
  /// para leer: un diccionario lista "avere", y el texto dice "abbia",
  /// "avesse", "avrebbe", "avean". Medido sobre las veintidós fábulas, esta
  /// tabla sube lo que se encuentra del 52% al 69%, y lo que suma son justo
  /// las conjugaciones y los apócopes del verso ("ancor", "aver",
  /// "andiam") que ninguna regla de plurales puede adivinar.
  final Map<String, String> formas;

  /// A quién hay que darle el crédito. La licencia obliga y además
  /// corresponde.
  final String credito;
  final String licencia;
  final String fuente;

  /// Las formas salen de otra fuente que las traducciones, y la licencia
  /// obliga a decirlo aparte.
  final String creditoDeLasFormas;

  bool get vacio => italiano.isEmpty && espanol.isEmpty;

  int get cuantasPalabras => italiano.length + espanol.length;

  /// El mismo diccionario con la tabla de formas puesta.
  ///
  /// Las formas viajan en otro archivo porque pesan como el diccionario
  /// entero y hay pantallas que no las necesitan.
  Diccionario conFormas(Map<String, String> cuales, {String credito = ''}) =>
      Diccionario(
        italiano: italiano,
        espanol: espanol,
        formas: cuales,
        credito: this.credito,
        licencia: licencia,
        fuente: fuente,
        creditoDeLasFormas: credito,
      );

  static Diccionario desdeJson(Map<String, dynamic> datos) {
    Map<String, List<String>> lado(String cual) => {
          for (final entrada in (datos[cual] as Map? ?? {}).entries)
            entrada.key as String: [
              for (final t in entrada.value as List) '$t',
            ],
        };

    return Diccionario(
      italiano: lado('it'),
      espanol: lado('es'),
      credito: datos['credito'] as String? ?? '',
      licencia: datos['licencia'] as String? ?? '',
      fuente: datos['fuente'] as String? ?? '',
    );
  }
}
