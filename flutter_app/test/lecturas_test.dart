import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tukyliano/datos/buscador_de_palabras.dart';
import 'package:tukyliano/datos/descargas.dart';
import 'package:tukyliano/datos/repositorio_diccionario.dart';
import 'package:tukyliano/datos/quien_soy.dart';
import 'package:tukyliano/datos/repositorio_lecturas.dart';
import 'package:tukyliano/ia/servidor.dart';
import 'package:tukyliano/modelos/lectura.dart';
import 'package:tukyliano/pantallas/pantalla_lecturas.dart';
import 'package:tukyliano/tema.dart';

import 'descargas_falsas.dart';
import 'reproductor_falso.dart';
import 'util_pantalla.dart';

/// El catálogo de verdad, el que viaja en el APK.
final _json = File('assets/favole.json').readAsStringSync();

/// Una carpeta de verdad: es lo que en el celular es la carpeta privada.
Directory _carpeta() {
  final dir = Directory.systemTemp.createTempSync('tukyliano_favole');
  addTearDown(() => dir.deleteSync(recursive: true));
  return dir;
}

DescargasEnElCelular _descargas({
  Directory? dir,
  int estado = 200,
  List<int>? cuerpo,
  Object? explota,
  void Function(String)? anotar,
}) {
  // Una sola carpeta por test. Resolverla adentro del cierre creaba una
  // temporal nueva en cada consulta, y la pantalla consulta veintidós veces
  // seguidas al abrirse.
  final carpeta = dir ?? _carpeta();
  return DescargasEnElCelular(
    carpeta: () async => carpeta,
    cliente: MockClient((pedido) async {
      anotar?.call(pedido.url.toString());
      if (explota != null) throw explota;
      return http.Response.bytes(cuerpo ?? List.filled(64, 7), estado);
    }),
  );
}

