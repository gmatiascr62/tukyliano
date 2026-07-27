import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tukyliano/datos/repositorio_frases.dart';
import 'package:tukyliano/ia/gemini.dart';
import 'package:tukyliano/modelos/verbo.dart';
import 'package:tukyliano/pantallas/pantalla_frases.dart';

import 'util_pantalla.dart';

final _verbos = DatosVerbos.desdeJson(jsonDecode('''
  {"verbos": {"essere": {"traduccion": "ser/estar", "tiempos": {
    "presente": {"io": {"italiano": "sono", "espanol": "yo soy/estoy"}}
  }}}}
''') as Map<String, dynamic>);

/// Respuesta con la forma real de la API de Gemini.
String _respuestaGemini(String texto) => jsonEncode({
      'candidates': [
        {
          'content': {
            'parts': [
              {'text': texto}
            ]
          }
        }
      ]
    });

/// Gemini simulado. Distingue generación de corrección por el prompt, así
/// sirve igual aunque el test pida varias frases seguidas.
Gemini _geminiFalso({
  required String generacion,
  String correccion = 'CORRECTO',
  int statusCode = 200,
}) {
  return Gemini(
    cliente: MockClient((request) async {
      if (statusCode != 200) {
        return http.Response('{"error": "clave mala"}', statusCode);
      }
      final esCorreccion = request.body.contains('Respuesta del alumno');
      return http.Response(
        _respuestaGemini(esCorreccion ? correccion : generacion),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }),
  );
}

/// Repositorio con las frases que le pasemos. Sin argumento queda vacío, que
/// es lo que necesita la mayoría de los tests: obliga a pasar por la IA.
RepositorioFrases _frasesLocales([String json = '{"frases": []}']) =>
    RepositorioFrases(leerAsset: (_) async => json);

Widget _app(
  Gemini gemini, {
  VoidCallback? onClaveInvalida,
  RepositorioFrases? frasesLocales,
}) =>
    MaterialApp(
      home: Scaffold(
        body: PantallaFrases(
          verbos: _verbos.verbos.values.toList(),
          tiempos: const ['presente'],
          apiKey: 'FAKE',
          gemini: gemini,
          frasesLocales: frasesLocales ?? _frasesLocales(),
          onClaveInvalida: onClaveInvalida ?? () {},
        ),
      ),
    );

Future<void> _escribir(WidgetTester tester, String palabra) async {
  for (final letra in palabra.split('')) {
    await tester.tap(find.widgetWithText(ElevatedButton, letra));
    await tester.pump();
  }
}

const _fraseOk = '{"espanol": "Hoy soy feliz", "italiano": "Oggi sono felice", '
    '"pista": "feliz = felice"}';

void main() {
  testWidgets('muestra la frase generada en español', (tester) async {
    usarPantallaDeCelular(tester);
    await tester.pumpWidget(_app(_geminiFalso(generacion: _fraseOk)));
    await tester.pumpAndSettle();

    expect(find.textContaining('Hoy soy feliz'), findsOneWidget);
    expect(find.text('Escribí la traducción...'), findsOneWidget);
  });

  testWidgets('una respuesta correcta muestra ¡Correcto!', (tester) async {
    usarPantallaDeCelular(tester);
    await tester.pumpWidget(_app(_geminiFalso(generacion: _fraseOk)));
    await tester.pumpAndSettle();

    await _escribir(tester, 'oggi');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Verificar'));
    await tester.pumpAndSettle();

    expect(find.text('¡Correcto!'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Siguiente'), findsOneWidget);
  });

  testWidgets('una respuesta incorrecta muestra solo la frase correcta',
      (tester) async {
    usarPantallaDeCelular(tester);
    await tester.pumpWidget(
      _app(_geminiFalso(generacion: _fraseOk, correccion: 'INCORRECTO')),
    );
    await tester.pumpAndSettle();

    await _escribir(tester, 'oggi');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Verificar'));
    await tester.pumpAndSettle();

    // Sin el "Incorrecto. Era:", solo la referencia.
    expect(find.text('Oggi sono felice'), findsOneWidget);
    expect(find.textContaining('Incorrecto. Era'), findsNothing);
  });

  testWidgets('lee el JSON aunque venga envuelto en markdown', (tester) async {
    usarPantallaDeCelular(tester);
    await tester.pumpWidget(_app(_geminiFalso(
      generacion: '```json\n$_fraseOk\n```',
    )));
    await tester.pumpAndSettle();

    expect(find.textContaining('Hoy soy feliz'), findsOneWidget);
  });

  testWidgets('un 403 avisa que la clave es inválida', (tester) async {
    usarPantallaDeCelular(tester);
    var avisado = false;
    await tester.pumpWidget(_app(
      _geminiFalso(generacion: _fraseOk, statusCode: 403),
      onClaveInvalida: () => avisado = true,
    ));
    await tester.pumpAndSettle();

    expect(avisado, isTrue);
  });

  testWidgets('un error de red muestra un mensaje y no rompe', (tester) async {
    usarPantallaDeCelular(tester);
    final gemini = Gemini(
      cliente: MockClient((_) async => http.Response('boom', 500)),
    );
    await tester.pumpWidget(_app(gemini));
    await tester.pumpAndSettle();

    expect(find.textContaining('No se pudo generar la frase'), findsOneWidget);
  });

  group('pista', () {
    testWidgets('arranca escondida y se revela al tocar el botón',
        (tester) async {
      usarPantallaDeCelular(tester);
      await tester.pumpWidget(_app(_geminiFalso(generacion: _fraseOk)));
      await tester.pumpAndSettle();

      expect(find.text('feliz = felice'), findsNothing);

      await tester.tap(find.widgetWithText(TextButton, 'Pista'));
      await tester.pumpAndSettle();

      expect(find.text('feliz = felice'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Pista'), findsNothing);
    });

    testWidgets('no gasta una llamada extra a la IA', (tester) async {
      usarPantallaDeCelular(tester);
      var llamadas = 0;
      final gemini = Gemini(
        cliente: MockClient((_) async {
          llamadas++;
          return http.Response(_respuestaGemini(_fraseOk), 200);
        }),
      );

      await tester.pumpWidget(_app(gemini));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Pista'));
      await tester.pumpAndSettle();

      expect(llamadas, 1);
    });

    testWidgets('si el modelo no manda pista, no aparece el botón',
        (tester) async {
      usarPantallaDeCelular(tester);
      await tester.pumpWidget(_app(_geminiFalso(
        generacion: '{"espanol": "Hoy soy feliz", "italiano": "Oggi sono felice"}',
      )));
      await tester.pumpAndSettle();

      expect(find.textContaining('Hoy soy feliz'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Pista'), findsNothing);
    });

    testWidgets('se esconde de nuevo en la frase siguiente', (tester) async {
      usarPantallaDeCelular(tester);
      await tester.pumpWidget(_app(_geminiFalso(generacion: _fraseOk)));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextButton, 'Pista'));
      await tester.pumpAndSettle();
      expect(find.text('feliz = felice'), findsOneWidget);

      await _escribir(tester, 'oggi');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Verificar'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Siguiente'));
      await tester.pumpAndSettle();

      expect(find.text('feliz = felice'), findsNothing);
    });
  });

  group('frases guardadas', () {
    const guardadas = '''
      {"frases": [
        {"verbo": "essere", "tiempo": "presente", "persona": "io",
         "espanol": "Estoy cansado", "italiano": "Sono stanco",
         "pista": "cansado = stanco"}
      ]}
    ''';

    testWidgets('se usa la guardada y no se llama a la IA', (tester) async {
      usarPantallaDeCelular(tester);
      var llamadas = 0;
      final gemini = Gemini(
        cliente: MockClient((_) async {
          llamadas++;
          return http.Response(_respuestaGemini(_fraseOk), 200);
        }),
      );

      await tester.pumpWidget(
        _app(gemini, frasesLocales: _frasesLocales(guardadas)),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Estoy cansado'), findsOneWidget);
      expect(find.textContaining('Hoy soy feliz'), findsNothing);
      expect(llamadas, 0);
    });

    testWidgets('la guardada también trae pista', (tester) async {
      usarPantallaDeCelular(tester);
      await tester.pumpWidget(_app(
        _geminiFalso(generacion: _fraseOk),
        frasesLocales: _frasesLocales(guardadas),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextButton, 'Pista'));
      await tester.pumpAndSettle();

      expect(find.text('cansado = stanco'), findsOneWidget);
    });

    testWidgets('la corrección sigue yendo a la IA', (tester) async {
      usarPantallaDeCelular(tester);
      await tester.pumpWidget(_app(
        _geminiFalso(generacion: _fraseOk, correccion: 'INCORRECTO'),
        frasesLocales: _frasesLocales(guardadas),
      ));
      await tester.pumpAndSettle();

      await _escribir(tester, 'sono');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Verificar'));
      await tester.pumpAndSettle();

      // Corrige contra el italiano de la frase guardada, no contra el de la IA.
      expect(find.text('Sono stanco'), findsOneWidget);
    });

    testWidgets('si la forma no tiene frase guardada, cae en la IA',
        (tester) async {
      usarPantallaDeCelular(tester);
      // Guardada para otro verbo: para essere/presente/io no hay nada.
      await tester.pumpWidget(_app(
        _geminiFalso(generacion: _fraseOk),
        frasesLocales: _frasesLocales('''
          {"frases": [
            {"verbo": "avere", "tiempo": "presente", "persona": "io",
             "espanol": "Tengo hambre", "italiano": "Ho fame", "pista": ""}
          ]}
        '''),
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('Hoy soy feliz'), findsOneWidget);
    });

    testWidgets('un asset roto no rompe la pantalla', (tester) async {
      usarPantallaDeCelular(tester);
      await tester.pumpWidget(_app(
        _geminiFalso(generacion: _fraseOk),
        frasesLocales: _frasesLocales('esto no es JSON'),
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('Hoy soy feliz'), findsOneWidget);
    });
  });

  testWidgets('verificar con el campo vacío no llama a la IA', (tester) async {
    usarPantallaDeCelular(tester);
    var llamadas = 0;
    final gemini = Gemini(
      cliente: MockClient((_) async {
        llamadas++;
        return http.Response(_respuestaGemini(_fraseOk), 200);
      }),
    );

    await tester.pumpWidget(_app(gemini));
    await tester.pumpAndSettle();
    expect(llamadas, 1); // solo la generación

    await tester.tap(find.widgetWithText(ElevatedButton, 'Verificar'));
    await tester.pumpAndSettle();

    expect(llamadas, 1); // no hubo pedido de corrección
  });
}
