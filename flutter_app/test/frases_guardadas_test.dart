import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tukyliano/constantes.dart';
import 'package:tukyliano/datos/repositorio_frases.dart';

/// Lee el asset de verdad desde el disco. No usa rootBundle a propósito: así
/// el test verifica el archivo que se empaqueta, sin depender del binding.
final _json = File('assets/frases.json').readAsStringSync();
final _frases = (jsonDecode(_json) as Map<String, dynamic>)['frases'] as List;

RepositorioFrases _repo() =>
    RepositorioFrases(leerAsset: (_) async => _json);

void main() {
  group('el asset de frases', () {
    test('tiene una frase por cada forma de los verbos que vienen con la app',
        () {
      // 4 verbos x (4 tiempos x 6 personas + gerundio).
      expect(_frases.length, 100);
    });

    test('no repite ninguna forma', () {
      final claves = _frases
          .map((f) => RepositorioFrases.claveDe(
              f['verbo'] as String, f['tiempo'] as String, f['persona'] as String))
          .toList();
      expect(claves.toSet().length, claves.length);
    });

    test('todas tienen español, italiano y pista', () {
      for (final f in _frases) {
        expect(f['espanol'], isNotEmpty, reason: '$f');
        expect(f['italiano'], isNotEmpty, reason: '$f');
        expect(f['pista'], isNotEmpty, reason: '$f');
      }
    });

    test('ninguna pasa las seis palabras', () {
      for (final f in _frases) {
        final palabras = (f['espanol'] as String).split(' ').length;
        expect(palabras, lessThanOrEqualTo(6), reason: f['espanol'] as String);
      }
    });

    test('el gerundio va con la persona que usa el resto de la app', () {
      final gerundios = _frases.where((f) => f['tiempo'] == tiempoGerundio);
      expect(gerundios, isNotEmpty);
      for (final f in gerundios) {
        expect(f['persona'], personaGerundio);
      }
    });

    test('solo usa tiempos que la app conoce', () {
      for (final f in _frases) {
        expect(tiemposDisponibles, contains(f['tiempo']));
      }
    });
  });

  group('RepositorioFrases', () {
    test('carga las 100 y las encuentra por forma', () async {
      final repo = _repo();
      await repo.cargar();

      expect(repo.cantidad, 100);
      final frase =
          repo.elegir(verbo: 'essere', tiempo: 'presente', persona: 'io');
      expect(frase, isNotNull);
      expect(frase!.italiano, isNotEmpty);
    });

    test('devuelve null para una forma que no tiene frase', () async {
      final repo = _repo();
      await repo.cargar();

      expect(
        repo.elegir(verbo: 'mangiare', tiempo: 'presente', persona: 'io'),
        isNull,
      );
    });

    test('cargar dos veces no duplica', () async {
      final repo = _repo();
      await repo.cargar();
      await repo.cargar();

      expect(repo.cantidad, 100);
    });

    test('un asset ilegible deja el repositorio vacío en vez de tirar', () async {
      final repo = RepositorioFrases(leerAsset: (_) async => 'roto');
      await repo.cargar();

      expect(repo.cantidad, 0);
      expect(
        repo.elegir(verbo: 'essere', tiempo: 'presente', persona: 'io'),
        isNull,
      );
    });

    test('elige entre varias cuando la forma tiene más de una', () async {
      final repo = RepositorioFrases(leerAsset: (_) async => '''
        {"frases": [
          {"verbo": "essere", "tiempo": "presente", "persona": "io",
           "espanol": "Una", "italiano": "Uno", "pista": ""},
          {"verbo": "essere", "tiempo": "presente", "persona": "io",
           "espanol": "Dos", "italiano": "Due", "pista": ""}
        ]}
      ''');
      await repo.cargar();

      final vistas = <String>{};
      for (var i = 0; i < 20; i++) {
        vistas.add(repo
            .elegir(
              verbo: 'essere',
              tiempo: 'presente',
              persona: 'io',
              azar: Random(i),
            )!
            .espanol);
      }
      expect(vistas, containsAll(['Una', 'Dos']));
    });
  });
}
