import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tukyliano/datos/repositorio_preposizioni.dart';
import 'package:tukyliano/pantallas/pantalla_preposizioni.dart';
import 'package:tukyliano/tema.dart';

import 'util_pantalla.dart';

/// Una sola frase, así la pregunta es siempre la misma y se puede afirmar
/// cuál es la respuesta.
const _soloCitta = '''
  {
    "version": 1,
    "frases": [
      {"frase": "Vado ___ città", "correcta": "in", "es": "voy a la ciudad",
       "opciones": ["a", "in", "alla", "nella"],
       "explicacion": "«in città» es fija: el italiano se come el artículo."}
    ]
  }
''';

/// Una donde la respuesta es una contracción, para la cuenta.
const _soloBorsa = '''
  {
    "version": 1,
    "frases": [
      {"frase": "La chiave è ___ borsa", "correcta": "nella",
       "es": "la llave está en la cartera",
       "opciones": ["in", "nella", "sulla", "alla"],
       "explicacion": "Adentro de una cosa concreta sí lleva artículo."}
    ]
  }
''';

/// Una con "per", que no se contrae y por eso ocupa dos palabras.
const _soloRegalo = '''
  {
    "version": 1,
    "frases": [
      {"frase": "Il regalo è ___ nonna", "correcta": "per la",
       "es": "el regalo es para la abuela",
       "opciones": ["per la", "perla", "per", "alla"],
       "explicacion": "«per» no se pega nunca con el artículo."}
    ]
  }
''';

RepositorioPreposizioni _repo(String json) => RepositorioPreposizioni(
      leerAsset: (_) async => json,
      cliente: MockClient((_) async => http.Response('', 404)),
      carpeta: () async => null,
    );

Future<void> _abrir(WidgetTester tester, String json) async {
  usarPantallaDeCelular(tester);
  await tester.pumpWidget(MaterialApp(
    theme: Tema.datos,
    home: Scaffold(body: PantallaPreposizioni(repositorio: _repo(json))),
  ));
  await tester.pumpAndSettle();
}

Future<void> _tocar(WidgetTester tester, String texto) async {
  await tester.tap(find.text(texto));
  await tester.pumpAndSettle();
}

/// La frase se dibuja en trozos (para pintar el hueco de otro color), así que
/// hay que juntarlos para leerla entera.
String _fraseEnPantalla(WidgetTester tester) {
  final rico = tester.widget<Text>(
    find.byWidgetPredicate((w) => w is Text && w.textSpan != null).first,
  );
  return rico.textSpan!.toPlainText();
}

