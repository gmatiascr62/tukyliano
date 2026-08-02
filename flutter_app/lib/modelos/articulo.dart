/// Los artículos que le corresponden a un grupo de sustantivos, más la regla
/// que lo explica.
///
/// Las clases están en el JSON una sola vez y cada sustantivo apunta a la
/// suya: así agregar una palabra es elegir su clase, y la explicación de la
/// regla se escribe en un solo lugar.
class ClaseArticulo {
  const ClaseArticulo({
    required this.nombre,
    required this.determinativo,
    required this.indeterminativo,
    required this.determinativoPlural,
    required this.explicacion,
    this.partitivo = '',
    this.partitivoPlural = '',
  });

  final String nombre;
  final String determinativo;
  final String indeterminativo;
  final String determinativoPlural;
  final String explicacion;

  /// El partitivo es "di" pegado al determinado: di + il = del. Está escrito
  /// en el JSON en vez de calculado para que la fuente de verdad siga siendo
  /// una sola, pero un test verifica que la contracción esté bien hecha.
  final String partitivo;
  final String partitivoPlural;

  static ClaseArticulo desdeJson(String nombre, Map<String, dynamic> json) =>
      ClaseArticulo(
        nombre: nombre,
        determinativo: json['determinativo'] as String? ?? '',
        indeterminativo: json['indeterminativo'] as String? ?? '',
        determinativoPlural: json['determinativo_plural'] as String? ?? '',
        partitivo: json['partitivo'] as String? ?? '',
        partitivoPlural: json['partitivo_plural'] as String? ?? '',
        explicacion: json['explicacion'] as String? ?? '',
      );
}

/// Un sustantivo para practicar el artículo que le corresponde.
class Sustantivo {
  const Sustantivo({
    required this.italiano,
    required this.espanol,
    required this.clase,
    this.italianoPlural = '',
    this.espanolPlural = '',
    this.espanolGenero = 'm',
    this.nota = '',
    this.incontable = false,
  });

  final String italiano;
  final String espanol;
  final ClaseArticulo clase;

  /// Vacío cuando la palabra no se usa en plural (por ejemplo "latte").
  final String italianoPlural;
  final String espanolPlural;

  /// Género en español: sirve para armar la pregunta ("la mochila", "el
  /// libro"). No siempre coincide con el italiano, y ahí está la gracia.
  final String espanolGenero;

  /// Aclaración propia de esta palabra, si tiene algo que valga la pena
  /// decir aparte de la regla general.
  final String nota;

  /// Las que no se cuentan (pane, latte, zucchero): no van en plural ni con
  /// el indeterminado, pero son justamente las que piden el partitivo
  /// singular ("algo de pan" → del pane).
  final bool incontable;

  bool get tienePlural => italianoPlural.isNotEmpty;

  /// True si el género no coincide con el del español. Son las palabras que
  /// más hacen tropezar.
  bool get generoEnganoso =>
      clase.nombre.startsWith('m') != (espanolGenero == 'm');
}

/// Todo lo que trae articoli.json.
class DatosArticoli {
  const DatosArticoli({
    required this.version,
    required this.clases,
    required this.sustantivos,
  });

  final int version;
  final Map<String, ClaseArticulo> clases;
  final List<Sustantivo> sustantivos;

  static const vacio =
      DatosArticoli(version: 0, clases: {}, sustantivos: []);

  static DatosArticoli desdeJson(Map<String, dynamic> json) {
    final clases = <String, ClaseArticulo>{};
    final crudas = json['clases'];
    if (crudas is Map<String, dynamic>) {
      crudas.forEach((nombre, datos) {
        if (datos is Map<String, dynamic>) {
          clases[nombre] = ClaseArticulo.desdeJson(nombre, datos);
        }
      });
    }

    final sustantivos = <Sustantivo>[];
    final lista = json['sustantivos'];
    if (lista is List) {
      for (final item in lista) {
        if (item is! Map<String, dynamic>) continue;
        final clase = clases[item['clase']];
        final italiano = item['it'] as String? ?? '';
        // Sin clase no hay artículo que enseñar, así que la palabra se
        // descarta en vez de romper la pantalla.
        if (clase == null || italiano.isEmpty) continue;

        sustantivos.add(Sustantivo(
          italiano: italiano,
          espanol: item['es'] as String? ?? italiano,
          clase: clase,
          italianoPlural: item['it_plural'] as String? ?? '',
          espanolPlural: item['es_plural'] as String? ?? '',
          espanolGenero: item['es_genero'] as String? ?? 'm',
          nota: item['nota'] as String? ?? '',
          incontable: item['incontable'] as bool? ?? false,
        ));
      }
    }

    return DatosArticoli(
      version: json['version'] as int? ?? 0,
      clases: clases,
      sustantivos: sustantivos,
    );
  }
}
