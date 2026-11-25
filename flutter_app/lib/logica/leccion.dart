/// Qué pasa adentro de una lección, paso por paso.
///
/// La pantalla no decide nada de esto: recibe la lista hecha y va mostrando
/// uno atrás del otro. Está acá y no adentro de la pantalla porque el orden
/// de los pasos es lo que hace o rompe una lección —una palabra que se
/// pregunta antes de mostrarse, una frase para armar con una palabra que no
/// se enseñó— y eso se prueba con un test, no mirando.
library;

import 'dart:math';

import '../modelos/percorso.dart';
import 'armar_frase.dart';

/// Un paso de la lección.
sealed class Paso {
  const Paso();
}

/// Leer una regla. Va antes que todo lo demás: es lo que hay que entender
/// para que el resto de la lección no sea adivinar.
class MostrarExplicacion extends Paso {
  const MostrarExplicacion(this.explicacion);

  final Explicacion explicacion;
}

/// Mostrar una palabra nueva. No hay nada que contestar: se mira, se
/// escucha y se sigue.
class MostrarPalabra extends Paso {
  const MostrarPalabra(this.palabra);

  final PalabraDeLeccion palabra;
}

/// Leer una conversación corta de una situación real.
class MostrarDialogo extends Paso {
  const MostrarDialogo(this.dialogo);

  final Dialogo dialogo;
}

/// Contestar una pregunta escrita a mano: completar un hueco, elegir qué
/// decir, entender lo que pasó en el diálogo.
class Contestar extends Paso {
  const Contestar(this.pregunta);

  final Pregunta pregunta;
}

/// Unir cada palabra con lo que quiere decir.
///
/// Es el único ejercicio donde se ven varias juntas, y por eso es el que
/// obliga a distinguirlas entre sí en vez de reconocer una sola.
class Relacionar extends Paso {
  const Relacionar({required this.pares, required this.traducciones});

  final List<PalabraDeLeccion> pares;

  /// Las de la columna derecha, en el orden en que van.
  ///
  /// Vienen armadas de acá y no de la pantalla porque la pantalla se
  /// redibuja en cada toque: mezclarlas ahí las reacomodaría a cada rato.
  final List<String> traducciones;
}

/// Si alguna traducción quedó en la misma fila que su palabra.
///
/// Pasó en la primera versión, que ordenaba la columna derecha alfabé-
/// ticamente: salió una pantalla con las cuatro alineadas, o sea un
/// ejercicio que se resuelve sin leer. Ahora se mezcla y se revisa.
bool hayAlgunaEnLinea(List<PalabraDeLeccion> pares, List<String> derecha) {
  for (var i = 0; i < pares.length && i < derecha.length; i++) {
    if (pares[i].espanol == derecha[i]) return true;
  }
  return false;
}

/// Elegir qué quiere decir una palabra, entre cuatro.
class ElegirTraduccion extends Paso {
  const ElegirTraduccion({
    required this.palabra,
    required this.opciones,
    this.esRepaso = false,
  });

  final PalabraDeLeccion palabra;

  /// Viene de una lección anterior. Se avisa en pantalla —"Repaso"— para
  /// que no parezca que la app se olvidó de enseñarla.
  final bool esRepaso;

  /// Las cuatro de abajo, ya mezcladas. Una es [palabra.espanol].
  final List<String> opciones;

  String get correcta => palabra.espanol;
}

/// Mostrar una frase entera, con su traducción.
class MostrarFrase extends Paso {
  const MostrarFrase(this.frase);

  final FraseDeLeccion frase;
}

/// Armar la frase tocando fichas.
class ArmarLaFrase extends Paso {
  const ArmarLaFrase({required this.frase, required this.fichas});

  final FraseDeLeccion frase;
  final List<String> fichas;
}

/// De a cuántas palabras se muestran antes de preguntarlas.
///
/// Tres y no diez: mostrar las diez seguidas y recién después preguntar es
/// pedirle al que recién empieza que se acuerde de diez cosas que vio hace
/// un minuto. De a tres, cada una se pregunta cuando todavía está fresca.
const int palabrasPorTanda = 3;

/// Cuántas frases se arman al final.
///
/// No todas: en la lección más larga son cinco, y cinco frases para armar
/// después de once palabras es una lección que cansa antes de terminar. Se
/// arman las últimas, que son las más completas.
const int frasesParaArmar = 2;