void main() {
  testWidgets('muestra la frase con el hueco y la traducción', (tester) async {
    await _abrir(tester, _soloCitta);

    expect(_fraseEnPantalla(tester), 'Vado ___ città');
    expect(find.text('voy a la ciudad'), findsOneWidget);
    expect(find.text('Puntaje: 0/0'), findsOneWidget);
  });

  testWidgets('ofrece los cuatro botones del JSON', (tester) async {
    await _abrir(tester, _soloCitta);

    for (final opcion in ['a', 'in', 'alla', 'nella']) {
      expect(find.text(opcion), findsOneWidget);
    }
  });

  testWidgets('tocar una opción la mete en el hueco', (tester) async {
    await _abrir(tester, _soloCitta);

    await _tocar(tester, 'alla');

    expect(_fraseEnPantalla(tester), 'Vado alla città');
  });

  testWidgets('sin elegir nada no se puede verificar', (tester) async {
    await _abrir(tester, _soloCitta);

    final boton = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Verificar'),
    );
    expect(boton.onPressed, isNull);
  });

  testWidgets('se puede cambiar de opción antes de verificar', (tester) async {
    await _abrir(tester, _soloCitta);

    await _tocar(tester, 'alla');
    await _tocar(tester, 'nella');

    expect(_fraseEnPantalla(tester), 'Vado nella città');
  });

  group('al verificar', () {
    testWidgets('acertar suma y muestra la explicación', (tester) async {
      await _abrir(tester, _soloCitta);

      await _tocar(tester, 'in');
      await _tocar(tester, 'Verificar');

      expect(find.text('¡Correcto!'), findsOneWidget);
      expect(find.text('Puntaje: 1/1'), findsOneWidget);
      expect(find.textContaining('se come el artículo'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Siguiente'), findsOneWidget);
    });

    testWidgets('errar muestra la frase entera bien contestada',
        (tester) async {
      await _abrir(tester, _soloCitta);

      await _tocar(tester, 'alla');
      await _tocar(tester, 'Verificar');

      expect(find.text('Va: Vado in città'), findsOneWidget);
      expect(find.text('Puntaje: 0/1'), findsOneWidget);
      expect(find.text('¡Correcto!'), findsNothing);
    });

    testWidgets('ya no se puede cambiar la respuesta', (tester) async {
      await _abrir(tester, _soloCitta);

      await _tocar(tester, 'alla');
      await _tocar(tester, 'Verificar');
      await _tocar(tester, 'in');

      // Sigue mostrando lo que se contestó, no lo último que se tocó.
      expect(_fraseEnPantalla(tester), 'Vado alla città');
      expect(find.text('Puntaje: 0/1'), findsOneWidget);
    });

    testWidgets('Siguiente limpia el hueco y mantiene el puntaje',
        (tester) async {
      await _abrir(tester, _soloCitta);

      await _tocar(tester, 'in');
      await _tocar(tester, 'Verificar');
      await _tocar(tester, 'Siguiente');

      expect(_fraseEnPantalla(tester), 'Vado ___ città');
      expect(find.text('¡Correcto!'), findsNothing);
      expect(find.text('Puntaje: 1/1'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Verificar'), findsOneWidget);
    });
  });

  testWidgets('con una contracción muestra la cuenta', (tester) async {
    await _abrir(tester, _soloBorsa);

    await _tocar(tester, 'nella');
    await _tocar(tester, 'Verificar');

    expect(find.text('in + la = nella'), findsOneWidget);
  });

  testWidgets('sin contracción no muestra ninguna cuenta', (tester) async {
    await _abrir(tester, _soloCitta);

    await _tocar(tester, 'in');
    await _tocar(tester, 'Verificar');

    // "in" es la preposición sola: no hay nada que sumar.
    expect(find.textContaining(' = '), findsNothing);
  });

  testWidgets('una respuesta de dos palabras entra igual', (tester) async {
    // "per la" no se contrae, así que el botón tiene dos palabras.
    await _abrir(tester, _soloRegalo);

    await _tocar(tester, 'per la');
    await _tocar(tester, 'Verificar');

    expect(_fraseEnPantalla(tester), 'Il regalo è per la nonna');
    expect(find.text('¡Correcto!'), findsOneWidget);
    // Tampoco hay cuenta: justamente porque no se pega.
    expect(find.textContaining(' = '), findsNothing);
  });

  testWidgets('la explicación no queda tapada por el botón', (tester) async {
    await _abrir(tester, _soloBorsa);

    await _tocar(tester, 'in');
    await _tocar(tester, 'Verificar');

    final explicacion = tester.getRect(find.textContaining('cosa concreta'));
    final boton =
        tester.getRect(find.widgetWithText(ElevatedButton, 'Siguiente'));

    expect(explicacion.bottom, lessThanOrEqualTo(boton.top),
        reason: 'la explicación se solapa con el botón');
  });

  testWidgets('sin frases cargadas lo avisa', (tester) async {
    await _abrir(tester, '{"version": 1, "frases": []}');

    expect(find.textContaining('Todavía no hay frases'), findsOneWidget);
  });

  testWidgets('un JSON roto no rompe la pantalla', (tester) async {
    await _abrir(tester, 'esto no es JSON');

    expect(find.textContaining('Todavía no hay frases'), findsOneWidget);
  });
}
