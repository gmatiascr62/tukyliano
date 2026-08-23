import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tukyliano/constantes.dart';
import 'package:tukyliano/modelos/particella.dart';

final _crudo =
    jsonDecode(File('assets/via.json').readAsStringSync()) as Map<String, dynamic>;
final _datos = DatosParticelle.desdeJson(_crudo);

void main() {
  group('el asset del via', () {
    test('no se descartó ninguna frase al leerlo', () {
      // desdeJson tira las frases sin hueco o con la correcta afuera de los
      // botones. Si el JSON trae una así, acá se nota.
      expect(_datos.frases.length, (_crudo['frases'] as List).length);
    });

    test('hay frases de sobra para que no se repitan enseguida', () {
      expect(_datos.frases.length, greaterThanOrEqualTo(50));
    });

    test('todas tienen hueco, traducción y explicación', () {
      for (final frase in _datos.frases) {
        expect(frase.frase, contains(hueco), reason: frase.frase);
        expect(frase.espanol, isNotEmpty, reason: frase.frase);
        expect(frase.explicacion, isNotEmpty, reason: frase.frase);
      }
    });

    test('todas practican el via: la frase resuelta lo tiene', () {
      // Es la sección del via: una frase sin «via» estaría practicando otra
      // cosa.
      for (final frase in _datos.frases) {
        expect(
          frase.resuelta.toLowerCase().split(RegExp(r'[\s,.!?]+')),
          contains('via'),
          reason: frase.resuelta,
        );
      }
    });

    test('cada frase ofrece cuatro botones distintos', () {
      for (final frase in _datos.frases) {
        expect(frase.opciones.length, 4, reason: frase.frase);
        expect(frase.opciones.toSet().length, 4, reason: frase.frase);
        expect(frase.opciones, contains(frase.correcta), reason: frase.frase);
      }
    });

    test('la correcta no cae siempre en el mismo botón', () {
      // Si estuviera siempre primera, se aprendería la posición y no el verbo.
      final lugares = {
        for (final frase in _datos.frases) frase.opciones.indexOf(frase.correcta),
      };
      expect(lugares.length, greaterThanOrEqualTo(4));
    });

    test('no hay frases repetidas', () {
      final frases = _datos.frases.map((f) => f.frase).toList();
      expect(frases.toSet().length, frases.length);
    });

    test('practica todas las personas, no solo la primera', () {
      // Lo que se pidió: que los ejemplos no sean todos "yo", sino también
      // nosotros, ustedes y ellos.
      final personas = _datos.frases.map((f) => f.persona).toSet();
      expect(personas, containsAll(['io', 'tu', 'lui', 'noi', 'voi', 'loro']));
    });

    test('cada persona aparece en más de una frase', () {
      for (final persona in ['io', 'tu', 'lui', 'noi', 'voi', 'loro']) {
        final cuantas = _datos.frases.where((f) => f.persona == persona).length;
        expect(cuantas, greaterThanOrEqualTo(3), reason: persona);
      }
    });

    test('cubre los verbos que más se usan con via', () {
      final todas = _datos.frases.map((f) => f.resuelta.toLowerCase()).join(' ');
      for (final raiz in [
        'and', // andare via
        'butt', // buttare via
        'port', // portare via
        'mand', // mandare via
        'scapp', // scappare via
        'vol', // volare via
      ]) {
        expect(todas, contains(raiz), reason: raiz);
      }
    });

    test('el hueco cae en una sola parte de la frase', () {
      for (final frase in _datos.frases) {
        final (antes, despues) = frase.partes;
        expect(antes + hueco + despues, frase.frase, reason: frase.frase);
        expect(despues, isNot(contains(hueco)), reason: frase.frase);
      }
    });
  });

  group('el modelo', () {
    test('descarta la frase sin hueco', () {
      expect(
        FraseParticella.desdeJson({
          'frase': 'Vado via',
          'correcta': 'Vado',
          'opciones': ['Vado'],
        }),
        isNull,
      );
    });

    test('descarta la frase cuya respuesta no está entre los botones', () {
      expect(
        FraseParticella.desdeJson({
          'frase': '___ via',
          'correcta': 'Vado',
          'opciones': ['Porto', 'Butto'],
        }),
        isNull,
      );
    });

    test('arma la frase resuelta poniendo la respuesta en el hueco', () {
      final frase = FraseParticella.desdeJson({
        'frase': '___ via, è tardi.',
        'correcta': 'Vado',
        'opciones': ['Vado', 'Porto'],
        'es': 'me voy, es tarde',
      })!;

      expect(frase.resuelta, 'Vado via, è tardi.');
    });

    test('un JSON roto no deja la pantalla sin datos que mostrar', () {
      expect(DatosParticelle.desdeJson({'frases': 'esto no es una lista'}).frases,
          isEmpty);
    });
  });
}
