import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tukyliano/datos/repositorio_racconti.dart';
import 'package:tukyliano/pantallas/pantalla_racconti.dart';
import 'package:tukyliano/tema.dart';

import 'util_pantalla.dart';

const _dos = '''
  {
    "version": 1,
    "racconti": [
      {
        "id": "la-colazione", "titulo": "La colazione",
        "titulo_es": "El desayuno", "nivel": 1,
        "vocabulario": [{"it": "presto", "es": "temprano"}],
        "lineas": [
          {"it": "Marco è in cucina.", "es": "Marco está en la cocina."},
          {"it": "È mattina presto.", "es": "Es temprano a la mañana."},
          {"it": "Marco ha fame.", "es": "Marco tiene hambre."}
        ]
      },
      {
        "id": "il-lavoro", "titulo": "Il lavoro", "titulo_es": "El trabajo",
        "nivel": 3,
        "vocabulario": [],
        "lineas": [{"it": "Marco lavora.", "es": "Marco trabaja."}]
      }
    ]
  }
''';

RepositorioRacconti _repo(String json) => RepositorioRacconti(
      leerAsset: (_) async => json,
      cliente: MockClient((_) async => http.Response('', 404)),
      carpeta: () async => null,
    );

Future<void> _abrir(WidgetTester tester, String json) async {
  usarPantallaDeCelular(tester);
  await tester.pumpWidget(MaterialApp(
    theme: Tema.datos,
    home: Scaffold(body: PantallaRacconti(repositorio: _repo(json))),
  ));
  await tester.pumpAndSettle();
}

Future<void> _tocar(WidgetTester tester, String texto) async {
  await tester.tap(find.text(texto));
  await tester.pumpAndSettle();
}

void main() {
  group('la lista', () {
    testWidgets('muestra los cuentos con su título en los dos idiomas',
        (tester) async {
      await _abrir(tester, _dos);

      expect(find.text('La colazione'), findsOneWidget);
      expect(find.text('El desayuno'), findsOneWidget);
      expect(find.text('Il lavoro'), findsOneWidget);
    });

    testWidgets('muestra el nivel y cuántas frases tiene', (tester) async {
      await _abrir(tester, _dos);

      expect(find.text('Nivel 1'), findsOneWidget);
      expect(find.text('3 frases'), findsOneWidget);
    });

    testWidgets('sin cuentos cargados lo avisa', (tester) async {
      await _abrir(tester, '{"version": 1, "racconti": []}');

      expect(find.textContaining('Todavía no hay cuentos'), findsOneWidget);
    });

    testWidgets('un JSON roto no rompe la pantalla', (tester) async {
      await _abrir(tester, 'esto no es JSON');

      expect(find.textContaining('Todavía no hay cuentos'), findsOneWidget);
    });
  });

  group('el cuento abierto', () {
    testWidgets('muestra los renglones en italiano, sin traducción',
        (tester) async {
      await _abrir(tester, _dos);
      await _tocar(tester, 'La colazione');

      expect(find.text('Marco è in cucina.'), findsOneWidget);
      expect(find.text('Marco está en la cocina.'), findsNothing);
      // El otro cuento ya no está.
      expect(find.text('Il lavoro'), findsNothing);
    });

    testWidgets('tocar un renglón revela su traducción', (tester) async {
      await _abrir(tester, _dos);
      await _tocar(tester, 'La colazione');
      await _tocar(tester, 'Marco è in cucina.');

      expect(find.text('Marco está en la cocina.'), findsOneWidget);
      // Solo la del renglón tocado.
      expect(find.text('Marco tiene hambre.'), findsNothing);
    });

    testWidgets('tocarlo de nuevo la esconde', (tester) async {
      await _abrir(tester, _dos);
      await _tocar(tester, 'La colazione');
      await _tocar(tester, 'Marco è in cucina.');
      await _tocar(tester, 'Marco è in cucina.');

      expect(find.text('Marco está en la cocina.'), findsNothing);
    });

    testWidgets('Mostrar todo revela todos y después los esconde',
        (tester) async {
      await _abrir(tester, _dos);
      await _tocar(tester, 'La colazione');

      await _tocar(tester, 'Mostrar todo');
      expect(find.text('Marco está en la cocina.'), findsOneWidget);
      expect(find.text('Marco tiene hambre.'), findsOneWidget);

      await _tocar(tester, 'Ocultar todo');
      expect(find.text('Marco está en la cocina.'), findsNothing);
    });

    testWidgets('el vocabulario arranca plegado y se abre al tocarlo',
        (tester) async {
      await _abrir(tester, _dos);
      await _tocar(tester, 'La colazione');

      expect(find.text('Vocabulario (1)'), findsOneWidget);
      expect(find.text('temprano'), findsNothing);

      await _tocar(tester, 'Vocabulario (1)');
      expect(find.text('presto'), findsOneWidget);
      expect(find.text('temprano'), findsOneWidget);
    });

    testWidgets('un cuento sin vocabulario no muestra la sección',
        (tester) async {
      await _abrir(tester, _dos);
      await _tocar(tester, 'Il lavoro');

      expect(find.textContaining('Vocabulario'), findsNothing);
    });

    testWidgets('la flecha vuelve a la lista', (tester) async {
      await _abrir(tester, _dos);
      await _tocar(tester, 'La colazione');

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(find.text('Il lavoro'), findsOneWidget);
      expect(find.text('Marco è in cucina.'), findsNothing);
    });

    testWidgets('al reabrirlo los renglones vuelven a estar tapados',
        (tester) async {
      await _abrir(tester, _dos);
      await _tocar(tester, 'La colazione');
      await _tocar(tester, 'Marco è in cucina.');

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      await _tocar(tester, 'La colazione');

      expect(find.text('Marco está en la cocina.'), findsNothing);
    });
  });

  testWidgets('los cuentos salen ordenados por nivel', (tester) async {
    await _abrir(tester, _dos);

    final facil = tester.getRect(find.text('La colazione'));
    final dificil = tester.getRect(find.text('Il lavoro'));
    expect(facil.top, lessThan(dificil.top));
  });
}
