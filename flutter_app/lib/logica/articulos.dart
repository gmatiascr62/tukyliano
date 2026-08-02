import '../modelos/articulo.dart';

/// Qué artículo se está practicando.
///
/// El italiano no tiene indeterminado plural: para "unos libros" usa el
/// partitivo, "dei libri". Por eso [partitivoPlural] ocupa ese lugar.
enum CategoriaArticulo {
  determinado,
  indeterminado,
  partitivo,
  plural,
  partitivoPlural,
}

extension DatosCategoria on CategoriaArticulo {
  /// Los botones que se ofrecen. Son todos los que existen en esa categoría,
  /// así elegir es una decisión de verdad.
  List<String> get opciones => switch (this) {
        CategoriaArticulo.determinado => const ['il', 'lo', 'la', "l'"],
        CategoriaArticulo.indeterminado => const ['un', 'uno', 'una', "un'"],
        CategoriaArticulo.partitivo =>
          const ['del', 'dello', 'della', "dell'"],
        CategoriaArticulo.plural => const ['i', 'gli', 'le'],
        CategoriaArticulo.partitivoPlural => const ['dei', 'degli', 'delle'],
      };

  /// Cómo se arma la pregunta en español. El artículo de acá es el que le
  /// dice al alumno qué se le está pidiendo, sin necesidad de un selector.
  String articuloEspanol(bool femenino) => switch (this) {
        CategoriaArticulo.determinado => femenino ? 'la' : 'el',
        CategoriaArticulo.indeterminado => femenino ? 'una' : 'un',
        // No lleva género: "algo de pan", "algo de carne".
        CategoriaArticulo.partitivo => 'algo de',
        CategoriaArticulo.plural => femenino ? 'las' : 'los',
        CategoriaArticulo.partitivoPlural => femenino ? 'unas' : 'unos',
      };

  bool get esPartitivo =>
      this == CategoriaArticulo.partitivo ||
      this == CategoriaArticulo.partitivoPlural;

  /// Una línea extra en la explicación, porque el partitivo no se deduce de
  /// la clase: hay que saber qué es antes de que la regla sirva de algo.
  String get ayuda => switch (this) {
        CategoriaArticulo.partitivo =>
          'El partitivo es "di" pegado al artículo determinado '
              '(di + il = del) y sirve para las cosas que no se cuentan.',
        CategoriaArticulo.partitivoPlural =>
          'El italiano no tiene "unos/unas": usa el partitivo, que es "di" '
              'pegado al plural determinado (di + i = dei).',
        _ => '',
      };
}

/// Contrae "di" con un artículo determinado: il → del, gli → degli.
///
/// La app NO usa esto: en la pantalla manda lo que dice el JSON. Existe para
/// que un test revise que los partitivos del JSON estén bien escritos.
String? partitivoDe(String determinado) => const {
      'il': 'del',
      'lo': 'dello',
      'la': 'della',
      "l'": "dell'",
      'i': 'dei',
      'gli': 'degli',
      'le': 'delle',
    }[determinado];

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

  bool get _plural =>
      categoria == CategoriaArticulo.plural ||
      categoria == CategoriaArticulo.partitivoPlural;

  /// La palabra italiana que se muestra: singular o plural según la categoría.
  String get palabra =>
      _plural ? sustantivo.italianoPlural : sustantivo.italiano;

  /// El artículo que hay que elegir.
  String get correcto => switch (categoria) {
        CategoriaArticulo.determinado => sustantivo.clase.determinativo,
        CategoriaArticulo.indeterminado => sustantivo.clase.indeterminativo,
        CategoriaArticulo.partitivo => sustantivo.clase.partitivo,
        CategoriaArticulo.plural => sustantivo.clase.determinativoPlural,
        CategoriaArticulo.partitivoPlural => sustantivo.clase.partitivoPlural,
      };

  /// Cómo se pregunta: "la mochila", "unas mochilas", "algo de pan".
  String get pregunta {
    final femenino = sustantivo.espanolGenero == 'f';
    final palabraEs =
        _plural ? sustantivo.espanolPlural : sustantivo.espanol;
    return '${categoria.articuloEspanol(femenino)} $palabraEs';
  }

  /// La respuesta completa, ya armada: "lo zaino".
  String get respuesta => unir(correcto, palabra);
}

