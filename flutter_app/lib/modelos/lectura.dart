/// Un renglón de la fábula, y en qué momento se dice.
///
/// Los tiempos son opcionales porque marcarlos es trabajo a mano: hay que
/// escuchar la fábula e ir anotando en qué segundo arranca cada verso. Las
/// que todavía no están marcadas muestran el texto quieto, que ya sirve.
class RenglonDeLectura {
  const RenglonDeLectura({required this.texto, this.desde, this.hasta});

  final String texto;
  final Duration? desde;
  final Duration? hasta;

  bool get tieneTiempo => desde != null;

  /// Si en este momento se está diciendo este renglón.
  bool suenaEn(Duration donde) {
    final arranca = desde;
    if (arranca == null) return false;
    final termina = hasta;
    return donde >= arranca && (termina == null || donde < termina);
  }

  static Duration? _comoDuracion(Object? segundos) {
    if (segundos is! num) return null;
    return Duration(milliseconds: (segundos * 1000).round());
  }

  static RenglonDeLectura desdeJson(Object? datos) {
    if (datos is String) return RenglonDeLectura(texto: datos);
    final mapa = datos! as Map<String, dynamic>;
    return RenglonDeLectura(
      texto: mapa['t'] as String? ?? '',
      desde: _comoDuracion(mapa['desde']),
      hasta: _comoDuracion(mapa['hasta']),
    );
  }
}

/// Una fábula de La Fontaine, leída en italiano.
///
/// Son lo mejor que hay para empezar a escuchar italiano de verdad: duran
/// entre uno y tres minutos, cuentan historias que uno ya conoce —la cigarra
/// y la hormiga, el cuervo y el zorro— y cada una se cierra sola. Si no
/// entendiste una, perdiste dos minutos, no un capítulo.
///
/// Las graban voluntarios de LibriVox y son de dominio público: las obras
/// hace rato y las grabaciones a propósito. Por eso pueden viajar adentro de
/// la app sin pedirle permiso a nadie, al revés que la radio.
class Lectura {
  const Lectura({
    required this.id,
    required this.titulo,
    required this.libro,
    required this.archivo,
    required this.segundos,
    required this.bytes,
    this.renglones = const [],
    this.tituloDesde,
    this.tituloHasta,
  });

  final String id;
  final String titulo;

  /// De cuál de los doce libros de La Fontaine sale.
  final int libro;

  /// Cómo se llama el mp3. Es lo que se le pide al servidor y lo que se
  /// guarda en el celular.
  final String archivo;

  final int segundos;
  final int bytes;

  /// El texto, renglón por renglón.
  ///
  /// Viaja en la app y no se baja: son unos pocos KB y así se puede leer la
  /// fábula aunque el audio no esté bajado todavía.
  ///
  /// Está en verso, porque la traducción que leen es la de Emilio de Marchi
  /// y es poesía rimada. Para seguir el audio con la vista sirve igual; para
  /// aprender a hablar, el italiano de Pinocchio es mejor material.
  final List<RenglonDeLectura> renglones;

  /// Cuánto antes del título se empieza a reproducir.
  ///
  /// El alineado marca el título tarde, y no por imprecisión de whisper sino
  /// por una razón concreta: el título sale del índice del libro y el lector
  /// lee el del capítulo, que no siempre dice lo mismo. El capítulo 2 es el
  /// caso claro —el índice dice "Maestro Ciliegia" y el lector dice "Mastro
  /// Ciliegia"—, así que la primera palabra no coincide y el alineado
  /// arranca en la segunda.
  ///
  /// Medido contra la transcripción del audio en los tres capítulos de los
  /// que se tiene: el alineado llega 0,78 segundos tarde en el 1, 1,92 en el
  /// 2 y 2,54 en el 33. El error crece con el largo del título, que encaja
  /// con la explicación: cuanto más largo, más chances de que las primeras
  /// palabras no coincidan.
  ///
  /// De ahí cuatro segundos y no dos y medio. Dos y medio parecía alcanzar
  /// con los dos primeros capítulos y con el 33 se quedaba corto por cuatro
  /// centésimas, que es la clase de margen que no es margen.
  ///
  /// Pasarse cuesta poco: lo que se oye de más es el final de la
  /// presentación de LibriVox —el nombre de quien lee— y el "Capitolo
  /// primo". Quedarse corto, en cambio, se come el principio del título,
  /// que es justo lo que se vino a arreglar.
  static const _elAire = Duration(seconds: 4);

