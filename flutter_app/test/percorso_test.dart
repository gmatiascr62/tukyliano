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
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tukyliano/logica/leccion.dart';
import 'package:tukyliano/modelos/percorso.dart';

/// Una palabra italiana. El apóstrofo separa: "l'uccello" son dos,
/// el artículo y el sustantivo, y se enseñan por separado.
final _unaPalabra = RegExp(r"[a-zàáèéìíòóùúü]+", caseSensitive: false);

List<String> _enPalabras(String texto) =>
    _unaPalabra.allMatches(texto.toLowerCase()).map((m) => m[0]!).toList();

/// Los nombres propios no son vocabulario: no se traducen ni se aprenden.
const _nombres = {
  'marco',
  'elena',
  'rosa',
  'riccardo',
  'paolo',
  'stefano',
  'anna',
  'giulia',
  'luca',
  'sofia',
  'matteo',
  'chiara',
  'roma',
  'napoli',
  'firenze',
  'milano',
  'italia',
  'venezia',
  'palermo',
  'olbia',
  'cagliari',
  'sardegna',
  'matías',
  'buenos',
  'aires',
};

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
  test('el nivel 1 son las dos ciudades de Cerdeña, y están enteras', () {
    final camino = _elCamino;
    final nivelUno = camino.ciudades.where((c) => c.nivel == 1).toList();

    expect(nivelUno.map((c) => c.id), ['olbia', 'cagliari']);
    for (final ciudad in nivelUno) {
      expect(ciudad.lecciones.last.esPrueba, isTrue, reason: ciudad.id);
      expect(ciudad.cuantasLecciones, 10, reason: ciudad.id);
      for (final leccion in ciudad.lecciones.where((l) => !l.esPrueba)) {
        expect(
          leccion.explicaciones,
          isNotEmpty,
          reason:
              '${ciudad.id} · ${leccion.id}: toda lección explica algo '
              'antes de preguntar',
        );
      }
    }

    // El examen del final toma el nivel entero, no solo Cagliari.
    expect(nivelUno.last.lecciones.last.integradora, isTrue);
  });

  test('cada ciudad llega a su prueba con suficiente para preguntar', () {
    // La prueba saca sus preguntas de las lecciones de antes. Si pide más
    // de las que hay, se achica sola y se aprueba con cuatro preguntas.
    for (final ciudad in _elCamino.ciudades) {
      final prueba = ciudad.lecciones.where((l) => l.esPrueba).firstOrNull;
      if (prueba == null) continue;
      final dadas = ciudad.lecciones.where((l) => !l.esPrueba);
      final cuantosEjercicios =
          dadas.fold(0, (suma, l) => suma + l.palabras.length) +
          dadas.fold(0, (suma, l) => suma + l.frases.length) +
          dadas.fold(0, (suma, l) => suma + l.preguntas.length);
      expect(
        cuantosEjercicios,
        greaterThanOrEqualTo(prueba.cuantas),
        reason: '${ciudad.id}: la prueba pide ${prueba.cuantas}',
      );
      expect(prueba.paraAprobar, lessThanOrEqualTo(prueba.cuantas));
    }
  });

  test('ninguna frase ni diálogo usa una palabra que no se enseñó', () {
    // Esta es la importante. Se recorre el camino entero en orden,
    // juntando lo enseñado, y cada frase y cada renglón de diálogo tiene
    // que entrar en eso.
    //
    // De corrido entre ciudades, no de a una: el camino es un curso solo,
    // así que Cagliari puede usar lo de Olbia sin volver a enseñarlo.
    //
    // Los ejemplos de las explicaciones quedan afuera a propósito. En las
    // lecciones de pronunciación son demostraciones de un sonido
    // —gnocchi, spaghetti, famiglia—, van con su traducción al lado y no
    // se preguntan nunca. Exigirles la escalera obligaría a enseñar como
    // vocabulario cada palabra que se usa de ejemplo.
    final sabidas = <String>{};
    for (final ciudad in _elCamino.ciudades) {
      for (final leccion in ciudad.lecciones) {
        sabidas.addAll(leccion.palabras.expand((p) => _enPalabras(p.italiano)));

        void revisar(String texto, String que) {
          final faltan = _enPalabras(
            texto,
          ).where((p) => !sabidas.contains(p) && !_nombres.contains(p)).toSet();
          expect(
            faltan,
            isEmpty,
            reason:
                '${ciudad.nombre} · ${leccion.titulo} ($que): '
                '"$texto" usa $faltan, que no se enseñó todavía',
          );
        }

        for (final frase in leccion.frases) {
          revisar(frase.italiano, 'frase');
        }
        for (final dialogo in leccion.dialogos) {
          for (final renglon in dialogo.renglones) {
            revisar(renglon.italiano, 'diálogo');
          }
        }
      }
    }
  });

  test('el cuento del final no trae ni una palabra nueva', () {
    // El premio de la ciudad es leer un cuento entero sin que falte nada.
    // Si falta una sola palabra, deja de ser un premio y vuelve a ser un
    // examen.
    final sabidas = <String>{};
    for (final ciudad in _elCamino.ciudades) {
      for (final leccion in ciudad.lecciones) {
        sabidas.addAll(leccion.palabras.expand((p) => _enPalabras(p.italiano)));
        if (!leccion.esLectura) continue;

        final delCuento = _renglonesDe(
          leccion.racconto,
        ).expand(_enPalabras).where((p) => !_nombres.contains(p)).toSet();
        final faltan = delCuento.difference(sabidas);
        expect(
          faltan,
          isEmpty,
          reason:
              '${ciudad.nombre}: el cuento "${leccion.racconto}" usa '
              '${faltan.length} palabras sin enseñar: $faltan',
        );
      }
    }
  });

  test('ninguna lección se hace interminable', () {
    // Medido: las del nivel 1 van de 21 a 39 pasos, o sea entre tres y
    // siete minutos. Cuarenta es el techo. No es un número mágico: es
    // que una lección más larga que eso se abandona por la mitad, y
    // abandonada no enseñó nada.
    //
    // Cada palabra nueva cuesta dos pasos —mostrarla y preguntarla—, así
    // que el que se pasa del techo casi siempre es por meter demasiado
    // vocabulario junto.
    for (final ciudad in _elCamino.ciudades) {
      final antes = <Leccion>[];
      for (final leccion in ciudad.lecciones) {
        final pasos = pasosDe(leccion, antes: antes, azar: Random(1));
        expect(
          pasos.length,
          lessThanOrEqualTo(40),
          reason:
              '${ciudad.id} · ${leccion.id} tiene ${pasos.length} pasos '
              'con ${leccion.palabras.length} palabras',
        );
        if (!leccion.esPrueba) antes.add(leccion);
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
          expect(
            antes,
            isNull,
            reason:
                '"${palabra.italiano}" está en "${leccion.titulo}" '
                'y ya estaba en "$antes"',
          );
          vistas[palabra.italiano] = leccion.titulo;
        }
      }
    }
  });

  test('toda palabra enseñada tiene su traducción', () {
    for (final ciudad in _elCamino.ciudades) {
      for (final leccion in ciudad.lecciones) {
        for (final palabra in leccion.palabras) {
          expect(
            palabra.espanol,
            isNotEmpty,
            reason: '"${palabra.italiano}" en "${leccion.titulo}"',
          );
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