/// Si esta palabra puede preguntarse en esta categoría.
///
/// No toda palabra entra en toda categoría: "latte" no va en plural, y "un
/// azúcar" no se dice. Las que quedan afuera aparecerían con el casillero
/// vacío o preguntando algo que nadie diría.
bool sirveParaCategoria(Sustantivo s, CategoriaArticulo c) => switch (c) {
      CategoriaArticulo.determinado => true,
      // "un pane" existe, pero "un azúcar" o "un aceite" no: para las que no
      // se cuentan, el indeterminado lo reemplaza el partitivo.
      CategoriaArticulo.indeterminado => !s.incontable,
      // Al revés: el partitivo singular es justamente para esas.
      CategoriaArticulo.partitivo => s.incontable,
      CategoriaArticulo.plural ||
      CategoriaArticulo.partitivoPlural =>
        s.tienePlural && s.espanolPlural.isNotEmpty,
    };

/// Todas las preguntas que se pueden hacer con estas palabras.
List<Consigna> consignasPosibles(
  Iterable<Sustantivo> sustantivos,
  Set<CategoriaArticulo> categorias,
) =>
    [
      for (final s in sustantivos)
        for (final c in CategoriaArticulo.values)
          if (categorias.contains(c) && sirveParaCategoria(s, c))
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

/// Las palabras cuyo plural no sale de la regla. Son pocas y conocidas: si
/// aparece una nueva, va acá y no se toca [pluralDeducido].
const pluralesIrregulares = {
  // -co y -go hacen -chi/-ghi salvo cuando la fuerza de la voz cae más
  // atrás: amico, medico y psicologo son las que más se usan.
  'amico': 'amici',
  'medico': 'medici',
  'psicologo': 'psicologi',
  // La i de zio suena fuerte, así que no se come: zii, con dos.
  'zio': 'zii',
  'uomo': 'uomini',
  // Femenina terminada en -o, la excepción más famosa del italiano.
  'mano': 'mani',
};

/// Deduce el plural de una palabra italiana.
///
/// Igual que [claseDeducida], la app NO usa esto: el plural sale del JSON.
/// Está para que un test revise de a cientos y avise si alguno quedó mal
/// escrito, que es un error que si no pasa desapercibido y enseña mal.
String? pluralDeducido(String palabra, {required bool masculino}) {
  final p = palabra.toLowerCase();
  if (p.isEmpty) return null;
  if (pluralesIrregulares.containsKey(p)) return pluralesIrregulares[p];

  // Las que terminan en consonante o en vocal acentuada no cambian:
  // lo sport / gli sport, la città / le città.
  final ultima = p[p.length - 1];
  if (!_vocales.contains(ultima) || 'àèéìòù'.contains(ultima)) return p;

  final sinUltima = p.substring(0, p.length - 1);

  if (masculino) {
    // La c y la g necesitan la h para seguir sonando duras: banco → banchi.
    if (p.endsWith('co')) return '${p.substring(0, p.length - 1)}hi';
    if (p.endsWith('go')) return '${p.substring(0, p.length - 1)}hi';
    // -io con la i floja pierde la i: occhio → occhi, no "occhii".
    if (p.endsWith('io')) return '${p.substring(0, p.length - 2)}i';
    return '${sinUltima}i';
  }

  if (p.endsWith('ca')) return '${p.substring(0, p.length - 1)}he';
  if (p.endsWith('ga')) return '${p.substring(0, p.length - 1)}he';
  // -cia y -gia pierden la i si viene pegada a una consonante
  // (arancia → arance), y la conservan si viene detrás de vocal
  // (camicia → camicie).
  if (p.endsWith('cia') || p.endsWith('gia')) {
    final antes = p.length > 3 ? p[p.length - 4] : '';
    return _vocales.contains(antes)
        ? '${p.substring(0, p.length - 1)}e'
        : '${p.substring(0, p.length - 2)}e';
  }
  if (p.endsWith('a')) return '${sinUltima}e';
  // Las femeninas en -e hacen -i igual que las masculinas: chiave → chiavi.
  return '${sinUltima}i';
}
