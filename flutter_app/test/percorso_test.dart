// La regla que hace posible empezar de cero.
//
// El camino sirve si, y solo si, **nunca aparece una palabra que no se
// enseñó antes**. Si en la lección 3 se cuela una palabra que recién sale
// en la 4, el que no sabe nada se traba y no entiende por qué: no le falta
// estudiar, le falta algo que la app no le dio.
//
// Eso no se puede cuidar leyendo el JSON a ojo —son cientos de palabras y
// cada cuento nuevo lo vuelve a poner en riesgo—, así que lo cuida esto.
//
// Se mide sobre los archivos de verdad, no sobre datos de prueba: lo que
// hay que proteger es el contenido que se publica.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tukyliano/modelos/percorso.dart';

/// Una palabra italiana. El apóstrofo separa: "l'uccello" son dos,
/// el artículo y el sustantivo, y se enseñan por separado.
final _unaPalabra = RegExp(r"[a-zàèéìòóùü]+", caseSensitive: false);

List<String> _enPalabras(String texto) =>
    _unaPalabra.allMatches(texto.toLowerCase()).map((m) => m[0]!).toList();

/// Los nombres propios no son vocabulario: no se traducen ni se aprenden.
const _nombres = {'marco', 'elena', 'rosa', 'riccardo', 'paolo', 'stefano',
  'anna', 'giulia', 'luca', 'sofia', 'matteo', 'chiara', 'roma', 'napoli',
  'firenze', 'milano', 'italia', 'venezia', 'palermo'};

Map<String, dynamic> _leer(String archivo) =>
    jsonDecode(File(archivo).readAsStringSync()) as Map<String, dynamic>;

Percorso get _elCamino => Percorso.desdeJson(_leer('assets/percorso.json'));

/// Los renglones de un cuento del catálogo, por id.
List<String> _renglonesDe(String id) {
  final racconti = _leer('assets/racconti.json')['racconti'] as List;
  for (final r in racconti) {
    if ((r as Map)['id'] != id) continue;
    return [for (final l in r['lineas'] as List) (l as Map)['it'] as String];
  }
  throw StateError('no existe el cuento "$id"');
}

void main() {
  test('el camino se lee y Palermo está entera', () {
    final camino = _elCamino;
    expect(camino.ciudades, isNotEmpty);

    final palermo = camino.ciudades.first;
    expect(palermo.id, 'palermo');
    expect(palermo.lecciones.length, 6);
    expect(palermo.cuantasLecciones, 5, reason: 'la prueba no se cuenta');
    expect(palermo.lecciones.last.esPrueba, isTrue);
  });

  test('ninguna frase usa una palabra que todavía no se enseñó', () {
    // Esta es la importante. Se recorren las lecciones en orden, juntando
    // lo enseñado, y cada frase de ejemplo tiene que entrar en eso.
    for (final ciudad in _elCamino.ciudades) {
      final sabidas = <String>{};
      for (final leccion in ciudad.lecciones) {
        sabidas.addAll(leccion.palabras.expand((p) => _enPalabras(p.italiano)));

        for (final frase in leccion.frases) {
          final faltan = _enPalabras(frase.italiano)
              .where((p) => !sabidas.contains(p) && !_nombres.contains(p))
              .toSet();
          expect(faltan, isEmpty,
              reason: '${ciudad.nombre} · ${leccion.titulo}: '
                  '"${frase.italiano}" usa $faltan, que no se enseñó todavía');
        }
      }
    }
  });

  test('el cuento del final no trae ni una palabra nueva', () {
    // El premio de la ciudad es leer un cuento entero sin que falte nada.
    // Si falta una sola palabra, deja de ser un premio y vuelve a ser un
    // examen.
    for (final ciudad in _elCamino.ciudades) {
      final sabidas = <String>{};
      for (final leccion in ciudad.lecciones) {
        sabidas.addAll(leccion.palabras.expand((p) => _enPalabras(p.italiano)));
        if (!leccion.esLectura) continue;

        final delCuento = _renglonesDe(leccion.racconto)
            .expand(_enPalabras)
            .where((p) => !_nombres.contains(p))
            .toSet();
        final faltan = delCuento.difference(sabidas);
        expect(faltan, isEmpty,
            reason: '${ciudad.nombre}: el cuento "${leccion.racconto}" usa '
                '${faltan.length} palabras sin enseñar: $faltan');
      }
    }
  });

  test('no se enseña dos veces la misma palabra', () {
    // Repetir una palabra no rompe nada, pero es una lección más corta de
    // lo que parece y una señal de que el reparto se desacomodó.
    for (final ciudad in _elCamino.ciudades) {
      final vistas = <String, String>{};
      for (final leccion in ciudad.lecciones) {
        for (final palabra in leccion.palabras) {
          final antes = vistas[palabra.italiano];
          expect(antes, isNull,
              reason: '"${palabra.italiano}" está en "${leccion.titulo}" '
                  'y ya estaba en "$antes"');
          vistas[palabra.italiano] = leccion.titulo;
        }
      }
    }
  });

  test('toda palabra enseñada tiene su traducción', () {
    for (final ciudad in _elCamino.ciudades) {
      for (final leccion in ciudad.lecciones) {
        for (final palabra in leccion.palabras) {
          expect(palabra.espanol, isNotEmpty,
              reason: '"${palabra.italiano}" en "${leccion.titulo}"');
        }
      }
    }
  });

  test('la ciudad cae sobre el mapa, no en el mar', () {
    // Las posiciones salieron de medirlas sobre el dibujo. Acá solo se
    // cuida que nadie las deje en cero o fuera de rango por un descuido.
    for (final ciudad in _elCamino.ciudades) {
      expect(ciudad.x, inInclusiveRange(0.05, 0.95), reason: ciudad.nombre);
      expect(ciudad.y, inInclusiveRange(0.05, 0.95), reason: ciudad.nombre);
    }
  });
}
