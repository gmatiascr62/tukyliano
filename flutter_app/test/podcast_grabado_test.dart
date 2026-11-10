import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tukyliano/datos/repositorio_podcast.dart';
import 'package:tukyliano/modelos/episodio.dart';
import 'package:tukyliano/pantallas/pantalla_podcast.dart';

import 'reproductor_falso.dart';
import 'voz_falsa.dart';

/// Un episodio con audio grabado: archivo y, por frase, el segundo en que
/// arranca.
const _grabado = '''
{
  "version": 3,
  "episodios": [
    {
      "titulo": "Il caffè",
      "deQueVa": "Hablan del café.",
      "audio": "caffe.mp3",
      "lineas": [
        { "quien": "giulia", "it": "Come stai?", "es": "¿Cómo estás?", "t": 0 },
        { "quien": "lorenzo", "it": "Molto bene.", "es": "Muy bien.", "t": 2.5 },
        { "quien": "giulia", "it": "Io ho sonno.", "es": "Tengo sueño.", "t": 6.25 }
      ]
    }
  ]
}
''';

/// El mismo, pero a una frase le falta el momento de arranque.
const _aMedias = '''
{
  "version": 3,
  "episodios": [
    {
      "titulo": "Il caffè",
      "deQueVa": "Hablan del café.",
      "audio": "caffe.mp3",
      "lineas": [
        { "quien": "giulia", "it": "Come stai?", "es": "¿Cómo estás?", "t": 0 },
        { "quien": "lorenzo", "it": "Molto bene.", "es": "Muy bien." }
      ]
    }
  ]
}
''';

Future<ReproductorFalso> _abrir(
  WidgetTester tester, {
  String json = _grabado,
  bool hayArchivo = true,
  bool hayItaliano = true,
}) async {
  final reproductor = ReproductorFalso(hayArchivo: hayArchivo);
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: PantallaPodcast(
        repositorio: RepositorioPodcast(leerAsset: (_) async => json),
        voz: VozFalsa(hayItaliano: hayItaliano),
        reproductor: reproductor,
      ),
    ),
  ));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Il caffè'));
  await tester.pumpAndSettle();
  return reproductor;
}

Episodio _episodio(String json) =>
    Podcast.desdeJson(jsonDecode(json)).episodios.first;

void main() {
  group('el modelo', () {
    test('un episodio sin audio no está grabado', () {
      final episodio = _episodio(_grabado.replaceAll('"audio": "caffe.mp3",', ''));
      expect(episodio.grabado, isFalse);
    });

    test('si a una frase le falta el tiempo, el episodio no está grabado', () {
      // Es a propósito: con una sola frase sin tiempo, de ahí en adelante se
      // marcaría la frase equivocada. Mejor hablarlo entero con el motor de
      // voz que mostrarlo mal.
      expect(_episodio(_aMedias).grabado, isFalse);
    });

    test('con archivo y todos los tiempos, está grabado', () {
      expect(_episodio(_grabado).grabado, isTrue);
    });

    test('los tiempos se leen en milisegundos', () {
      final lineas = _episodio(_grabado).lineas;
      expect(lineas[0].desde, Duration.zero);
      expect(lineas[1].desde, const Duration(milliseconds: 2500));
      expect(lineas[2].desde, const Duration(milliseconds: 6250));
    });

    test('cuál suena en cada momento', () {
      final episodio = _episodio(_grabado);
      expect(episodio.cualSuena(Duration.zero), 0);
      expect(episodio.cualSuena(const Duration(milliseconds: 2499)), 0);
      // Justo en el borde ya es la siguiente.
      expect(episodio.cualSuena(const Duration(milliseconds: 2500)), 1);
      expect(episodio.cualSuena(const Duration(seconds: 5)), 1);
      expect(episodio.cualSuena(const Duration(seconds: 30)), 2);
    });
  });

  group('la pantalla con audio grabado', () {
    testWidgets('abre el archivo del episodio', (tester) async {
      final reproductor = await _abrir(tester);
      expect(reproductor.cargado, 'caffe.mp3');
    });

    testWidgets('el botón reproduce y pausa el archivo', (tester) async {
      final reproductor = await _abrir(tester);

      await tester.tap(find.text('Escuchar'));
      await tester.pumpAndSettle();
      expect(reproductor.andando, isTrue);

      await tester.tap(find.text('Parar'));
      await tester.pumpAndSettle();
      expect(reproductor.andando, isFalse);
    });

    testWidgets('marca la frase según el segundo en que va', (tester) async {
      final reproductor = await _abrir(tester);
      await tester.tap(find.text('Escuchar'));
      await tester.pumpAndSettle();

      Color? fondoDe(String frase) {
        final caja = tester.widget<Container>(find.ancestor(
          of: find.textContaining(frase),
          matching: find.byType(Container),
        ).first);
        return (caja.color);
      }

      reproductor.correrA(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(fondoDe('Come stai?'), isNotNull, reason: 'la primera suena');
      expect(fondoDe('Molto bene.'), isNull);

      reproductor.correrA(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(fondoDe('Come stai?'), isNull, reason: 'la primera ya pasó');
      expect(fondoDe('Molto bene.'), isNotNull);
    });

    testWidgets('tocar una frase salta a ese segundo', (tester) async {
      final reproductor = await _abrir(tester);

      await tester.tap(find.textContaining('Io ho sonno.'));
      await tester.pumpAndSettle();

      expect(reproductor.donde, const Duration(milliseconds: 6250));
      expect(reproductor.andando, isTrue,
          reason: 'saltar a una frase sigue escuchando desde ahí');
    });

    testWidgets('el principio vuelve a cero sin reproducir', (tester) async {
      final reproductor = await _abrir(tester);
      await tester.tap(find.textContaining('Io ho sonno.'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Parar'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.replay));
      await tester.pumpAndSettle();

      expect(reproductor.donde, Duration.zero);
      expect(reproductor.andando, isFalse);
    });

    testWidgets('lento va al reproductor, no al motor de voz', (tester) async {
      final reproductor = await _abrir(tester);
      await tester.tap(find.text('Lento'));
      await tester.pumpAndSettle();
      expect(reproductor.lenta, isTrue);
    });

    testWidgets('al terminar vuelve a estar listo desde el principio',
        (tester) async {
      final reproductor = await _abrir(tester);
      await tester.tap(find.text('Escuchar'));
      await tester.pumpAndSettle();

      reproductor.terminar();
      await tester.pumpAndSettle();

      expect(find.text('Escuchar'), findsOneWidget,
          reason: 'no "Seguir": terminado no hay nada que retomar');
    });

    testWidgets('sin la voz italiana el episodio grabado se escucha igual',
        (tester) async {
      // Este es el punto del audio grabado: no depende de lo que tenga
      // instalado el celular.
      await _abrir(tester, hayItaliano: false);
      expect(find.text('Escuchar'), findsOneWidget);
      expect(find.textContaining('no tiene la voz italiana'), findsNothing);
    });

    testWidgets('si falta el archivo, cae al motor de voz', (tester) async {
      final reproductor = await _abrir(tester, hayArchivo: false);
      expect(reproductor.cargado, isNull);
      // El motor de voz sigue estando, así que el episodio se escucha igual.
      expect(find.text('Escuchar'), findsOneWidget);
    });
  });
}
