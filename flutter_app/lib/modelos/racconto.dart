/// Un renglón del cuento, con su traducción.
class LineaRacconto {
  const LineaRacconto({required this.italiano, required this.espanol});

  final String italiano;
  final String espanol;
}

/// Una palabra del cuento que todavía no se practicó en ninguna sección.
class PalabraGlosada {
  const PalabraGlosada({required this.italiano, required this.espanol});

  final String italiano;
  final String espanol;

  static PalabraGlosada? desdeJson(Object? item) {
    if (item is! Map<String, dynamic>) return null;
    final italiano = item['it'] as String? ?? '';
    if (italiano.isEmpty) return null;
    return PalabraGlosada(
      italiano: italiano,
      espanol: item['es'] as String? ?? '',
    );
  }
}

/// Un cuento para leer.
class Racconto {
  const Racconto({
    required this.id,
    required this.titulo,
    required this.tituloEspanol,
    required this.lineas,
    this.nivel = 1,
    this.vocabulario = const [],
    this.graduado = true,
    this.serie = '',
    this.serieTitulo = '',
    this.serieTituloEspanol = '',
    this.imagen = '',
  });

  final String id;
  final String titulo;
  final String tituloEspanol;
  final List<LineaRacconto> lineas;

  /// La obra a la que pertenece, cuando es un capítulo y no un cuento suelto.
  /// Vacío en los cuentos.
  ///
  /// Una novela son diez capítulos, pero es una sola cosa: en la lista tiene
  /// que ocupar un renglón y no diez. Los capítulos que comparten esta marca se
  /// agrupan en una tarjeta sola.
  final String serie;

  /// Cómo se llama la obra. Va repetido en cada capítulo para que el JSON siga
  /// siendo una lista plana; se usa el primero que venga.
  final String serieTitulo;
  final String serieTituloEspanol;

  /// Qué portada le toca. Es un nombre del catálogo que tiene la app; vacío o
  /// desconocido usa la de por defecto.
  final String imagen;

  bool get esCapitulo => serie.isNotEmpty;

  /// Para ordenarlos de más fácil a más difícil.
  final int nivel;

  /// Las palabras nuevas del cuento. Son las que de verdad frenan la lectura:
  /// una frase entera se adivina por contexto, una palabra suelta no.
  final List<PalabraGlosada> vocabulario;

  /// Si el cuento se compromete a usar solo palabras ya practicadas o
  /// glosadas. Los cortos sí, y un test lo verifica palabra por palabra.
  ///
  /// Los largos declaran false: una novela con todos los tiempos verbales
  /// necesitaría cientos de glosas y el panel dejaría de servir. Se glosa lo
  /// que de verdad frena y se lee con esfuerzo, que es de lo que se trata.
  /// La marca es por cuento justamente para no aflojar la garantía de los
  /// demás.
  final bool graduado;

  static Racconto? desdeJson(Map<String, dynamic> json) {
    final id = json['id'] as String? ?? '';
    final lineas = <LineaRacconto>[];
    final crudas = json['lineas'];
    if (crudas is List) {
      for (final item in crudas) {
        if (item is! Map<String, dynamic>) continue;
        final italiano = item['it'] as String? ?? '';
        if (italiano.isEmpty) continue;
        lineas.add(LineaRacconto(
          italiano: italiano,
          espanol: item['es'] as String? ?? '',
        ));
      }
    }

    // Un cuento sin id o sin renglones no se puede ni mostrar ni recordar.
    if (id.isEmpty || lineas.isEmpty) return null;

    return Racconto(
      id: id,
      titulo: json['titulo'] as String? ?? id,
      tituloEspanol: json['titulo_es'] as String? ?? '',
      nivel: json['nivel'] as int? ?? 1,
      graduado: json['graduado'] as bool? ?? true,
      serie: json['serie'] as String? ?? '',
      serieTitulo: json['serie_titulo'] as String? ?? '',
      serieTituloEspanol: json['serie_titulo_es'] as String? ?? '',
      imagen: json['imagen'] as String? ?? '',
      lineas: lineas,
      vocabulario: [
        for (final item in (json['vocabulario'] as List?) ?? const [])
          ?PalabraGlosada.desdeJson(item),
      ],
    );
  }
}

