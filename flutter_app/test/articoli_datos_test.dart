import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tukyliano/datos/repositorio_articoli.dart';
import 'package:tukyliano/logica/articulos.dart';
import 'package:tukyliano/modelos/articulo.dart';

final _json = File('assets/articoli.json').readAsStringSync();
final _datos =
    DatosArticoli.desdeJson(jsonDecode(_json) as Map<String, dynamic>);

RepositorioArticoli _repo({String? asset, String remoto = '', int codigo = 404}) =>
    RepositorioArticoli(
      leerAsset: (_) async => asset ?? _json,
      cliente: MockClient((_) async => http.Response(remoto, codigo)),
      // Sin carpeta: en los tests no hay path_provider, así que no se cachea.
      carpeta: () async => null,
    );

void main() {
  group('el asset de artículos', () {
    test('tiene palabras y todas apuntan a una clase que existe', () {
      expect(_datos.sustantivos, isNotEmpty);
      // desdeJson descarta las que apuntan a una clase inexistente, así que
      // si el JSON tuviera una mal, acá faltaría.
      final crudo = jsonDecode(_json) as Map<String, dynamic>;
      expect(_datos.sustantivos.length, (crudo['sustantivos'] as List).length);
    });

    test('la clase de cada palabra coincide con cómo se escribe', () {
      // La red de contención: el JSON no pasa por ninguna validación cuando se
      // edita a mano, así que acá se deduce la clase del deletreo y se compara.
      for (final s in _datos.sustantivos) {
        final masculino = s.clase.nombre.startsWith('m');
        expect(
          claseDeducida(s.italiano, masculino: masculino),
          s.clase.nombre,
          reason: '"${s.italiano}" está etiquetado como ${s.clase.nombre}',
        );
      }
    });

    test('cada clase trae los tres artículos y su explicación', () {
      expect(_datos.clases, isNotEmpty);
      for (final clase in _datos.clases.values) {
        expect(clase.determinativo, isNotEmpty, reason: clase.nombre);
        expect(clase.indeterminativo, isNotEmpty, reason: clase.nombre);
        expect(clase.determinativoPlural, isNotEmpty, reason: clase.nombre);
        expect(clase.explicacion, isNotEmpty, reason: clase.nombre);
      }
    });

    test('todos los determinados están entre los botones que se ofrecen', () {
      for (final s in _datos.sustantivos) {
        expect(articulosDeterminados, contains(s.clase.determinativo),
            reason: s.italiano);
      }
    });

    test('no hay palabras repetidas', () {
      final italianos = _datos.sustantivos.map((s) => s.italiano).toList();
      expect(italianos.toSet().length, italianos.length);
    });

    test('están cubiertas las cinco clases', () {
      final usadas = _datos.sustantivos.map((s) => s.clase.nombre).toSet();
      expect(usadas.length, 5, reason: 'faltan clases sin ninguna palabra');
    });

    test('hay palabras donde el género no coincide con el español', () {
      // Son las que más hacen tropezar: conviene que no falten.
      final enganosas = _datos.sustantivos.where((s) => s.generoEnganoso);
      expect(enganosas, isNotEmpty);
    });
  });

  group('DatosArticoli.desdeJson', () {
    test('descarta la palabra que apunta a una clase que no existe', () {
      final datos = DatosArticoli.desdeJson(jsonDecode('''
        {
          "version": 1,
          "clases": {"m_consonante": {"determinativo": "il", "indeterminativo": "un",
                     "determinativo_plural": "i", "explicacion": "..."}},
          "sustantivos": [
            {"it": "libro", "clase": "m_consonante", "es": "libro"},
            {"it": "gnomo", "clase": "clase_inventada", "es": "gnomo"}
          ]
        }
      ''') as Map<String, dynamic>);

      expect(datos.sustantivos.map((s) => s.italiano), ['libro']);
    });

    test('un JSON vacío no rompe', () {
      final datos = DatosArticoli.desdeJson(
          jsonDecode('{}') as Map<String, dynamic>);
      expect(datos.sustantivos, isEmpty);
      expect(datos.clases, isEmpty);
    });

    test('usa el italiano si falta la traducción', () {
      final datos = DatosArticoli.desdeJson(jsonDecode('''
        {"clases": {"c": {"determinativo": "il", "indeterminativo": "un",
         "determinativo_plural": "i", "explicacion": "x"}},
         "sustantivos": [{"it": "libro", "clase": "c"}]}
      ''') as Map<String, dynamic>);

      expect(datos.sustantivos.single.espanol, 'libro');
    });
  });

  group('RepositorioArticoli', () {
    test('carga las palabras del asset', () async {
      final repo = _repo();
      await repo.cargar();

      expect(repo.datos.sustantivos.length, _datos.sustantivos.length);
      expect(repo.version, _datos.version);
    });

    test('un asset ilegible lo deja vacío en vez de tirar', () async {
      final repo = _repo(asset: 'esto no es JSON');
      await repo.cargar();

      expect(repo.datos.sustantivos, isEmpty);
    });

    test('cargar dos veces no duplica', () async {
      final repo = _repo();
      await repo.cargar();
      await repo.cargar();

      expect(repo.datos.sustantivos.length, _datos.sustantivos.length);
    });

    test('una versión más nueva reemplaza a la del asset', () async {
      final repo = _repo(codigo: 200, remoto: '''
        {"version": 99,
         "clases": {"m_consonante": {"determinativo": "il", "indeterminativo": "un",
          "determinativo_plural": "i", "explicacion": "..."}},
         "sustantivos": [{"it": "tavolo", "clase": "m_consonante", "es": "mesa"}]}
      ''');
      await repo.cargar();

      expect(await repo.verificarActualizacion(), isTrue);
      expect(repo.version, 99);
      expect(repo.datos.sustantivos.single.italiano, 'tavolo');
    });

    test('una versión igual o más vieja no cambia nada', () async {
      final repo = _repo(codigo: 200, remoto: '{"version": 1, "sustantivos": []}');
      await repo.cargar();

      expect(await repo.verificarActualizacion(), isFalse);
      expect(repo.datos.sustantivos, isNotEmpty);
    });

    test('sin internet se sigue con las que ya están', () async {
      final repo = RepositorioArticoli(
        leerAsset: (_) async => _json,
        cliente: MockClient((_) async => throw const SocketException('sin red')),
        carpeta: () async => null,
      );
      await repo.cargar();

      expect(await repo.verificarActualizacion(), isFalse);
      expect(repo.datos.sustantivos, isNotEmpty);
    });

    test('un JSON remoto roto no borra las palabras', () async {
      final repo = _repo(codigo: 200, remoto: 'no es json');
      await repo.cargar();

      expect(await repo.verificarActualizacion(), isFalse);
      expect(repo.datos.sustantivos, isNotEmpty);
    });

    test('guarda la tanda nueva para la próxima vez', () async {
      final dir = Directory.systemTemp.createTempSync('articoli_test');
      addTearDown(() => dir.deleteSync(recursive: true));

      const remoto = '''
        {"version": 50,
         "clases": {"m_consonante": {"determinativo": "il", "indeterminativo": "un",
          "determinativo_plural": "i", "explicacion": "..."}},
         "sustantivos": [{"it": "tavolo", "clase": "m_consonante", "es": "mesa"}]}
      ''';

      final repo = RepositorioArticoli(
        leerAsset: (_) async => _json,
        cliente: MockClient((_) async => http.Response(remoto, 200)),
        carpeta: () async => dir,
      );
      await repo.cargar();
      await repo.verificarActualizacion();

      final despues = RepositorioArticoli(
        leerAsset: (_) async => throw StateError('no debería leer el asset'),
        cliente: MockClient((_) async => http.Response('', 404)),
        carpeta: () async => dir,
      );
      await despues.cargar();

      expect(despues.version, 50);
      expect(despues.datos.sustantivos.single.italiano, 'tavolo');
    });
  });
}