  /// Cuándo el lector lee el título, en las colecciones donde lo lee.
  ///
  /// En Pinocchio el lector dice "Capitolo primo" y después el título
  /// entero, y recién ahí empieza el cuento. El título no es un renglón de
  /// la lista —es el encabezado, y como renglón aparecería dos veces— pero
  /// tiene su momento, y sin él la app arrancaba pasado el título: quedaba
  /// escrito arriba sin que se oyera nunca.
  final Duration? tituloDesde;
  final Duration? tituloHasta;

  /// Si en este momento se está leyendo el título.
  bool tituloSuenaEn(Duration donde) {
    final arranca = tituloDesde;
    final termina = tituloHasta;
    if (arranca == null || termina == null) return false;
    return donde >= arranca && donde < termina;
  }

  bool get tieneTexto => renglones.isNotEmpty;

  /// Si se sabe en qué momento se dice cada renglón.
  bool get sigueElAudio => renglones.any((r) => r.tieneTiempo);

  /// Cuál se está diciendo en este momento. -1 si ninguno: antes del primer
  /// verso está la presentación de LibriVox, y al final el cierre.
  int cualSuena(Duration donde) {
    for (var i = 0; i < renglones.length; i++) {
      if (renglones[i].suenaEn(donde)) return i;
    }
    return -1;
  }

  /// Dónde arranca lo que se vino a escuchar. Null si no está marcado.
  ///
  /// Importa porque antes va la presentación de LibriVox —quién lee, de qué
  /// libro—, y en una fábula de minuto y medio son dieciséis segundos de
  /// espera antes de que empiece lo que se vino a escuchar.
  ///
  /// Donde el lector lee el título, eso **también** es lo que se vino a
  /// escuchar: es la primera línea del capítulo, está escrita arriba y hay
  /// que oírla. Saltearla dejaba una frase a la vista que no sonaba nunca.
  Duration? get dondeEmpiezaDeVerdad {
    final elTitulo = tituloDesde;
    if (elTitulo != null) {
      final conAire = elTitulo - _elAire;
      return conAire < Duration.zero ? Duration.zero : conAire;
    }
    for (final renglon in renglones) {
      if (renglon.desde != null) return renglon.desde;
    }
    return null;
  }

  /// "1:27", para mostrar al lado del título.
  String get cuantoDura {
    final minutos = segundos ~/ 60;
    final resto = segundos % 60;
    return '$minutos:${resto.toString().padLeft(2, '0')}';
  }

  /// "682 KB". Importa: el que la baja está gastando sus datos.
  String get cuantoPesa {
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.round()} KB';
    return '${(kb / 1024).toStringAsFixed(1)} MB';
  }

  static Lectura desdeJson(Map<String, dynamic> datos) => Lectura(
        id: datos['id'] as String,
        titulo: datos['titulo'] as String,
        libro: datos['libro'] as int? ?? 1,
        archivo: datos['archivo'] as String,
        segundos: datos['segundos'] as int? ?? 0,
        bytes: datos['bytes'] as int? ?? 0,
        renglones: [
          for (final r in (datos['renglones'] as List? ?? []))
            RenglonDeLectura.desdeJson(r),
        ],
        tituloDesde: RenglonDeLectura._comoDuracion(datos['tituloDesde']),
        tituloHasta: RenglonDeLectura._comoDuracion(datos['tituloHasta']),
      );
}

/// El catálogo entero, con de dónde salió.
class Lecturas {
  const Lecturas({
    this.lecturas = const [],
    this.base = '',
    this.credito = '',
    this.fuente = '',
    this.textoDe = '',
    this.deQuien = '',
  });

  final List<Lectura> lecturas;

  /// De dónde se bajan. Viene del archivo y no del código para poder mudar
  /// los audios de lugar sin publicar un APK.
  final String base;

  final String credito;
  final String fuente;

  /// Quién firma lo que suena, para la pantalla bloqueada y los auriculares.
  ///
  /// Viene del catálogo y no del código porque cambia con la colección:
  /// las fábulas son de La Fontaine y Pinocchio es de Collodi. Antes
  /// estaba clavado, y el día que entró la segunda colección iba a decir
  /// que Pinocchio lo escribió La Fontaine.
  final String deQuien;

  /// De dónde salió el texto, que no es el mismo lugar que el audio.
  final String textoDe;

  bool get hay => lecturas.isNotEmpty;

  String donde(Lectura lectura) => '$base/${lectura.archivo}';
}
