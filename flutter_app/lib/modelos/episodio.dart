/// Un episodio del podcast: una conversación entre Giulia y Lorenzo.
///
/// No hay archivos de audio. El episodio es texto, y lo habla el motor de voz
/// del celular, el mismo que ya pronuncia los cuentos y las palabras. Por eso
/// un episodio pesa unos kilobytes, anda sin internet y no gasta ninguna
/// cuota.
///
/// Que sean dos voces y no una no es un adorno. Un diálogo tiene preguntas,
/// respuestas cortas y reacciones, que es la forma en la que de verdad se va a
/// escuchar italiano. Y además rompe la monotonía de la voz sintética, que es
/// el riesgo grande de toda esta sección: una palabra suelta suena bien, pero
/// dos minutos seguidos de una sola voz cansan.
library;

/// Quién habla. Son las dos voces italianas que la app ya tenía elegidas a
/// oído en voz.dart: no se inventaron para esto.
enum QuienHabla { giulia, lorenzo }

extension NombreDeQuienHabla on QuienHabla {
  String get nombre => switch (this) {
        QuienHabla.giulia => 'Giulia',
        QuienHabla.lorenzo => 'Lorenzo',
      };
}

/// Un turno: lo que dice uno, y qué quiere decir.
class LineaDelEpisodio {
  const LineaDelEpisodio({
    required this.quien,
    required this.italiano,
    required this.castellano,
  });

  final QuienHabla quien;
  final String italiano;
  final String castellano;

  static LineaDelEpisodio? desdeJson(Object? crudo) {
    if (crudo is! Map) return null;

    final quien = switch (crudo['quien']) {
      'giulia' => QuienHabla.giulia,
      'lorenzo' => QuienHabla.lorenzo,
      _ => null,
    };
    final italiano = crudo['it'];
    final castellano = crudo['es'];

    if (quien == null) return null;
    if (italiano is! String || italiano.trim().isEmpty) return null;
    if (castellano is! String || castellano.trim().isEmpty) return null;

    return LineaDelEpisodio(
      quien: quien,
      italiano: italiano,
      castellano: castellano,
    );
  }
}

class Episodio {
  const Episodio({
    required this.titulo,
    required this.deQueVa,
    required this.lineas,
  });

  /// En italiano, como los nombres de las secciones.
  final String titulo;

  /// En castellano: es lo que decide si alguien lo escucha o no.
  final String deQueVa;

  final List<LineaDelEpisodio> lineas;

  /// Cuántos turnos tiene.
  ///
  /// Se muestra esto y no una duración en minutos a propósito: cuánto tarda
  /// depende de la velocidad del motor de voz de cada celular, y poner un
  /// número inventado sería peor que no poner ninguno. Cuando esté medido en
  /// un teléfono de verdad, se cambia.
  int get cuantosTurnos => lineas.length;

  static Episodio? desdeJson(Object? crudo) {
    if (crudo is! Map) return null;

    final titulo = crudo['titulo'];
    final deQueVa = crudo['deQueVa'];
    if (titulo is! String || titulo.trim().isEmpty) return null;
    if (deQueVa is! String || deQueVa.trim().isEmpty) return null;

    final crudas = crudo['lineas'];
    if (crudas is! List || crudas.isEmpty) return null;

    final lineas = <LineaDelEpisodio>[];
    for (final cruda in crudas) {
      // Un renglón roto se saltea en vez de tirar abajo el episodio entero:
      // es mejor escuchar veinticinco frases que ninguna.
      if (LineaDelEpisodio.desdeJson(cruda) case final linea?) {
        lineas.add(linea);
      }
    }
    if (lineas.isEmpty) return null;

    return Episodio(titulo: titulo, deQueVa: deQueVa, lineas: lineas);
  }
}

/// Todos los episodios que trae la app.
class Podcast {
  const Podcast({required this.episodios});

  final List<Episodio> episodios;

  static Podcast desdeJson(Object? crudo) {
    if (crudo is! Map) return const Podcast(episodios: []);

    final crudos = crudo['episodios'];
    if (crudos is! List) return const Podcast(episodios: []);

    return Podcast(episodios: [
      // El '?' saltea los que no se pudieron leer: un episodio roto no tiene
      // que dejar sin podcast a los que sí están bien.
      for (final cruda in crudos) ?Episodio.desdeJson(cruda),
    ]);
  }
}