Future<void> _abrir(
  WidgetTester tester, {
  required DescargasFalsas descargas,
  required ReproductorFalso reproductor,
  String? catalogo,
  BuscadorDePalabras? buscador,
}) async {
  usarPantallaDeCelular(tester);
  await tester.pumpWidget(MaterialApp(
    theme: Tema.datos,
    home: Scaffold(
      body: PantallaLecturas(
        repositorio: RepositorioLecturas(
          leerAsset: (_) async => catalogo ?? _json,
        ),
        descargas: descargas,
        reproductor: reproductor,
        diccionario: RepositorioDiccionario(
          leerAsset: (_) async => _diccionarioDePrueba,
        ),
        buscador: buscador,
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

/// Un diccionario chico: los tests no tienen por qué depender de las catorce
/// mil palabras del de verdad.
const String _diccionarioDePrueba = '''
{
  "version": 1,
  "it": {"cicala": ["cigarra"], "formica": ["hormiga"]},
  "es": {"cigarra": ["cicala"], "hormiga": ["formica"]}
}
''';

void main() {
  group('el catálogo', () {
    final datos = jsonDecode(_json) as Map<String, dynamic>;
    final lecturas = (datos['favole'] as List).cast<Map<String, dynamic>>();

    test('tiene fábulas', () {
      expect(lecturas, isNotEmpty);
    });

    test('todas tienen título, archivo, duración y peso', () {
      for (final f in lecturas) {
        expect(f['titulo'], isNotEmpty, reason: '$f');
        expect(f['archivo'], isNotEmpty, reason: '${f['titulo']}');
        expect(f['segundos'], greaterThan(0), reason: '${f['titulo']}');
        expect(f['bytes'], greaterThan(0), reason: '${f['titulo']}');
      }
    });

    test('ninguna pasa de cuatro minutos', () {
      // Es la razón de ser de esta sección: si no entendiste una, perdiste
      // dos minutos y no un capítulo. Una fábula larga rompe el trato.
      for (final f in lecturas) {
        expect(f['segundos'], lessThan(4 * 60), reason: '${f['titulo']}');
      }
    });

    test('los títulos no tienen la codificación rota', () {
      // archive.org devuelve "Il Topo di cittÃÂÃÂ..." en vez de "città".
      // El script lo arregla; esto verifica que lo siga arreglando.
      for (final f in lecturas) {
        expect(f['titulo'], isNot(contains('Ã')), reason: '${f['titulo']}');
      }
    });

    test('no hay dos con el mismo archivo', () {
      final nombres = lecturas.map((f) => f['archivo']).toList();
      expect(nombres.toSet().length, nombres.length);
    });

    test('se bajan por https', () {
      expect(datos['base'], startsWith('https://'));
    });

    test('dice quién las grabó', () {
      // Son voluntarios que leyeron esto gratis. Se nombra.
      expect(datos['credito'], contains('LibriVox'));
    });
  });

  group('bajar', () {
    test('guarda el archivo y después dice que ya está', () async {
      final dir = _carpeta();
      final descargas = _descargas(dir: dir);

      expect(await descargas.yaEsta('una.mp3'), isFalse);
      final quedo = await descargas.bajar('https://x.test/una.mp3', 'una.mp3');

      expect(quedo, isNotNull);
      expect(await descargas.yaEsta('una.mp3'), isTrue);
      expect(await quedo!.length(), 64);
    });

    test('lo que ya está no se vuelve a bajar', () async {
      final dir = _carpeta();
      final pedidos = <String>[];
      final descargas = _descargas(dir: dir, anotar: pedidos.add);

      await descargas.bajar('https://x.test/una.mp3', 'una.mp3');
      await descargas.bajar('https://x.test/una.mp3', 'una.mp3');

      // El que la bajó ya gastó sus datos una vez.
      expect(pedidos.length, 1);
    });

    test('si el servidor contesta mal no deja nada', () async {
      final dir = _carpeta();
      final descargas = _descargas(dir: dir, estado: 404);

      expect(
        await descargas.bajar('https://x.test/una.mp3', 'una.mp3'),
        isNull,
      );
      expect(await descargas.yaEsta('una.mp3'), isFalse);
    });

    test('si se corta la bajada no deja un archivo roto', () async {
      final dir = _carpeta();
      final descargas = _descargas(dir: dir, explota: const SocketException('sin señal'));

      expect(
        await descargas.bajar('https://x.test/una.mp3', 'una.mp3'),
        isNull,
      );
      // Lo peor que podría pasar: que quede un mp3 a medias, que la próxima
      // vez se dé por bueno —ya existe— y no suene nunca.
      expect(await descargas.yaEsta('una.mp3'), isFalse);
    });

    test('una respuesta vacía tampoco cuenta como bajada', () async {
      final dir = _carpeta();
      final descargas = _descargas(dir: dir, cuerpo: const []);

      expect(
        await descargas.bajar('https://x.test/una.mp3', 'una.mp3'),
        isNull,
      );
      expect(await descargas.yaEsta('una.mp3'), isFalse);
    });

    test('borrar libera el lugar', () async {
      final dir = _carpeta();
      final descargas = _descargas(dir: dir);

      await descargas.bajar('https://x.test/una.mp3', 'una.mp3');
      expect(await descargas.cuantoOcupa(), 64);

      await descargas.borrar('una.mp3');
      expect(await descargas.yaEsta('una.mp3'), isFalse);
      expect(await descargas.cuantoOcupa(), 0);
    });
  });

  group('la pantalla', () {
    testWidgets('muestra las fábulas con su duración y su peso',
        (tester) async {
      await _abrir(
        tester,
        descargas: DescargasFalsas(),
        reproductor: ReproductorFalso(),
      );

      expect(find.text('La Cicala e la Formica'), findsOne);
      // Sin bajar se dice cuánto pesa: el que la toca gasta sus datos.
      expect(find.textContaining('KB'), findsWidgets);
    });

    testWidgets('no baja nada sola al abrir', (tester) async {
      final descargas = DescargasFalsas();
      await _abrir(
        tester,
        descargas: descargas,
        reproductor: ReproductorFalso(),
      );

      // Entrar a mirar la lista no tiene por qué gastar datos de nadie.
      expect(descargas.pedidas, isEmpty);
    });

    testWidgets('tocar una la baja y la pone a sonar', (tester) async {
      final descargas = DescargasFalsas();
      final reproductor = ReproductorFalso();
      await _abrir(
        tester,
        descargas: descargas,
        reproductor: reproductor,
      );

      await tester.tap(find.text('La Cicala e la Formica'));
      await tester.pumpAndSettle();

      expect(descargas.pedidas.length, 1);
      expect(descargas.pedidas.first, contains('favole_01_libro01'));
      expect(reproductor.andando, isTrue);
      // El título va a la notificación: es lo que se lee con el celular
      // bloqueado.
      expect(reproductor.elTitulo, 'La Cicala e la Formica');
    });

    testWidgets('la segunda vez no la vuelve a bajar', (tester) async {
      final descargas = DescargasFalsas();
      final reproductor = ReproductorFalso();
      await _abrir(
        tester,
        descargas: descargas,
        reproductor: reproductor,
      );

      await tester.tap(find.text('La Cicala e la Formica'));
      await tester.pumpAndSettle();
      // Volver a la lista y entrar de nuevo: el audio ya está.
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      await tester.tap(find.text('La Cicala e la Formica'));
      await tester.pumpAndSettle();

      // El que la bajó ya gastó sus datos una vez.
      expect(descargas.pedidas.length, 1);
      expect(reproductor.andando, isTrue);
    });

    testWidgets('tocar una abre su pantalla con el texto', (tester) async {
      final reproductor = ReproductorFalso();
      await _abrir(
        tester,
        descargas: DescargasFalsas(),
        reproductor: reproductor,
      );

      await tester.tap(find.text('La Cicala e la Formica'));
      await tester.pumpAndSettle();

      // El primer verso de la fábula, que solo está en la pantalla de la
      // fábula y no en la lista.
      expect(find.text('La Cicala che imprudente'), findsOne);
      // Se entra desde el play, así que arranca sonando: hacer tocar play
      // otra vez sería pedir dos veces lo mismo.
      expect(reproductor.andando, isTrue);
      expect(find.text('Pausar'), findsOne);
    });

    testWidgets('desde la fábula se vuelve a la lista', (tester) async {
      await _abrir(
        tester,
        descargas: DescargasFalsas(),
        reproductor: ReproductorFalso(),
      );

      await tester.tap(find.text('La Cicala e la Formica'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(find.text('La Cicala che imprudente'), findsNothing);
      expect(find.text('Il Corvo e la Volpe'), findsOne);
    });

    testWidgets('el botón de la fábula pausa y vuelve a poner',
        (tester) async {
      final reproductor = ReproductorFalso();
      await _abrir(
        tester,
        descargas: DescargasFalsas(),
        reproductor: reproductor,
      );

      await tester.tap(find.text('La Cicala e la Formica'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pausar'));
      await tester.pumpAndSettle();
      expect(reproductor.andando, isFalse);

      await tester.tap(find.text('Escuchar'));
      await tester.pumpAndSettle();
      expect(reproductor.andando, isTrue);
    });

    testWidgets('tocar una palabra dice qué quiere decir', (tester) async {
      // En un texto en verso del siglo XIX, esto es lo que separa leerlo de
      // mirarlo.
      await _abrir(
        tester,
        descargas: DescargasFalsas(),
        reproductor: ReproductorFalso(),
      );

      await tester.tap(find.text('La Cicala e la Formica'));
      await tester.pumpAndSettle();
      // Sobre la palabra y no sobre el renglón: cada palabra es su propio
      // pedacito tocable.
      await tester.tapOnText(find.textRange.ofSubstring('Cicala che'));
      await tester.pumpAndSettle();

      expect(find.textContaining('cigarra'), findsOne);
    });

    testWidgets('una palabra que no está se le pregunta al servidor',
        (tester) async {
      // Es el caso de Matías: apretó "lumicino" en Il Lupo e il Cane y no
      // estaba. Ahora el servidor la busca, la guarda, y el próximo que la
      // toque la recibe de la base sin gastar nada.
      final pedidos = <String>[];
      await _abrir(
        tester,
        descargas: DescargasFalsas(),
        reproductor: ReproductorFalso(),
        buscador: BuscadorDePalabras(
          quienSoy: QuienSoy(carpeta: () async => null),
          servidor: Servidor(
            url: 'https://servidor-de-mentira',
            cliente: MockClient((pedido) async {
              pedidos.add(pedido.body);
              return http.Response(
                jsonEncode({'es': ['en las últimas'], 'base': ''}),
                200,
                headers: {'content-type': 'application/json; charset=utf-8'},
              );
            }),
          ),
        ),
      );

      await tester.tap(find.text('La Cicala e la Formica'));
      await tester.pumpAndSettle();
      // "imprudente" no está en el diccionario chico de este test.
      await tester.tapOnText(find.textRange.ofSubstring('imprudente'));
      await tester.pumpAndSettle();

      expect(find.textContaining('en las últimas'), findsOne);
      // Y se le mandó el renglón, que es lo que desambigua.
      expect(pedidos.single, contains('imprudente'));
      expect(pedidos.single, contains('La Cicala che imprudente'));
    });

    testWidgets('si el servidor tampoco la sabe, lo dice y no se rompe',
        (tester) async {
      await _abrir(
        tester,
        descargas: DescargasFalsas(),
        reproductor: ReproductorFalso(),
        buscador: BuscadorDePalabras(
          quienSoy: QuienSoy(carpeta: () async => null),
          servidor: Servidor(
            url: 'https://servidor-de-mentira',
            cliente: MockClient((_) async => throw const SocketException('')),
          ),
        ),
      );

      await tester.tap(find.text('La Cicala e la Formica'));
      await tester.pumpAndSettle();
      await tester.tapOnText(find.textRange.ofSubstring('imprudente'));
      await tester.pumpAndSettle();

      expect(find.textContaining('no está en el diccionario'), findsOne);
    });

    testWidgets('si no se pudo bajar lo dice y deja reintentar',
        (tester) async {
      await _abrir(
        tester,
        descargas: DescargasFalsas(sePuedeBajar: false),
        reproductor: ReproductorFalso(),
      );

      await tester.tap(find.text('La Cicala e la Formica'));
      await tester.pumpAndSettle();

      expect(find.textContaining('No se pudo bajar'), findsOne);
      expect(find.byIcon(Icons.refresh), findsOne);
    });

    testWidgets('al salir pausa, pero no suelta el reproductor',
        (tester) async {
      final reproductor = ReproductorFalso();
      await _abrir(
        tester,
        descargas: DescargasFalsas(),
        reproductor: reproductor,
      );
      await tester.tap(find.text('La Cicala e la Formica'));
      await tester.pumpAndSettle();

      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await tester.pumpAndSettle();

      expect(reproductor.andando, isFalse);
      // El reproductor es uno solo para toda la app: lo suelta main.dart.
      expect(reproductor.soltadas, 0);
    });

    testWidgets('dice quién las grabó', (tester) async {
      await _abrir(
        tester,
        descargas: DescargasFalsas(),
        reproductor: ReproductorFalso(),
      );

      await tester.drag(find.byType(ListView), const Offset(0, -4000));
      await tester.pumpAndSettle();

      expect(find.textContaining('LibriVox'), findsOne);
    });

    testWidgets('sin fábulas no se cae', (tester) async {
      await _abrir(
        tester,
        descargas: DescargasFalsas(),
        reproductor: ReproductorFalso(),
        catalogo: '{"version": 1, "lecturas": []}',
      );

      expect(find.textContaining('Todavía no hay fábulas'), findsOne);
    });
  });

  group('los tiempos del texto', () {
    final datos = jsonDecode(_json) as Map<String, dynamic>;
    final lecturas = (datos['favole'] as List).cast<Map<String, dynamic>>();

    Lectura deLaLista(String parteDelTitulo) => Lectura.desdeJson(
          lecturas.firstWhere(
            (f) => (f['titulo'] as String).contains(parteDelTitulo),
          ),
        );

    test('la que está marcada sabe seguir el audio', () {
      expect(deLaLista('Lupo e il Cane').sigueElAudio, isTrue);
    });

    test('ahora las veintidós siguen el audio', () {
      // Antes había una sola marcada a mano. Las otras veintiuna las alineó
      // scripts/alinear_favole.py y ya no queda ninguna con el texto quieto.
      for (final mapa in lecturas) {
        expect(Lectura.desdeJson(mapa).sigueElAudio, isTrue,
            reason: mapa['titulo'] as String);
      }
    });

    test('una sin marcar no finge que sigue el audio', () {
      // Mostrar el renglón equivocado iluminado sería peor que no iluminar
      // ninguno, así que la que no tiene tiempos lo dice.
      final sinMarcar = Lectura.desdeJson({
        'id': 'x',
        'titulo': 'Sin marcar',
        'archivo': 'x.mp3',
        'segundos': 60,
        'bytes': 1000,
        'renglones': [
          {'t': 'Un renglón'},
          {'t': 'y otro'},
        ],
      });
      expect(sinMarcar.sigueElAudio, isFalse);
      expect(sinMarcar.cualSuena(const Duration(seconds: 10)), -1);
      expect(sinMarcar.dondeEmpiezaDeVerdad, isNull);
    });

    testWidgets('sabe qué renglón suena en cada momento', (tester) async {
      final lectura = deLaLista('Lupo e il Cane');

      // Antes del primer verso está la presentación de LibriVox.
      expect(lectura.cualSuena(const Duration(seconds: 5)), -1);
      expect(lectura.cualSuena(const Duration(seconds: 16)), 0);
      expect(lectura.cualSuena(const Duration(seconds: 23)), 2);
      // Y al final, el cierre.
      expect(lectura.cualSuena(const Duration(seconds: 145)), -1);
    });

    test('los tiempos van en orden y caben en el audio', () {
      for (final mapa in lecturas) {
        final lectura = Lectura.desdeJson(mapa);
        if (!lectura.sigueElAudio) continue;
        var antes = Duration.zero;
        for (final renglon in lectura.renglones) {
          final desde = renglon.desde;
          if (desde == null) continue;
          expect(desde, greaterThanOrEqualTo(antes),
              reason: '${lectura.titulo}: "${renglon.texto}" va para atrás');
          expect(desde.inSeconds, lessThanOrEqualTo(lectura.segundos),
              reason: '${lectura.titulo}: "${renglon.texto}" se pasa del fin');
          antes = desde;
        }
      }
    });

    testWidgets('arranca donde arranca la fábula, no donde arranca el archivo',
        (tester) async {
      // Antes del primer verso va la presentación de LibriVox: en una fábula
      // de minuto y medio son dieciséis segundos de espera.
      final reproductor = ReproductorFalso();
      await _abrir(
        tester,
        descargas: DescargasFalsas(),
        reproductor: reproductor,
      );

      await tester.tap(find.text('Il Lupo e il Cane'));
      await tester.pumpAndSettle();

      expect(reproductor.donde, const Duration(seconds: 16));
    });

    testWidgets('cada una se saltea su propia presentación', (tester) async {
      // No es un número fijo: la de Il Lupo e il Cane dura 16 segundos y la
      // de La Cicala e la Formica, treinta. Medio minuto de "registrato per
      // LibriVox.org da..." antes de un poema de dos minutos.
      final reproductor = ReproductorFalso();
      await _abrir(
        tester,
        descargas: DescargasFalsas(),
        reproductor: reproductor,
      );

      await tester.tap(find.text('La Cicala e la Formica'));
      await tester.pumpAndSettle();

      expect(reproductor.donde, const Duration(milliseconds: 30060));
    });
  });
}
