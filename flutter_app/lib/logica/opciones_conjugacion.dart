import 'dart:math';

import 'seleccion_azar.dart';

/// Cuántos botones se ofrecen, contando el correcto.
const int cuantasOpciones = 4;

/// Las opciones para contestar una conjugación tocando en vez de escribiendo.
///
/// Los distractores salen del mismo verbo y no de otro, que es lo que hace que
/// el ejercicio enseñe algo: al lado de "andiamo" se ven "vado" y "andate",
/// que son las que de verdad se confunden. Con formas de otro verbo la
/// respuesta se adivinaría por la raíz sin mirar la terminación.
///
/// Primero entran otras personas del mismo tiempo (la fila de la tabla),
/// después la misma persona en otros tiempos (la columna), y recién al final
/// cualquiera. Así el error posible siempre es uno de los dos que importan:
/// equivocarse de persona o equivocarse de tiempo.
List<String> opcionesDeConjugacion(Combo combo, {Random? azar}) {
  final rnd = azar ?? Random();
  final correcta = combo.conjugacion.italiano;

  final mismoTiempo = <String>[];
  final mismaPersona = <String>[];
  final resto = <String>[];

  for (final tiempo in combo.verbo.tiempos.entries) {
    for (final persona in tiempo.value.entries) {
      final forma = persona.value.italiano;
      if (forma == correcta) continue;
      if (tiempo.key == combo.tiempo) {
        mismoTiempo.add(forma);
      } else if (persona.key == combo.persona) {
        mismaPersona.add(forma);
      } else {
        resto.add(forma);
      }
    }
  }

  for (final lista in [mismoTiempo, mismaPersona, resto]) {
    lista.shuffle(rnd);
  }

  final elegidas = <String>{};
  // Dos de la fila y una de la columna; si alguna no alcanza, la otra
  // completa. Los verbos con formas repetidas (essere tiene "sono" dos veces)
  // no llegarían a cuatro si no se descartaran las repetidas.
  void sumar(Iterable<String> desde, int cuantas) {
    for (final forma in desde) {
      if (cuantas <= 0) break;
      if (elegidas.add(forma)) cuantas--;
    }
  }

  sumar(mismoTiempo, 2);
  sumar(mismaPersona, 1);
  sumar([...mismoTiempo, ...mismaPersona, ...resto], cuantasOpciones);

  final opciones = [
    correcta,
    ...elegidas.take(cuantasOpciones - 1),
  ]..shuffle(rnd);
  return opciones;
}
