import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
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

/// Gemini simulado: la primera llamada genera la frase, la segunda corrige.
Gemini _geminiFalso({
  required String generacion,
  String correccion = 'CORRECTO',
  int statusCode = 200,
}) {
  var llamada = 0;
  return Gemini(
    cliente: MockClient((request) async {
      llamada++;
      if (statusCode != 200) {
        return http.Response('{"error": "clave mala"}', statusCode);
      }
      return http.Response(
        _respuestaGemini(llamada == 1 ? generacion : correccion),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }),
  );
}

Widget _app(Gemini gemini, {VoidCallback? onClaveInvalida}) => MaterialApp(
      home: Scaffold(
        body: PantallaFrases(
          verbos: _verbos.verbos.values.toList(),
          tiempos: const ['presente'],
          apiKey: 'FAKE',
          gemini: gemini,
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

const _fraseOk = '{"espanol": "Hoy soy feliz", "italiano": "Oggi sono felice"}';

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
