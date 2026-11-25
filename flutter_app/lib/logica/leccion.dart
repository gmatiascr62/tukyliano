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

/// Mostrar una palabra nueva. No hay nada que contestar: se mira, se
/// escucha y se sigue.
class MostrarPalabra extends Paso {
  const MostrarPalabra(this.palabra);

  final PalabraDeLeccion palabra;
}

/// Elegir qué quiere decir una palabra, entre cuatro.
class ElegirTraduccion extends Paso {
  const ElegirTraduccion({required this.palabra, required this.opciones});

  final PalabraDeLeccion palabra;

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

/// Los pasos de [leccion], en el orden en que se hacen.
///
/// La regla que no se puede romper: una palabra se muestra antes de
/// preguntarse, y una frase se muestra antes de armarse. Hay un test que la
/// recorre entera y falla si alguna aparece antes de tiempo.
List<Paso> pasosDe(Leccion leccion, {Random? azar}) {
  final random = azar ?? Random();
  final pasos = <Paso>[];

  final palabras = leccion.palabras;
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
          opciones: opcionesPara(palabra, dondeElegir: palabras, azar: random),
        ),
      );
    }
  }

  for (final frase in leccion.frases) {
    pasos.add(MostrarFrase(frase));
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

  return pasos;
}
