import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tukyliano/datos/repositorio_racconti.dart';
import 'package:tukyliano/logica/preposiciones.dart';
import 'package:tukyliano/modelos/articulo.dart';
import 'package:tukyliano/modelos/racconto.dart';

final _json = File('assets/racconti.json').readAsStringSync();
final _datos =
    DatosRacconti.desdeJson(jsonDecode(_json) as Map<String, dynamic>);

/// Los sustantivos que ya se practican en Articoli, en singular y en plural.
final _sustantivos = () {
  final crudo = jsonDecode(File('assets/articoli.json').readAsStringSync());
  final datos = DatosArticoli.desdeJson(crudo as Map<String, dynamic>);
  return {
    for (final s in datos.sustantivos) ...[
      s.italiano.toLowerCase(),
      if (s.tienePlural) s.italianoPlural.toLowerCase(),
    ],
  };
}();

const _articulos = [
  'il', 'lo', 'la', "l'", 'i', 'gli', 'le', 'un', 'uno', 'una', "un'",
];

/// Palabras de puro andamiaje: no son vocabulario que haya que aprender, son
/// las que sostienen cualquier frase.
const _gramatica = ['e', 'ed', 'ma', 'o', 'che', 'non', 'ci', 'si', 'mi',
                    'ti', 'ne'];

RepositorioRacconti _repo({String? asset, String remoto = '', int codigo = 404}) =>
    RepositorioRacconti(
      leerAsset: (_) async => asset ?? _json,
      cliente: MockClient((_) async => http.Response(remoto, codigo)),
      // Sin carpeta: en los tests no hay path_provider, así que no se cachea.
      carpeta: () async => null,
    );

/// Parte un texto italiano en palabras.
///
/// El apóstrofo queda pegado a lo de la izquierda, que es como funciona la
/// elisión: "l'acqua" son dos palabras, l' y acqua.
Set<String> _palabras(String texto) {
  final limpio = texto
      .toLowerCase()
      .replaceAll('’', "'")
      .replaceAll("'", "' ")
      .replaceAll(RegExp(r'[.,!?;:«»"()]'), ' ');
  return limpio.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toSet();
}

/// Todo lo que se da por sabido: lo que ya se practica en otras secciones más
/// lo que el JSON declara como común.
final _conocidas = <String>{
  ..._articulos,
  ..._gramatica,
  "d'", // di elidido: un po' d'acqua
  for (final p in preposicionesSimples) ...formasDe(p),
  ..._sustantivos,
  for (final p in _datos.vocabularioComun) ..._palabras(p.italiano),
  for (final n in _datos.nombres) n.toLowerCase(),
};

/// Las palabras que declara el propio cuento. Se parten por "/" para que una
/// sola entrada cubra las dos formas ("caldo/calda").
Set<String> _declaradas(Racconto r) => {
      for (final p in r.vocabulario)
        for (final alt in p.italiano.split('/')) ..._palabras(alt),
    };

