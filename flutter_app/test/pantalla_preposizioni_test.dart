import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tukyliano/datos/repositorio_preposizioni.dart';
import 'package:tukyliano/pantallas/pantalla_preposizioni.dart';
import 'package:tukyliano/logica/preposiciones.dart';
import 'package:tukyliano/tema.dart';
import 'package:tukyliano/widgets/boton_opcion.dart';
import 'package:tukyliano/widgets/pastilla.dart';

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

/// Tres frases, una de cada preposición, para probar los botones de arriba.
const _tresPreposiciones = '''
  {
    "version": 1,
    "frases": [
      {"frase": "Vado ___ città", "correcta": "in", "es": "voy a la ciudad",
       "opciones": ["a", "in", "alla", "nella"],
       "explicacion": "«in città» es fija."},
      {"frase": "Il regalo è ___ nonna", "correcta": "per la",
       "es": "el regalo es para la abuela",
       "opciones": ["per la", "perla", "per", "alla"],
       "explicacion": "«per» no se pega nunca con el artículo."},
      {"frase": "Il libro è ___ tavolo", "correcta": "sul",
       "es": "el libro está sobre la mesa",
       "opciones": ["sul", "nel", "al", "sullo"],
       "explicacion": "su + il = sul."}
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

/// Toca un botón de respuesta. Va por el widget y no por el texto porque las
/// pastillas de arriba dicen lo mismo: "in" es a la vez una preposición que se
/// puede apagar y una de las opciones para contestar.
Future<void> _tocar(WidgetTester tester, String texto) async {
  await tester.tap(find.widgetWithText(BotonOpcion, texto));
  await tester.pumpAndSettle();
}

/// Toca uno de los botones grandes de abajo (Verificar, Siguiente).
Future<void> _tocarBoton(WidgetTester tester, String texto) async {
  await tester.tap(find.widgetWithText(ElevatedButton, texto));
  await tester.pumpAndSettle();
}

/// Prende o apaga una preposición de las de arriba.
Future<void> _tocarPastilla(WidgetTester tester, String texto) async {
  await tester.tap(find.widgetWithText(Pastilla, texto));
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
      expect(find.widgetWithText(BotonOpcion, opcion), findsOneWidget);
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
      await _tocarBoton(tester, 'Verificar');

      expect(find.text('¡Correcto!'), findsOneWidget);
      expect(find.text('Puntaje: 1/1'), findsOneWidget);
      expect(find.textContaining('se come el artículo'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Siguiente'), findsOneWidget);
    });

    testWidgets('errar muestra la frase entera bien contestada',
        (tester) async {
      await _abrir(tester, _soloCitta);

      await _tocar(tester, 'alla');
      await _tocarBoton(tester, 'Verificar');

      expect(find.text('Va: Vado in città'), findsOneWidget);
      expect(find.text('Puntaje: 0/1'), findsOneWidget);
      expect(find.text('¡Correcto!'), findsNothing);
    });

    testWidgets('ya no se puede cambiar la respuesta', (tester) async {
      await _abrir(tester, _soloCitta);

      await _tocar(tester, 'alla');
      await _tocarBoton(tester, 'Verificar');
      await _tocar(tester, 'in');

      // Sigue mostrando lo que se contestó, no lo último que se tocó.
      expect(_fraseEnPantalla(tester), 'Vado alla città');
      expect(find.text('Puntaje: 0/1'), findsOneWidget);
    });

    testWidgets('Siguiente limpia el hueco y mantiene el puntaje',
        (tester) async {
      await _abrir(tester, _soloCitta);

      await _tocar(tester, 'in');
      await _tocarBoton(tester, 'Verificar');
      await _tocarBoton(tester, 'Siguiente');

      expect(_fraseEnPantalla(tester), 'Vado ___ città');
      expect(find.text('¡Correcto!'), findsNothing);
      expect(find.text('Puntaje: 1/1'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Verificar'), findsOneWidget);
    });
  });

  testWidgets('con una contracción muestra la cuenta', (tester) async {
    await _abrir(tester, _soloBorsa);

    await _tocar(tester, 'nella');
    await _tocarBoton(tester, 'Verificar');

    expect(find.text('in + la = nella'), findsOneWidget);
  });

  testWidgets('sin contracción no muestra ninguna cuenta', (tester) async {
    await _abrir(tester, _soloCitta);

    await _tocar(tester, 'in');
    await _tocarBoton(tester, 'Verificar');

    // "in" es la preposición sola: no hay nada que sumar.
    expect(find.textContaining(' = '), findsNothing);
  });

  testWidgets('una respuesta de dos palabras entra igual', (tester) async {
    // "per la" no se contrae, así que el botón tiene dos palabras.
    await _abrir(tester, _soloRegalo);

    await _tocar(tester, 'per la');
    await _tocarBoton(tester, 'Verificar');

    expect(_fraseEnPantalla(tester), 'Il regalo è per la nonna');
    expect(find.text('¡Correcto!'), findsOneWidget);
    // Tampoco hay cuenta: justamente porque no se pega.
    expect(find.textContaining(' = '), findsNothing);
  });

  testWidgets('la explicación no queda tapada por el botón', (tester) async {
    await _abrir(tester, _soloBorsa);

    await _tocar(tester, 'in');
    await _tocarBoton(tester, 'Verificar');

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

  group('elegir con cuáles practicar', () {
    testWidgets('arrancan las siete prendidas', (tester) async {
      await _abrir(tester, _tresPreposiciones);

      for (final p in preposicionesSimples) {
        expect(find.widgetWithText(Pastilla, p), findsOneWidget, reason: p);
      }
      expect(find.widgetWithText(Pastilla, 'Todas'), findsOneWidget);
    });

    testWidgets('apagar una la saca de la práctica', (tester) async {
      await _abrir(tester, _tresPreposiciones);

      // Quedan solo las frases de per: las otras dos preposiciones apagadas.
      for (final p in preposicionesSimples) {
        if (p != 'per') await _tocarPastilla(tester, p);
      }

      for (var i = 0; i < 4; i++) {
        expect(_fraseEnPantalla(tester), 'Il regalo è ___ nonna');
        await _tocar(tester, 'per la');
        await _tocarBoton(tester, 'Verificar');
        await _tocarBoton(tester, 'Siguiente');
      }
    });

    testWidgets('se pueden dejar dos prendidas', (tester) async {
      await _abrir(tester, _tresPreposiciones);

      // Solo in y su: la frase de per no tiene que salir nunca.
      for (final p in preposicionesSimples) {
        if (p != 'in' && p != 'su') await _tocarPastilla(tester, p);
      }

      for (var i = 0; i < 6; i++) {
        expect(
          _fraseEnPantalla(tester),
          anyOf('Vado ___ città', 'Il libro è ___ tavolo'),
        );
        await _tocar(tester, _opcionCorrecta(tester));
        await _tocarBoton(tester, 'Verificar');
        await _tocarBoton(tester, 'Siguiente');
      }
    });

    testWidgets('la última prendida no se puede apagar', (tester) async {
      await _abrir(tester, _tresPreposiciones);

      for (final p in preposicionesSimples) {
        await _tocarPastilla(tester, p);
      }

      // Alguna quedó prendida: sin ninguna no habría nada que practicar.
      final prendidas = tester
          .widgetList<Pastilla>(find.byType(Pastilla))
          .where((p) => p.activa && p.texto != 'Todas');
      expect(prendidas.length, 1);
    });

    testWidgets('con una preposición sin frases lo dice', (tester) async {
      // El JSON de prueba solo tiene in, per y su: si se practica una de las
      // otras, el hueco es de la selección y no de los datos.
      await _abrir(tester, _tresPreposiciones);
      for (final p in preposicionesSimples) {
        if (p != 'di') await _tocarPastilla(tester, p);
      }

      expect(find.text('No hay frases para lo que elegiste arriba.'),
          findsOneWidget);
      // Y se puede volver sin salir de la sección.
      await _tocarPastilla(tester, 'Todas');
      expect(find.textContaining('No hay frases'), findsNothing);
    });

    testWidgets('Todas las vuelve a prender', (tester) async {
      await _abrir(tester, _tresPreposiciones);
      await _tocarPastilla(tester, 'in');
      await _tocarPastilla(tester, 'su');

      await _tocarPastilla(tester, 'Todas');

      final prendidas = tester
          .widgetList<Pastilla>(find.byType(Pastilla))
          .where((p) => p.activa);
      expect(prendidas.length, preposicionesSimples.length + 1);
    });
  });

  group('la explicación', () {
    testWidgets('el botón de info abre la tabla', (tester) async {
      await _abrir(tester, _soloCitta);
      await tester.tap(find.byIcon(Icons.info_outline));
      await tester.pumpAndSettle();

      expect(find.text('Cinco se pegan con el artículo'), findsOneWidget);

      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pumpAndSettle();
      expect(find.text('per y con no se pegan nunca'), findsOneWidget);
    });

    testWidgets('avisa dónde el español dice otra cosa', (tester) async {
      await _abrir(tester, _soloCitta);
      await tester.tap(find.byIcon(Icons.info_outline));
      await tester.pumpAndSettle();

      await tester.drag(find.byType(ListView), const Offset(0, -900));
      await tester.pumpAndSettle();

      expect(find.text('vado in città (voy a la ciudad)'), findsOneWidget);
    });
  });
}

/// El botón que hay que tocar para acertar la frase que está en pantalla.
String _opcionCorrecta(WidgetTester tester) =>
    _fraseEnPantalla(tester).startsWith('Vado') ? 'in' : 'sul';
