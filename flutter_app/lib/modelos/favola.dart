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
      );
}

/// El catálogo entero, con de dónde salió.
class Favole {
  const Favole({
    this.favole = const [],
    this.base = '',
    this.credito = '',
    this.fuente = '',
  });

  final List<Favola> favole;

  /// De dónde se bajan. Viene del archivo y no del código para poder mudar
  /// los audios de lugar sin publicar un APK.
  final String base;

  final String credito;
  final String fuente;

  bool get hay => favole.isNotEmpty;

  String donde(Favola favola) => '$base/${favola.archivo}';
}
