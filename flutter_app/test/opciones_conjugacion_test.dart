import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tukyliano/constantes.dart';
import 'package:tukyliano/logica/opciones_conjugacion.dart';
import 'package:tukyliano/logica/seleccion_azar.dart';
import 'package:tukyliano/modelos/verbo.dart';

final _datos = DatosVerbos.desdeJson(
    jsonDecode(File('assets/verbos.json').readAsStringSync())
        as Map<String, dynamic>);

Combo _combo(String verbo, String tiempo, String persona) {
  final v = _datos.verbos[verbo]!;
  return Combo(
    verbo: v,
    tiempo: tiempo,
    persona: persona,
    conjugacion: v.tiempos[tiempo]![persona]!,
  );
}

void main() {
  test('siempre trae la correcta y cuatro botones sin repetir', () {
    for (final verbo in _datos.verbos.values) {
      for (final tiempo in verbo.tiempos.entries) {
        for (final persona in tiempo.value.keys) {
          final combo = _combo(verbo.nombre, tiempo.key, persona);
          final opciones = opcionesDeConjugacion(combo, azar: Random(7));

          expect(opciones, contains(combo.conjugacion.italiano),
              reason: '${verbo.nombre}/${tiempo.key}/$persona');
          expect(opciones.length, cuantasOpciones,
              reason: '${verbo.nombre}/${tiempo.key}/$persona');
          expect(opciones.toSet().length, cuantasOpciones,
              reason: '${verbo.nombre}/${tiempo.key}/$persona: $opciones');
        }
      }
    }
  });

  test('los distractores son del mismo verbo', () {
    // Con formas de otro verbo la respuesta se adivinaría por la raíz, sin
    // mirar la terminación, que es justo lo que se está practicando.
    final combo = _combo('andare', 'presente', 'noi');
    final delVerbo = {
      for (final tiempo in combo.verbo.tiempos.values)
        for (final conjugacion in tiempo.values) conjugacion.italiano,
    };

    for (var i = 0; i < 20; i++) {
      final opciones = opcionesDeConjugacion(combo, azar: Random(i));
      expect(delVerbo.containsAll(opciones), isTrue, reason: '$opciones');
    }
  });

  test('la respuesta no cae siempre en el mismo botón', () {
    final combo = _combo('essere', 'presente', 'tu');
    final lugares = {
      for (var i = 0; i < 30; i++)
        opcionesDeConjugacion(combo, azar: Random(i))
            .indexOf(combo.conjugacion.italiano),
    };

    expect(lugares.length, greaterThan(1));
  });

  test('casi siempre hay alguna otra persona del mismo tiempo', () {
    // Es el error que más se quiere provocar: confundir la persona. El
    // gerundio queda afuera porque es una forma sola.
    for (final verbo in _datos.verbos.values) {
      final combo = _combo(verbo.nombre, 'presente', 'noi');
      final delTiempo = verbo.tiempos['presente']!.values
          .map((c) => c.italiano)
          .toSet();
      final opciones = opcionesDeConjugacion(combo, azar: Random(3));

      final delaFila =
          opciones.where(delTiempo.contains).length; // incluye la correcta
      expect(delaFila, greaterThanOrEqualTo(3), reason: verbo.nombre);
    }
  });

  test('el gerundio también se puede contestar tocando', () {
    // No tiene compañeras de fila, así que los distractores salen de los
    // otros tiempos. Igual tienen que ser cuatro.
    final combo = _combo('fare', tiempoGerundio, personaGerundio);
    final opciones = opcionesDeConjugacion(combo, azar: Random(1));

    expect(opciones, contains('facendo'));
    expect(opciones.length, cuantasOpciones);
  });
}
