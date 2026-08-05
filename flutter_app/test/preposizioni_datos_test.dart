import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tukyliano/datos/repositorio_preposizioni.dart';
import 'package:tukyliano/logica/preposiciones.dart';
import 'package:tukyliano/modelos/preposicion.dart';

final _json = File('assets/preposizioni.json').readAsStringSync();
final _datos =
    DatosPreposizioni.desdeJson(jsonDecode(_json) as Map<String, dynamic>);

RepositorioPreposizioni _repo(
        {String? asset, String remoto = '', int codigo = 404}) =>
    RepositorioPreposizioni(
      leerAsset: (_) async => asset ?? _json,
      cliente: MockClient((_) async => http.Response(remoto, codigo)),
      // Sin carpeta: en los tests no hay path_provider, así que no se cachea.
      carpeta: () async => null,
    );

/// Parte lo que va en el hueco. "nella" es una sola palabra, "per la" son dos
/// porque per no se contrae.
({String preposicion, String? articulo})? _analizar(String respuesta) {
  final palabras = respuesta.split(' ');
  if (palabras.length == 1) return separar(respuesta);
  if (palabras.length != 2) return null;
  if (!preposicionesSimples.contains(palabras[0])) return null;
  if (!articulosDeterminados.contains(palabras[1])) return null;
  return (preposicion: palabras[0], articulo: palabras[1]);
}

