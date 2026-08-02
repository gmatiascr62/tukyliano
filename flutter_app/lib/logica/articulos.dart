import '../modelos/articulo.dart';

/// Qué artículo se está practicando.
///
/// No hay indeterminado plural porque el italiano no lo tiene: "unos libros"
/// se dice "dei libri" (partitivo) o directamente "libri". Es otro tema.
enum CategoriaArticulo { determinado, indeterminado, plural }

extension DatosCategoria on CategoriaArticulo {
  /// Los botones que se ofrecen. Son todos los que existen en esa categoría,
  /// así elegir es una decisión de verdad.
  List<String> get opciones => switch (this) {
        CategoriaArticulo.determinado => const ['il', 'lo', 'la', "l'"],
        CategoriaArticulo.indeterminado => const ['un', 'uno', 'una', "un'"],
        CategoriaArticulo.plural => const ['i', 'gli', 'le'],
      };

  /// Cómo se arma la pregunta en español. El artículo de acá es el que le
  /// dice al alumno qué se le está pidiendo, sin necesidad de un selector.
  String articuloEspanol(bool femenino) => switch (this) {
        CategoriaArticulo.determinado => femenino ? 'la' : 'el',
        CategoriaArticulo.indeterminado => femenino ? 'una' : 'un',
        CategoriaArticulo.plural => femenino ? 'las' : 'los',
      };
}

/// Pega el artículo con la palabra.
///
/// Los que terminan en apóstrofo van pegados (l'amico), el resto con espacio
/// (lo zaino). Escribir "l' amico" está mal y enseñaría mal.
String unir(String articulo, String palabra) =>
    articulo.endsWith("'") ? '$articulo$palabra' : '$articulo $palabra';

/// Una pregunta concreta: esta palabra, en esta categoría.
class Consigna {
  const Consigna(this.sustantivo, this.categoria);

  final Sustantivo sustantivo;
  final CategoriaArticulo categoria;

  bool get _plural => categoria == CategoriaArticulo.plural;

  /// La palabra italiana que se muestra: singular o plural según la categoría.
  String get palabra =>
      _plural ? sustantivo.italianoPlural : sustantivo.italiano;

  /// El artículo que hay que elegir.
  String get correcto => switch (categoria) {
        CategoriaArticulo.determinado => sustantivo.clase.determinativo,
        CategoriaArticulo.indeterminado => sustantivo.clase.indeterminativo,
        CategoriaArticulo.plural => sustantivo.clase.determinativoPlural,
      };

  /// Cómo se pregunta: "la mochila", "una mochila", "las mochilas".
  String get pregunta {
    final femenino = sustantivo.espanolGenero == 'f';
    final palabraEs =
        _plural ? sustantivo.espanolPlural : sustantivo.espanol;
    return '${categoria.articuloEspanol(femenino)} $palabraEs';
  }

  /// La respuesta completa, ya armada: "lo zaino".
  String get respuesta => unir(correcto, palabra);
}

/// Todas las preguntas que se pueden hacer con estas palabras.
///
/// Una palabra sin plural (como "latte", que no se usa en plural) queda fuera
/// de la categoría plural en vez de aparecer con el casillero vacío.
List<Consigna> consignasPosibles(
  Iterable<Sustantivo> sustantivos,
  Set<CategoriaArticulo> categorias,
) =>
    [
      for (final s in sustantivos)
        for (final c in CategoriaArticulo.values)
          if (categorias.contains(c))
            if (c != CategoriaArticulo.plural ||
                (s.tienePlural && s.espanolPlural.isNotEmpty))
              Consigna(s, c),
    ];

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