/// Traducciones de relleno para cuando la lección no tiene suficientes
/// palabras como para llenar las cuatro opciones.
///
/// Son palabras de las primeras de cualquier curso, así que nunca suenan
/// absurdas al lado de la correcta: una opción obviamente disparatada se
/// descarta sin saber italiano.
const List<String> traduccionesDeRelleno = [
  'agua',
  'pan',
  'casa',
  'perro',
  'mesa',
  'día',
  'noche',
  'amigo',
  'calle',
  'mañana',
  'libro',
  'puerta',
];

/// Cuántas opciones tiene cada pregunta.
const int cuantasOpciones = 4;

/// Las opciones para preguntar [palabra], con la correcta adentro.
///
/// Las de al lado salen de la misma lección: son las que de verdad se
/// pueden confundir, porque son las que se acaban de ver. Recién cuando no
/// alcanzan entra el relleno.
List<String> opcionesPara(
  PalabraDeLeccion palabra, {
  required Iterable<PalabraDeLeccion> dondeElegir,
  Random? azar,
}) {
  final random = azar ?? Random();
  final usadas = <String>{palabra.espanol};

  final deLaLeccion = [
    for (final otra in dondeElegir)
      if (usadas.add(otra.espanol)) otra.espanol,
  ]..shuffle(random);

  final relleno = [
    for (final texto in traduccionesDeRelleno)
      if (usadas.add(texto)) texto,
  ]..shuffle(random);

  return [
    palabra.espanol,
    ...[...deLaLeccion, ...relleno].take(cuantasOpciones - 1),
  ]..shuffle(random);
}

/// Cuántas palabras entran en un relacionar.
const int cuantasEnRelacionar = 4;

/// Cuántas palabras de lecciones anteriores se repasan al final.
///
/// Dos, y no más: el repaso está para que lo viejo no se caiga, no para
/// alargar la lección. Si cada lección repasara cinco, la última de la
/// ciudad sería media hora.
const int cuantasDeRepaso = 2;

/// Los pasos de [leccion], en el orden en que se hacen.
///
/// El orden es el de una clase: primero la regla, después las palabras,
/// después verlas usadas, después la conversación, y recién al final
/// producir. Y cierra repasando algo de las lecciones de antes, que es lo
/// que hace que lo de la semana pasada no se caiga.
///
/// La regla que no se puede romper: una palabra se muestra antes de
/// preguntarse, y una frase se muestra antes de armarse. Hay un test que la
/// recorre entera y falla si alguna aparece antes de tiempo.
///
/// [antes] son las lecciones que ya se hicieron en esta ciudad: de ahí sale
/// el repaso, y también las opciones de al lado de las preguntas, que
/// cuanto más avanzada la ciudad más difíciles se vuelven solas.
List<Paso> pasosDe(
  Leccion leccion, {
  List<Leccion> antes = const [],
  Random? azar,
}) {
  final random = azar ?? Random();
  if (leccion.esPrueba) return pasosDePrueba(leccion, antes, random);
  final pasos = <Paso>[];

  for (final explicacion in leccion.explicaciones) {
    pasos.add(MostrarExplicacion(explicacion));
  }

  final palabras = leccion.palabras;
  final yaVistas = [for (final l in antes) ...l.palabras];
  final paraElegir = [...palabras, ...yaVistas];
  for (var desde = 0; desde < palabras.length; desde += palabrasPorTanda) {
    final tanda = palabras.sublist(
      desde,
      min(desde + palabrasPorTanda, palabras.length),
    );
    for (final palabra in tanda) {
      pasos.add(MostrarPalabra(palabra));
    }
    // Preguntar la tanda en otro orden que el que se mostró: si no, la
    // respuesta se contesta por la posición y no por la palabra.
    for (final palabra in [...tanda]..shuffle(random)) {
      pasos.add(
        ElegirTraduccion(
          palabra: palabra,
          opciones: opcionesPara(
            palabra,
            dondeElegir: paraElegir,
            azar: random,
          ),
        ),
      );
    }
  }

  // Relacionar: solo cuando hay cuatro, que es el mínimo para que una
  // columna contra la otra sea un ejercicio y no un regalo.
  if (palabras.length >= cuantasEnRelacionar) {
    final elegidas = ([
      ...palabras,
    ]..shuffle(random)).take(cuantasEnRelacionar).toList();
    final derecha = [for (final p in elegidas) p.espanol]..shuffle(random);
    // Mezclar hasta que ninguna quede frente a la suya. Con cuatro, una
    // de cada tres mezclas sirve, así que veinte intentos alcanzan de
    // sobra; si igual no sale, se deja como está y el ejercicio sigue
    // siendo válido, solo más fácil.
    for (
      var intento = 0;
      intento < 20 && hayAlgunaEnLinea(elegidas, derecha);
      intento++
    ) {
      derecha.shuffle(random);
    }
    pasos.add(Relacionar(pares: elegidas, traducciones: derecha));
  }

  for (final frase in leccion.frases) {
    pasos.add(MostrarFrase(frase));
  }

  for (final pregunta in leccion.preguntas) {
    pasos.add(Contestar(pregunta));
  }

  // El diálogo y enseguida lo que se preguntó de él: separados por otros
  // pasos habría que acordarse de lo que decía en vez de entenderlo.
  for (final dialogo in leccion.dialogos) {
    pasos.add(MostrarDialogo(dialogo));
    for (final pregunta in dialogo.preguntas) {
      pasos.add(Contestar(pregunta));
    }
  }

  final paraArmar = leccion.frases.length <= frasesParaArmar
      ? leccion.frases
      : leccion.frases.sublist(leccion.frases.length - frasesParaArmar);
  for (final frase in paraArmar) {
    pasos.add(
      ArmarLaFrase(
        frase: frase,
        fichas: fichasPara(
          frase.italiano,
          extras: leccion.palabras.map((p) => p.italiano),
          azar: random,
        ),
      ),
    );
  }

  for (final palabra in ([
    ...yaVistas,
  ]..shuffle(random)).take(cuantasDeRepaso)) {
    pasos.add(
      ElegirTraduccion(
        palabra: palabra,
        esRepaso: true,
        opciones: opcionesPara(palabra, dondeElegir: paraElegir, azar: random),
      ),
    );
  }

  return pasos;
}