void main() {
  group('el asset de preposiciones', () {
    test('tiene frases y ninguna se descartó al leerla', () {
      expect(_datos.frases, isNotEmpty);
      // desdeJson tira las frases sin hueco o con la correcta fuera de los
      // botones, así que si faltara alguna es que estaba mal escrita.
      final crudo = jsonDecode(_json) as Map<String, dynamic>;
      expect(_datos.frases.length, (crudo['frases'] as List).length);
    });

    test('cada frase tiene un solo hueco', () {
      for (final f in _datos.frases) {
        expect(hueco.allMatches(f.frase).length, 1, reason: f.frase);
      }
    });

    test('la respuesta correcta está siempre entre los botones', () {
      for (final f in _datos.frases) {
        expect(f.opciones, contains(f.correcta), reason: f.frase);
      }
    });

    test('siempre son cuatro botones y ninguno repetido', () {
      for (final f in _datos.frases) {
        expect(f.opciones.length, 4, reason: f.frase);
        expect(f.opciones.toSet().length, 4, reason: f.frase);
      }
    });

    test('la correcta no cae siempre en el mismo botón', () {
      // Si no, se aprende la posición en vez de la preposición.
      final posiciones = {
        for (final f in _datos.frases) f.opciones.indexOf(f.correcta),
      };
      expect(posiciones.length, 4);
    });

    test('todas las respuestas son preposiciones de verdad', () {
      // La red de contención: si una quedó mal escrita ("nela", "sul'"),
      // acá no se puede analizar y salta.
      for (final f in _datos.frases) {
        expect(_analizar(f.correcta), isNotNull,
            reason: '"${f.correcta}" en "${f.frase}"');
      }
    });

    test('las contracciones del JSON coinciden con la tabla', () {
      for (final f in _datos.frases) {
        final partes = _analizar(f.correcta)!;
        final articulo = partes.articulo;
        if (articulo == null) continue;

        final contraida = contraer(partes.preposicion, articulo);
        if (contraida == null) {
          // per y con: tienen que ir separadas, en dos palabras.
          expect(f.correcta, '${partes.preposicion} $articulo',
              reason: '${partes.preposicion} no se contrae');
        } else {
          expect(f.correcta, contraida, reason: f.frase);
        }
      }
    });

    test('los distractores también son formas que existen', () {
      // Menos "perla", que está a propósito: es el error que se quiere
      // enseñar y además es una palabra italiana de verdad.
      const aProposito = {'perla'};
      for (final f in _datos.frases) {
        for (final opcion in f.opciones) {
          if (aProposito.contains(opcion)) continue;
          expect(_analizar(opcion), isNotNull,
              reason: '"$opcion" en "${f.frase}"');
        }
      }
    });

    test('todas las frases traen traducción y explicación', () {
      for (final f in _datos.frases) {
        expect(f.espanol, isNotEmpty, reason: f.frase);
        expect(f.explicacion, isNotEmpty, reason: f.frase);
      }
    });

    test('no hay frases repetidas', () {
      final frases = _datos.frases.map((f) => f.frase).toList();
      expect(frases.toSet().length, frases.length);
    });

    test('están practicadas las siete preposiciones', () {
      final usadas = {
        for (final f in _datos.frases) _analizar(f.correcta)!.preposicion,
      };
      expect(usadas, containsAll(preposicionesSimples));
    });

    test('hay frases con la preposición sola y otras contraída', () {
      // Las dos mitades del problema: elegir la preposición y saber si se
      // pega. Si faltara una, media práctica se perdería.
      final conArticulo =
          _datos.frases.where((f) => _analizar(f.correcta)!.articulo != null);
      final sinArticulo =
          _datos.frases.where((f) => _analizar(f.correcta)!.articulo == null);
      expect(conArticulo, isNotEmpty);
      expect(sinArticulo, isNotEmpty);
    });

    test('se practican los siete artículos de la tabla', () {
      final usados = {
        for (final f in _datos.frases) _analizar(f.correcta)!.articulo,
      }..remove(null);
      expect(usados, containsAll(articulosDeterminados));
    });
  });

  group('FrasePreposicion', () {
    const frase = FrasePreposicion(
      frase: 'Vado ___ città',
      correcta: 'in',
      espanol: 'voy a la ciudad',
      opciones: ['a', 'in', 'alla', 'nella'],
    );

    test('parte la frase en lo de antes y lo de después del hueco', () {
      expect(frase.partes, ('Vado ', ' città'));
    });

    test('arma la frase resuelta', () {
      expect(frase.resuelta, 'Vado in città');
      expect(frase.conRespuesta('alla'), 'Vado alla città');
    });

    test('una frase sin hueco no rompe al partirla', () {
      const rota = FrasePreposicion(
        frase: 'Vado in città',
        correcta: 'in',
        espanol: '',
        opciones: ['in'],
      );
      expect(rota.partes, ('Vado in città', ''));
    });
  });

  group('DatosPreposizioni.desdeJson', () {
    test('descarta la frase sin hueco', () {
      final datos = DatosPreposizioni.desdeJson(jsonDecode('''
        {"version": 1, "frases": [
          {"frase": "Vado ___ Roma", "correcta": "a", "opciones": ["a", "in"]},
          {"frase": "Vado a Roma", "correcta": "a", "opciones": ["a", "in"]}
        ]}
      ''') as Map<String, dynamic>);

      expect(datos.frases.single.frase, 'Vado ___ Roma');
    });

    test('descarta la frase cuya respuesta no está entre los botones', () {
      // Sería imposible de contestar.
      final datos = DatosPreposizioni.desdeJson(jsonDecode('''
        {"frases": [
          {"frase": "Vado ___ Roma", "correcta": "da", "opciones": ["a", "in"]}
        ]}
      ''') as Map<String, dynamic>);

      expect(datos.frases, isEmpty);
    });

    test('un JSON vacío no rompe', () {
      final datos =
          DatosPreposizioni.desdeJson(jsonDecode('{}') as Map<String, dynamic>);
      expect(datos.frases, isEmpty);
      expect(datos.version, 0);
    });
  });

  group('RepositorioPreposizioni', () {
    test('carga las frases del asset', () async {
      final repo = _repo();
      await repo.cargar();

      expect(repo.datos.frases.length, _datos.frases.length);
      expect(repo.version, _datos.version);
    });

    test('un asset ilegible lo deja vacío en vez de tirar', () async {
      final repo = _repo(asset: 'esto no es JSON');
      await repo.cargar();

      expect(repo.datos.frases, isEmpty);
    });

    test('cargar dos veces no duplica', () async {
      final repo = _repo();
      await repo.cargar();
      await repo.cargar();

      expect(repo.datos.frases.length, _datos.frases.length);
    });

    test('una versión más nueva reemplaza a la del asset', () async {
      final repo = _repo(codigo: 200, remoto: '''
        {"version": 99, "frases": [
          {"frase": "Vado ___ Roma", "correcta": "a", "opciones": ["a", "in"]}
        ]}
      ''');
      await repo.cargar();

      expect(await repo.verificarActualizacion(), isTrue);
      expect(repo.version, 99);
      expect(repo.datos.frases.single.correcta, 'a');
    });

    test('una versión igual o más vieja no cambia nada', () async {
      final repo = _repo(codigo: 200, remoto: '{"version": 1, "frases": []}');
      await repo.cargar();

      expect(await repo.verificarActualizacion(), isFalse);
      expect(repo.datos.frases, isNotEmpty);
    });

    test('sin internet se sigue con las que ya están', () async {
      final repo = RepositorioPreposizioni(
        leerAsset: (_) async => _json,
        cliente: MockClient((_) async => throw const SocketException('sin red')),
        carpeta: () async => null,
      );
      await repo.cargar();

      expect(await repo.verificarActualizacion(), isFalse);
      expect(repo.datos.frases, isNotEmpty);
    });

    test('un JSON remoto roto no borra las frases', () async {
      final repo = _repo(codigo: 200, remoto: 'no es json');
      await repo.cargar();

      expect(await repo.verificarActualizacion(), isFalse);
      expect(repo.datos.frases, isNotEmpty);
    });

    test('guarda la tanda nueva para la próxima vez', () async {
      final dir = Directory.systemTemp.createTempSync('preposizioni_test');
      addTearDown(() => dir.deleteSync(recursive: true));

      const remoto = '''
        {"version": 50, "frases": [
          {"frase": "Vengo ___ Roma", "correcta": "da", "opciones": ["da", "a"]}
        ]}
      ''';

      final repo = RepositorioPreposizioni(
        leerAsset: (_) async => _json,
        cliente: MockClient((_) async => http.Response(remoto, 200)),
        carpeta: () async => dir,
      );
      await repo.cargar();
      await repo.verificarActualizacion();

      final despues = RepositorioPreposizioni(
        leerAsset: (_) async => throw StateError('no debería leer el asset'),
        cliente: MockClient((_) async => http.Response('', 404)),
        carpeta: () async => dir,
      );
      await despues.cargar();

      expect(despues.version, 50);
      expect(despues.datos.frases.single.frase, 'Vengo ___ Roma');
    });
  });
}