/// Una entrada de la lista de lectura: un cuento suelto, o una obra entera con
/// sus capítulos adentro.
///
/// Existe para que la novela no ocupe diez renglones de la lista. Un cuento
/// suelto también es una obra, de un capítulo: así la pantalla tiene una sola
/// clase de cosa para mostrar.
class Obra {
  const Obra({
    required this.titulo,
    required this.tituloEspanol,
    required this.capitulos,
    this.serie = '',
  });

  /// Vacío cuando es un cuento suelto.
  final String serie;

  final String titulo;
  final String tituloEspanol;

  /// En orden de lectura. Nunca está vacía.
  final List<Racconto> capitulos;

  bool get tieneCapitulos => capitulos.length > 1;

  /// Los del primer capítulo: una obra se empieza por el principio.
  int get nivel => capitulos.first.nivel;
  String get imagen => capitulos.first.imagen;

  int get cuantasLineas =>
      capitulos.fold(0, (total, c) => total + c.lineas.length);
}

/// Agrupa los capítulos de cada obra, respetando el orden en que vienen.
///
/// La obra queda en el lugar de su primer capítulo, así la lista sigue yendo
/// de más fácil a más difícil.
List<Obra> agruparEnObras(List<Racconto> racconti) {
  final obras = <Obra>[];
  final porSerie = <String, List<Racconto>>{};

  for (final racconto in racconti) {
    if (!racconto.esCapitulo) {
      obras.add(Obra(
        titulo: racconto.titulo,
        tituloEspanol: racconto.tituloEspanol,
        capitulos: [racconto],
      ));
      continue;
    }

    final capitulos = porSerie[racconto.serie];
    if (capitulos != null) {
      capitulos.add(racconto);
      continue;
    }

    // El primer capítulo es el que pone el título y el lugar en la lista.
    final nuevos = [racconto];
    porSerie[racconto.serie] = nuevos;
    obras.add(Obra(
      serie: racconto.serie,
      titulo: racconto.serieTitulo.isEmpty
          ? racconto.titulo
          : racconto.serieTitulo,
      tituloEspanol: racconto.serieTituloEspanol,
      capitulos: nuevos,
    ));
  }

  return obras;
}

/// Todo lo que trae racconti.json.
class DatosRacconti {
  const DatosRacconti({
    required this.version,
    required this.racconti,
    this.vocabularioComun = const [],
    this.nombres = const [],
  });

  final int version;
  final List<Racconto> racconti;

  /// Los mismos cuentos, pero con los capítulos de cada novela agrupados. Es lo
  /// que muestra la lista.
  List<Obra> get obras => agruparEnObras(racconti);

  /// Palabras que aparecen en varios cuentos y que ya se practican en otras
  /// secciones (las formas de avere, essere, fare y volere). No se muestran:
  /// están declaradas para que el test pueda verificar que ninguna palabra
  /// del cuento salga de la nada.
  final List<PalabraGlosada> vocabularioComun;

  /// Nombres propios (Marco, Roma). No son vocabulario que haya que aprender,
  /// pero el test necesita saber que existen.
  final List<String> nombres;

  static const vacio = DatosRacconti(version: 0, racconti: []);

  static DatosRacconti desdeJson(Map<String, dynamic> json) {
    final racconti = <Racconto>[];
    final lista = json['racconti'];
    if (lista is List) {
      for (final item in lista) {
        if (item is! Map<String, dynamic>) continue;
        final racconto = Racconto.desdeJson(item);
        if (racconto != null) racconti.add(racconto);
      }
    }
    // Por nivel, y a igual nivel en el orden en que vienen en el JSON. El
    // desempate por posición no es un detalle: los capítulos de una novela
    // comparten nivel, y sin esto podrían salir barajados.
    final porNivel = [
      for (var i = 0; i < racconti.length; i++) (i, racconti[i]),
    ]..sort((a, b) {
        final nivel = a.$2.nivel.compareTo(b.$2.nivel);
        return nivel != 0 ? nivel : a.$1.compareTo(b.$1);
      });

    return DatosRacconti(
      version: json['version'] as int? ?? 0,
      racconti: [for (final (_, r) in porNivel) r],
      vocabularioComun: [
        for (final item in (json['vocabulario_comun'] as List?) ?? const [])
          ?PalabraGlosada.desdeJson(item),
      ],
      nombres: [
        for (final item in (json['nombres'] as List?) ?? const [])
          if (item is String) item,
      ],
    );
  }
}
