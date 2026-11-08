import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tukyliano/datos/repositorio_podcast.dart';
import 'package:tukyliano/modelos/episodio.dart';
import 'package:tukyliano/pantallas/pantalla_podcast.dart';

import 'voz_falsa.dart';

/// El episodio de mentira: dos turnos, uno de cada uno.
const _unEpisodio = '''
{
  "version": 1,
  "episodios": [
    {
      "titulo": "Il caffè",
      "deQueVa": "Hablan del café.",
      "lineas": [
        { "quien": "giulia", "it": "Come stai?", "es": "¿Cómo estás?" },
        { "quien": "lorenzo", "it": "Sto bene.", "es": "Estoy bien." }
      ]
    }
  ]
}
''';

RepositorioPodcast _repositorioCon(String json) =>
    RepositorioPodcast(leerAsset: (_) async => json);

Future<VozFalsa> _abrir(
  WidgetTester tester, {
  String json = _unEpisodio,
  bool hayItaliano = true,
  int cuantasVoces = 2,
}) async {
  final voz = VozFalsa(hayItaliano: hayItaliano, cuantasVoces: cuantasVoces);
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: PantallaPodcast(repositorio: _repositorioCon(json), voz: voz),
    ),
  ));
  await tester.pumpAndSettle();
  return voz;
}

void main() {
  group('leer los episodios', () {
    test('el episodio de verdad que viaja en la app se lee entero', () async {
      // Es el archivo real, no uno de mentira: si alguien le rompe una coma
      // al JSON, o escribe mal un nombre, esto lo dice acá y no en el celular.
      final podcast = Podcast.desdeJson(
        jsonDecode(await _leerElArchivoDeVerdad()),
      );

      expect(podcast.episodios, isNotEmpty);
      final primero = podcast.episodios.first;
      expect(primero.titulo, isNotEmpty);
      expect(primero.lineas.length, greaterThan(10));
    });

    test('todas las líneas tienen las dos cosas', () async {
      final podcast = Podcast.desdeJson(
        jsonDecode(await _leerElArchivoDeVerdad()),
      );

      for (final linea in podcast.episodios.first.lineas) {
        expect(linea.italiano.trim(), isNotEmpty);
        expect(linea.castellano.trim(), isNotEmpty,
            reason: 'sin traducción no sirve: "${linea.italiano}"');
      }
    });

    test('los dos hablan: no es un monólogo', () async {
      // Que se turnen es la idea entera de la sección. Un episodio con una
      // sola voz sería un cuento leído, que ya existe.
      final lineas = Podcast.desdeJson(
        jsonDecode(await _leerElArchivoDeVerdad()),
      ).episodios.first.lineas;

      expect(lineas.any((l) => l.quien == QuienHabla.giulia), isTrue);
      expect(lineas.any((l) => l.quien == QuienHabla.lorenzo), isTrue);
    });

    test('un renglón roto no tira abajo el episodio', () {
      final podcast = Podcast.desdeJson(jsonDecode('''
        {"episodios": [{"titulo": "T", "deQueVa": "D", "lineas": [
          {"quien": "giulia", "it": "Ciao", "es": "Hola"},
          {"quien": "nadie", "it": "x", "es": "y"},
          {"quien": "lorenzo", "it": "Ciao", "es": "Hola"}
        ]}]}
      '''));

      expect(podcast.episodios.first.lineas.length, 2);
    });

    test('un episodio sin líneas no aparece', () {
      final podcast = Podcast.desdeJson(jsonDecode('''
        {"episodios": [{"titulo": "T", "deQueVa": "D", "lineas": []}]}
      '''));

      expect(podcast.episodios, isEmpty);
    });

    test('un archivo que no se puede leer no rompe la app', () async {
      final repositorio = RepositorioPodcast(
        leerAsset: (_) async => throw Exception('no está'),
      );

      expect((await repositorio.cargar()).episodios, isEmpty);
    });
  });

  group('la pantalla', () {
    testWidgets('muestra el título y las frases', (tester) async {
      await _abrir(tester);

      expect(find.text('Il caffè'), findsOneWidget);
      expect(find.text('Come stai?'), findsOneWidget);
      expect(find.text('Sto bene.'), findsOneWidget);
    });

    testWidgets('la traducción no está a la vista hasta que se pide',
        (tester) async {
      await _abrir(tester);

      expect(find.text('¿Cómo estás?'), findsNothing);

      await tester.longPress(find.text('Come stai?'));
      await tester.pumpAndSettle();

      expect(find.text('¿Cómo estás?'), findsOneWidget);
    });

    testWidgets('al escuchar, Giulia y Lorenzo se turnan de verdad',
        (tester) async {
      // Es lo que distingue esto de un cuento leído: que cada turno suene con
      // la voz de quien habla.
      final voz = await _abrir(tester);

      await tester.tap(find.text('Escuchar'));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(voz.dicho, ['Come stai?', 'Sto bene.']);
      expect(voz.conQueVoz, ['Giulia', 'Lorenzo']);
    });

    testWidgets('con una sola voz instalada igual se escucha', (tester) async {
      // Se pierde el ida y vuelta, pero el episodio se escucha. Callarse
      // sería peor.
      final voz = await _abrir(tester, cuantasVoces: 1);

      await tester.tap(find.text('Escuchar'));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(voz.dicho, ['Come stai?', 'Sto bene.']);
    });

    testWidgets('sin la voz italiana avisa y no habla', (tester) async {
      // La voz de mentira revienta si se la hace hablar sin italiano, así que
      // si esto pasa es porque de verdad no habló.
      await _abrir(tester, hayItaliano: false);

      expect(find.textContaining('no tiene la voz italiana'), findsOneWidget);
      expect(find.text('Escuchar'), findsNothing);
    });

    testWidgets('sin voz italiana igual se puede leer y traducir',
        (tester) async {
      await _abrir(tester, hayItaliano: false);

      await tester.longPress(find.text('Come stai?'));
      await tester.pumpAndSettle();

      expect(find.text('¿Cómo estás?'), findsOneWidget);
    });

    testWidgets('lo lento se puede pedir', (tester) async {
      final voz = await _abrir(tester);

      await tester.tap(find.text('Lento'));
      await tester.pumpAndSettle();

      expect(voz.lenta, isTrue);
    });

    testWidgets('sin episodios lo dice en vez de quedarse en blanco',
        (tester) async {
      await _abrir(tester, json: '{"episodios": []}');

      expect(find.textContaining('Todavía no hay episodios'), findsOneWidget);
    });
  });
}

/// El podcast.json de verdad, leído del disco.
///
/// No se usa rootBundle porque en los tests no está empaquetado: se lee el
/// archivo tal como está en el repositorio, que es lo que se quiere revisar.
Future<String> _leerElArchivoDeVerdad() async {
  // El test corre desde flutter_app/, así que la ruta es relativa a ahí.
  return await File('assets/podcast.json').readAsString();
}
