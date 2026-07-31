import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tukyliano/constantes.dart';
import 'package:tukyliano/datos/repositorio_frases.dart';

/// Lee el asset de verdad desde el disco. No usa rootBundle a propósito: así
/// el test verifica el archivo que se empaqueta, sin depender del binding.
final _json = File('assets/frases.json').readAsStringSync();
final _frases = (jsonDecode(_json) as Map<String, dynamic>)['frases'] as List;

RepositorioFrases _repo({String? asset, String remoto = '', int codigo = 404}) =>
    RepositorioFrases(
      leerAsset: (_) async => asset ?? _json,
      cliente: MockClient((_) async => http.Response(remoto, codigo)),
      // Sin carpeta: en los tests no hay path_provider, así que no se cachea.
      carpeta: () async => null,
    );

void main() {
  group('el asset de frases', () {
    // Se afirman invariantes, no cantidades exactas: las frases crecen seguido
    // y el test no tiene que romperse cada vez que se suman.
    test('cubre todas las formas de los verbos que trae la app', () {
      final formas = _frases
          .map((f) => RepositorioFrases.claveDe(
              f['verbo'] as String, f['tiempo'] as String, f['persona'] as String))
          .toSet();
      // 4 verbos x (4 tiempos x 6 personas + gerundio).
      expect(formas.length, 100);
    });

    test('cada forma tiene al menos una frase', () {
      final porForma = <String, int>{};
      for (final f in _frases) {
        final clave = RepositorioFrases.claveDe(
            f['verbo'] as String, f['tiempo'] as String, f['persona'] as String);
        porForma[clave] = (porForma[clave] ?? 0) + 1;
      }
      expect(porForma.values.every((n) => n >= 1), isTrue);
    });

    test('no repite la misma frase en español', () {
      final espanoles = _frases.map((f) => f['espanol']).toList();
      expect(espanoles.toSet().length, espanoles.length);
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
    test('carga todas las del asset y las encuentra por forma', () async {
      final repo = _repo();
      await repo.cargar();

      expect(repo.cantidad, _frases.length);
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

      expect(repo.cantidad, _frases.length);
    });

    test('un asset ilegible deja el repositorio vacío en vez de tirar', () async {
      final repo = _repo(asset: 'roto');
      await repo.cargar();

      expect(repo.cantidad, 0);
      expect(
        repo.elegir(verbo: 'essere', tiempo: 'presente', persona: 'io'),
        isNull,
      );
    });

    test('descarta la frase cuyo italiano no trae la conjugación', () async {
      // Red de contención para el JSON remoto, que no pasa por el build.
      final repo = _repo(asset: '''
        {"frases": [
          {"verbo": "essere", "tiempo": "futuro_semplice", "persona": "io",
           "espanol": "Mañana estaré acá", "italiano": "Domani soro qui",
           "pista": ""}
        ]}
      ''');
      await repo.cargar();

      expect(
        repo.elegir(
          verbo: 'essere',
          tiempo: 'futuro_semplice',
          persona: 'io',
          conjugacionItaliana: 'sarò',
        ),
        isNull,
      );
      // Sin conjugación que chequear, la frase se usa igual.
      expect(
        repo.elegir(
            verbo: 'essere', tiempo: 'futuro_semplice', persona: 'io'),
        isNotNull,
      );
    });

    test('entre varias se queda con la que sí trae la conjugación', () async {
      final repo = _repo(asset: '''
        {"frases": [
          {"verbo": "essere", "tiempo": "futuro_semplice", "persona": "io",
           "espanol": "Mala", "italiano": "Domani soro qui", "pista": ""},
          {"verbo": "essere", "tiempo": "futuro_semplice", "persona": "io",
           "espanol": "Buena", "italiano": "Domani sarò qui", "pista": ""}
        ]}
      ''');
      await repo.cargar();

      for (var i = 0; i < 10; i++) {
        expect(
          repo
              .elegir(
                verbo: 'essere',
                tiempo: 'futuro_semplice',
                persona: 'io',
                conjugacionItaliana: 'sarò',
                azar: Random(i),
              )!
              .espanol,
          'Buena',
        );
      }
    });

    test('elige entre varias cuando la forma tiene más de una', () async {
      final repo = _repo(asset: '''
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

  group('actualización desde GitHub', () {
    const remotoV2 = '''
      {"version": 99, "frases": [
        {"verbo": "essere", "tiempo": "presente", "persona": "io",
         "espanol": "Frase nueva", "italiano": "Sono nuovo", "pista": "nueva = nuovo"}
      ]}
    ''';

    test('una versión más nueva reemplaza a las del asset', () async {
      final repo = _repo(remoto: remotoV2, codigo: 200);
      await repo.cargar();
      expect(repo.cantidad, _frases.length);

      expect(await repo.verificarActualizacion(), isTrue);
      expect(repo.version, 99);
      expect(repo.cantidad, 1);
      expect(
        repo.elegir(verbo: 'essere', tiempo: 'presente', persona: 'io')!.espanol,
        'Frase nueva',
      );
    });

    test('una versión igual o más vieja no cambia nada', () async {
      final repo = _repo(remoto: '{"version": 1, "frases": []}', codigo: 200);
      await repo.cargar();

      expect(await repo.verificarActualizacion(), isFalse);
      expect(repo.cantidad, _frases.length);
    });

    test('sin internet se sigue con las que ya están', () async {
      final repo = RepositorioFrases(
        leerAsset: (_) async => _json,
        cliente: MockClient((_) async => throw const SocketException('sin red')),
        carpeta: () async => null,
      );
      await repo.cargar();

      expect(await repo.verificarActualizacion(), isFalse);
      expect(repo.cantidad, _frases.length);
    });

    test('un JSON remoto roto no borra las frases', () async {
      final repo = _repo(remoto: 'no es json', codigo: 200);
      await repo.cargar();

      expect(await repo.verificarActualizacion(), isFalse);
      expect(repo.cantidad, _frases.length);
    });

    test('un 404 no cambia nada', () async {
      final repo = _repo(remoto: 'Not Found', codigo: 404);
      await repo.cargar();

      expect(await repo.verificarActualizacion(), isFalse);
      expect(repo.cantidad, _frases.length);
    });

    test('guarda la tanda nueva en el celular para la próxima vez', () async {
      final dir = Directory.systemTemp.createTempSync('frases_test');
      addTearDown(() => dir.deleteSync(recursive: true));

      final repo = RepositorioFrases(
        leerAsset: (_) async => _json,
        cliente: MockClient((_) async => http.Response(remotoV2, 200)),
        carpeta: () async => dir,
      );
      await repo.cargar();
      await repo.verificarActualizacion();

      // La segunda vez arranca del archivo guardado, sin tocar el asset.
      final despues = RepositorioFrases(
        leerAsset: (_) async => throw StateError('no debería leer el asset'),
        cliente: MockClient((_) async => http.Response('', 404)),
        carpeta: () async => dir,
      );
      await despues.cargar();

      expect(despues.version, 99);
      expect(despues.cantidad, 1);
    });
  });
}
