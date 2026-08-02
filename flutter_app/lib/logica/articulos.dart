import '../modelos/articulo.dart';

/// Los artículos determinados que se ofrecen como opciones. Son todos los que
/// existen, así elegir es una decisión de verdad y no quedan dos botones.
const List<String> articulosDeterminados = ['il', 'lo', 'la', "l'"];

/// Pega el artículo con la palabra.
///
/// Los que terminan en apóstrofo van pegados (l'amico), el resto con espacio
/// (lo zaino). Escribir "l' amico" está mal y enseñaría mal.
String unir(String articulo, String palabra) =>
    articulo.endsWith("'") ? '$articulo$palabra' : '$articulo $palabra';

/// Cómo se pregunta en español: "la mochila", "el libro".
String conArticuloEspanol(Sustantivo s) =>
    '${s.espanolGenero == 'f' ? 'la' : 'el'} ${s.espanol}';

const _vocales = 'aeiouàèéìòù';

/// Deduce a qué clase pertenece una palabra mirando cómo se escribe.
///
/// La app NO usa esto: en la pantalla manda la clase que dice el JSON, que es
/// la fuente de verdad y admite excepciones. Esto existe para que un test
/// pueda revisar el JSON entero y avisar si una palabra quedó mal etiquetada.
String? claseDeducida(String palabra, {required bool masculino}) {
  final p = palabra.toLowerCase();
  if (p.isEmpty) return null;

  // La i seguida de otra vocal suena como consonante (iodio, ieri, iena), así
  // que se comporta como tal y no como vocal. Va antes que todo lo demás
  // justamente para que no la agarre el chequeo de vocal.
  final iSemiconsonante =
      p[0] == 'i' && p.length > 1 && _vocales.contains(p[1]);

  if (!iSemiconsonante) {
    // La h italiana es muda, así que cuenta como vocal para el artículo.
    final empiezaConVocal = _vocales.contains(p[0]) || p[0] == 'h';
    if (empiezaConVocal) return masculino ? 'm_vocal' : 'f_vocal';
  }

  // En femenino no importa con qué consonante empiece: siempre "la".
  if (!masculino) return 'f_consonante';

  const gruposImpuros = ['gn', 'ps', 'pn'];
  final sImpura = iSemiconsonante ||
      p[0] == 'z' ||
      p[0] == 'x' ||
      p[0] == 'y' ||
      gruposImpuros.any(p.startsWith) ||
      // s seguida de cualquier consonante.
      (p[0] == 's' && p.length > 1 && !_vocales.contains(p[1]));

  return sImpura ? 'm_s_impura' : 'm_consonante';
}
