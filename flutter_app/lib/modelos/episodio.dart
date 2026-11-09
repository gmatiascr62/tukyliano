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

/// Una palabra del episodio con lo que quiere decir.
///
/// No es un diccionario: son las palabras que de verdad frenan en ese
/// episodio, elegidas una por una. Tocar una palabra que no está en la lista
/// no muestra nada, así que la pantalla marca cuáles tienen algo para
/// mostrar: tocar y que no pase nada es peor que no poder tocar.
class PalabraDelEpisodio {
  const PalabraDelEpisodio({required this.italiano, required this.castellano});

  final String italiano;
  final String castellano;

  static PalabraDelEpisodio? desdeJson(Object? crudo) {
    if (crudo is! Map) return null;
    final italiano = crudo['it'];
    final castellano = crudo['es'];
    if (italiano is! String || italiano.trim().isEmpty) return null;
    if (castellano is! String || castellano.trim().isEmpty) return null;
    return PalabraDelEpisodio(italiano: italiano, castellano: castellano);
  }
}

class Episodio {
  const Episodio({
    required this.titulo,
    required this.deQueVa,
    required this.lineas,
    this.glosario = const [],
  });

  /// En italiano, como los nombres de las secciones.
  final String titulo;

  /// En castellano: es lo que decide si alguien lo escucha o no.
  final String deQueVa;

  final List<LineaDelEpisodio> lineas;

  final List<PalabraDelEpisodio> glosario;

  /// Quiénes hablan en este episodio, en el orden en que aparecen.
  ///
  /// Sale de las líneas y no de un campo aparte: así no puede quedar diciendo
  /// que hablan dos cuando habla uno solo.
  List<QuienHabla> get quienesHablan {
    final vistos = <QuienHabla>[];
    for (final linea in lineas) {
      if (!vistos.contains(linea.quien)) vistos.add(linea.quien);
    }
    return vistos;
  }

  /// Lo que se muestra debajo del título: quién habla.
  String get quienLoCuenta =>
      switch (quienesHablan.map((q) => q.nombre).toList()) {
        [final uno] => uno,
        [final uno, final otro] => '$uno y $otro',
        final todos => todos.join(', '),
      };

  /// Lo que quiere decir una palabra, si está en el glosario.
  ///
  /// Se compara en minúsculas y sin los signos de alrededor: en el texto la
  /// palabra viene pegada a una coma o a un signo de pregunta.
  ///
  /// Y se prueba también sin el artículo pegado adelante. El italiano está
  /// lleno de elisiones —l'Italia, un'idea, nell'Ottocento— y buscando la
  /// palabra entera ninguna de esas se encontraría nunca. Lo subrayado queda
  /// siendo la palabra completa con su artículo, que además se lee mejor.
  String? queQuiereDecir(String palabra) {
    final limpia = soloLasLetras(palabra);
    if (limpia.isEmpty) return null;
    final sinArticulo = limpia.split("'").last;

    for (final entrada in glosario) {
      final buscada = soloLasLetras(entrada.italiano);
      if (buscada == limpia || buscada == sinArticulo) return entrada.castellano;
    }
    return null;
  }

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

    final crudasPalabras = crudo['glosario'];
    final glosario = <PalabraDelEpisodio>[
      if (crudasPalabras is List)
        for (final cruda in crudasPalabras) ?PalabraDelEpisodio.desdeJson(cruda),
    ];

    return Episodio(
      titulo: titulo,
      deQueVa: deQueVa,
      lineas: lineas,
      glosario: glosario,
    );
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


/// Una palabra sin los signos de alrededor y en minúsculas, para poder
/// compararla: en el texto viene como "passeggiata." o "¿stai?".
String soloLasLetras(String palabra) {
  return palabra.toLowerCase().replaceAll(RegExp(r"[^a-zà-ÿ']"), '');
}