void main() {
  group('el asset de cuentos', () {
    test('tiene cuentos y ninguno se descartó al leerlo', () {
      expect(_datos.racconti, isNotEmpty);
      final crudo = jsonDecode(_json) as Map<String, dynamic>;
      expect(_datos.racconti.length, (crudo['racconti'] as List).length);
    });

    test('ninguna palabra sale de la nada', () {
      // Esta es la que hace que "cuento graduado" sea algo verificado y no
      // una promesa: cada palabra italiana tiene que estar practicada en otra
      // sección o declarada en el vocabulario del cuento. Si se cuela una
      // palabra nueva sin glosar, acá salta.
      for (final r in _datos.racconti) {
        final declaradas = _declaradas(r);
        for (final linea in r.lineas) {
          for (final palabra in _palabras(linea.italiano)) {
            expect(
              _conocidas.contains(palabra) || declaradas.contains(palabra),
              isTrue,
              reason: '"$palabra" en "${r.id}" no está en ningún lado',
            );
          }
        }
      }
    });

    test('no hay vocabulario declarado que después no se use', () {
      // Si sobra una entrada es que la frase cambió y la glosa quedó
      // colgada, tapando un agujero futuro.
      for (final r in _datos.racconti) {
        final usadas = {
          for (final linea in r.lineas) ..._palabras(linea.italiano),
        };
        for (final p in r.vocabulario) {
          final formas = {
            for (final alt in p.italiano.split('/')) ..._palabras(alt),
          };
          expect(formas.any(usadas.contains), isTrue,
              reason: '"${p.italiano}" de "${r.id}" no se usa en el cuento');
        }
      }
    });

    test('cada renglón trae las dos lenguas', () {
      for (final r in _datos.racconti) {
        for (final linea in r.lineas) {
          expect(linea.italiano, isNotEmpty, reason: r.id);
          expect(linea.espanol, isNotEmpty, reason: '${r.id}: ${linea.italiano}');
        }
      }
    });

    test('cada cuento trae título en los dos idiomas y vocabulario', () {
      for (final r in _datos.racconti) {
        expect(r.titulo, isNotEmpty, reason: r.id);
        expect(r.tituloEspanol, isNotEmpty, reason: r.id);
        expect(r.vocabulario, isNotEmpty, reason: r.id);
      }
    });

    test('cada glosa del vocabulario tiene traducción', () {
      for (final r in _datos.racconti) {
        for (final p in r.vocabulario) {
          expect(p.espanol, isNotEmpty, reason: '${r.id}: ${p.italiano}');
        }
      }
    });

    test('no hay ids repetidos', () {
      final ids = _datos.racconti.map((r) => r.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('ningún cuento es demasiado corto ni interminable', () {
      // Con menos de ocho renglones no es un cuento, es un ejemplo. El techo
      // es alto a propósito: los largos son justamente los que valen la pena
      // cuando ya se lee un poco, pero sin scroll infinito.
      for (final r in _datos.racconti) {
        expect(r.lineas.length, greaterThanOrEqualTo(8), reason: r.id);
        expect(r.lineas.length, lessThanOrEqualTo(60), reason: r.id);
      }
    });

    test('hay al menos un cuento largo y uno corto', () {
      // Si se fueran todos para el mismo lado, no habría por dónde empezar
      // ni adónde llegar.
      final largos = _datos.racconti.map((r) => r.lineas.length);
      expect(largos.reduce((a, b) => a < b ? a : b), lessThanOrEqualTo(15));
      expect(largos.reduce((a, b) => a > b ? a : b), greaterThanOrEqualTo(30));
    });

    test('vienen ordenados de más fácil a más difícil', () {
      final niveles = _datos.racconti.map((r) => r.nivel).toList();
      expect(niveles, orderedEquals(List.of(niveles)..sort()));
    });

    test('hay cuentos de los tres temas', () {
      final crudo = jsonDecode(_json) as Map<String, dynamic>;
      final temas = {
        for (final r in crudo['racconti'] as List)
          (r as Map<String, dynamic>)['tema'],
      };
      expect(temas, containsAll(['cotidiano', 'italia', 'trabajo']));
    });
  });

  group('DatosRacconti.desdeJson', () {
    test('descarta el cuento sin renglones', () {
      final datos = DatosRacconti.desdeJson(jsonDecode('''
        {"racconti": [
          {"id": "uno", "lineas": [{"it": "Ciao.", "es": "Hola."}]},
          {"id": "vacio", "lineas": []}
        ]}
      ''') as Map<String, dynamic>);

      expect(datos.racconti.single.id, 'uno');
    });

    test('descarta el cuento sin id, que no se podría abrir', () {
      final datos = DatosRacconti.desdeJson(jsonDecode('''
        {"racconti": [{"lineas": [{"it": "Ciao.", "es": "Hola."}]}]}
      ''') as Map<String, dynamic>);

      expect(datos.racconti, isEmpty);
    });

    test('sin título usa el id', () {
      final datos = DatosRacconti.desdeJson(jsonDecode('''
        {"racconti": [{"id": "uno", "lineas": [{"it": "Ciao.", "es": "Hola."}]}]}
      ''') as Map<String, dynamic>);

      expect(datos.racconti.single.titulo, 'uno');
    });

    test('ordena por nivel', () {
      final datos = DatosRacconti.desdeJson(jsonDecode('''
        {"racconti": [
          {"id": "dificil", "nivel": 3, "lineas": [{"it": "a", "es": "a"}]},
          {"id": "facil", "nivel": 1, "lineas": [{"it": "b", "es": "b"}]}
        ]}
      ''') as Map<String, dynamic>);

      expect(datos.racconti.map((r) => r.id), ['facil', 'dificil']);
    });

    test('un JSON vacío no rompe', () {
      final datos =
          DatosRacconti.desdeJson(jsonDecode('{}') as Map<String, dynamic>);
      expect(datos.racconti, isEmpty);
      expect(datos.vocabularioComun, isEmpty);
      expect(datos.nombres, isEmpty);
    });
  });

  group('RepositorioRacconti', () {
    test('carga los cuentos del asset', () async {
      final repo = _repo();
      await repo.cargar();

      expect(repo.datos.racconti.length, _datos.racconti.length);
      expect(repo.version, _datos.version);
    });

    test('un asset ilegible lo deja vacío en vez de tirar', () async {
      final repo = _repo(asset: 'esto no es JSON');
      await repo.cargar();

      expect(repo.datos.racconti, isEmpty);
    });

    test('cargar dos veces no duplica', () async {
      final repo = _repo();
      await repo.cargar();
      await repo.cargar();

      expect(repo.datos.racconti.length, _datos.racconti.length);
    });

    test('una versión más nueva reemplaza a la del asset', () async {
      final repo = _repo(codigo: 200, remoto: '''
        {"version": 99, "racconti": [
          {"id": "nuevo", "titulo": "Nuovo", "titulo_es": "Nuevo",
           "lineas": [{"it": "Ciao.", "es": "Hola."}]}
        ]}
      ''');
      await repo.cargar();

      expect(await repo.verificarActualizacion(), isTrue);
      expect(repo.version, 99);
      expect(repo.datos.racconti.single.id, 'nuevo');
    });

    test('una versión igual o más vieja no cambia nada', () async {
      final repo = _repo(codigo: 200, remoto: '{"version": 1, "racconti": []}');
      await repo.cargar();

      expect(await repo.verificarActualizacion(), isFalse);
      expect(repo.datos.racconti, isNotEmpty);
    });

    test('sin internet se sigue con los que ya están', () async {
      final repo = RepositorioRacconti(
        leerAsset: (_) async => _json,
        cliente: MockClient((_) async => throw const SocketException('sin red')),
        carpeta: () async => null,
      );
      await repo.cargar();

      expect(await repo.verificarActualizacion(), isFalse);
      expect(repo.datos.racconti, isNotEmpty);
    });

    test('un JSON remoto roto no borra los cuentos', () async {
      final repo = _repo(codigo: 200, remoto: 'no es json');
      await repo.cargar();

      expect(await repo.verificarActualizacion(), isFalse);
      expect(repo.datos.racconti, isNotEmpty);
    });

    test('guarda la tanda nueva para la próxima vez', () async {
      final dir = Directory.systemTemp.createTempSync('racconti_test');
      addTearDown(() => dir.deleteSync(recursive: true));

      const remoto = '''
        {"version": 50, "racconti": [
          {"id": "nuovo", "lineas": [{"it": "Ciao.", "es": "Hola."}]}
        ]}
      ''';

      final repo = RepositorioRacconti(
        leerAsset: (_) async => _json,
        cliente: MockClient((_) async => http.Response(remoto, 200)),
        carpeta: () async => dir,
      );
      await repo.cargar();
      await repo.verificarActualizacion();

      final despues = RepositorioRacconti(
        leerAsset: (_) async => throw StateError('no debería leer el asset'),
        cliente: MockClient((_) async => http.Response('', 404)),
        carpeta: () async => dir,
      );
      await despues.cargar();

      expect(despues.version, 50);
      expect(despues.datos.racconti.single.id, 'nuovo');
    });
  });
}
