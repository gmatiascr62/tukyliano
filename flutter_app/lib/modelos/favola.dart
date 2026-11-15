/// Un renglón de la fábula, y en qué momento se dice.
///
/// Los tiempos son opcionales porque marcarlos es trabajo a mano: hay que
/// escuchar la fábula e ir anotando en qué segundo arranca cada verso. Las
/// que todavía no están marcadas muestran el texto quieto, que ya sirve.
class RenglonDeFavola {
  const RenglonDeFavola({required this.texto, this.desde, this.hasta});

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

  static RenglonDeFavola desdeJson(Object? datos) {
    if (datos is String) return RenglonDeFavola(texto: datos);
    final mapa = datos! as Map<String, dynamic>;
    return RenglonDeFavola(
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
class Favola {
  const Favola({
    required this.id,
    required this.titulo,
    required this.libro,
    required this.archivo,
    required this.segundos,
    required this.bytes,
    this.renglones = const [],
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
  final List<RenglonDeFavola> renglones;

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

  /// Dónde arranca el primer verso. Null si no está marcado.
  ///
  /// Importa porque antes va la presentación de LibriVox —quién lee, de qué
  /// libro—, y en una fábula de minuto y medio son dieciséis segundos de
  /// espera antes de que empiece lo que se vino a escuchar.
  Duration? get dondeEmpiezaDeVerdad {
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

  static Favola desdeJson(Map<String, dynamic> datos) => Favola(
        id: datos['id'] as String,
        titulo: datos['titulo'] as String,
        libro: datos['libro'] as int? ?? 1,
        archivo: datos['archivo'] as String,
        segundos: datos['segundos'] as int? ?? 0,
        bytes: datos['bytes'] as int? ?? 0,
        renglones: [
          for (final r in (datos['renglones'] as List? ?? []))
            RenglonDeFavola.desdeJson(r),
        ],
      );
}

/// El catálogo entero, con de dónde salió.
class Favole {
  const Favole({
    this.favole = const [],
    this.base = '',
    this.credito = '',
    this.fuente = '',
    this.textoDe = '',
  });

  final List<Favola> favole;

  /// De dónde se bajan. Viene del archivo y no del código para poder mudar
  /// los audios de lugar sin publicar un APK.
  final String base;

  final String credito;
  final String fuente;

  /// De dónde salió el texto, que no es el mismo lugar que el audio.
  final String textoDe;

  bool get hay => favole.isNotEmpty;

  String donde(Favola favola) => '$base/${favola.archivo}';
}