/// Los pasos de la prueba de una ciudad.
///
/// No enseña nada: pregunta lo que ya se enseñó, sacado de las lecciones
/// de esa misma ciudad. Por eso no hay un solo paso de mostrar.
///
/// Las preguntas salen por turnos de tres montones —palabras, ejercicios
/// escritos, frases para armar— en vez de todas mezcladas en una bolsa.
/// Mezcladas, el azar da pruebas de ocho palabras sueltas: aprobadas sin
/// haber armado una sola frase, que es justo lo que hay que demostrar.
List<Paso> pasosDePrueba(Leccion prueba, List<Leccion> antes, Random random) {
  final palabras = <Paso>[];
  final escritas = <Paso>[];
  final frases = <Paso>[];

  final todasLasPalabras = [for (final l in antes) ...l.palabras];

  for (final leccion in antes) {
    for (final palabra in leccion.palabras) {
      palabras.add(
        ElegirTraduccion(
          palabra: palabra,
          opciones: opcionesPara(
            palabra,
            dondeElegir: todasLasPalabras,
            azar: random,
          ),
        ),
      );
    }
    for (final pregunta in leccion.preguntas) {
      escritas.add(Contestar(pregunta));
    }
    for (final dialogo in leccion.dialogos) {
      for (final pregunta in dialogo.preguntas) {
        escritas.add(Contestar(pregunta));
      }
    }
    for (final frase in leccion.frases) {
      frases.add(
        ArmarLaFrase(
          frase: frase,
          fichas: fichasPara(
            frase.italiano,
            extras: leccion.palabras.map((p) => p.italiano),
            azar: random,
          ),
        ),
      );
    }
  }

  for (final monton in [palabras, escritas, frases]) {
    monton.shuffle(random);
  }

  final cuantas = prueba.cuantas > 0 ? prueba.cuantas : 8;
  final elegidos = <Paso>[];
  var vuelta = 0;
  while (elegidos.length < cuantas) {
    final habia = elegidos.length;
    for (final monton in [palabras, escritas, frases]) {
      if (vuelta < monton.length && elegidos.length < cuantas) {
        elegidos.add(monton[vuelta]);
      }
    }
    // Se acabaron los tres montones antes de llegar a `cuantas`: la
    // ciudad tiene menos ejercicios que los que pide la prueba.
    if (elegidos.length == habia) break;
    vuelta++;
  }

  return elegidos..shuffle(random);
}
