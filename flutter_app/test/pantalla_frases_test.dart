import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tukyliano/datos/repositorio_frases.dart';
import 'package:tukyliano/modelos/verbo.dart';
import 'package:tukyliano/pantallas/pantalla_frases.dart';
import 'package:tukyliano/tema.dart';

import 'util_pantalla.dart';

final _verbos = DatosVerbos.desdeJson(jsonDecode('''
  {"verbos": {"avere": {"traduccion": "tener", "tiempos": {
    "presente": {"io": {"italiano": "ho", "espanol": "yo tengo"}}
  }}}}
''') as Map<String, dynamic>);

const _guardadas = '''
  {"frases": [
    {"verbo": "avere", "tiempo": "presente", "persona": "io",
     "espanol": "Tengo mucha hambre", "italiano": "Ho molta fame",
     "pista": "hambre = fame"}
  ]}
''';

/// Repositorio con las frases que le pasemos, sin red ni cache en disco.
RepositorioFrases _frases([String json = _guardadas]) => RepositorioFrases(
      leerAsset: (_) async => json,
      cliente: MockClient((_) async => http.Response('', 404)),
      carpeta: () async => null,
    );

Widget _app({RepositorioFrases? frases}) => MaterialApp(
      home: Scaffold(
        body: PantallaFrases(
          verbos: _verbos.verbos.values.toList(),
          tiempos: const ['presente'],
          frasesLocales: frases ?? _frases(),
        ),
      ),
    );

Future<void> _escribir(WidgetTester tester, String texto) async {
  for (final letra in texto.split('')) {
    final tecla = letra == ' ' ? 'espacio' : letra;
    await tester.tap(find.widgetWithText(ElevatedButton, tecla));
    await tester.pump();
  }
}

/// El color con el que quedó pintada una palabra de la respuesta correcta.
Color? _colorDe(WidgetTester tester, String palabra) {
  final textos = tester.widgetList<Text>(find.byType(Text));
  for (final texto in textos) {
    final span = texto.textSpan;
    if (span is! TextSpan) continue;
    for (final hijo in span.children ?? const <InlineSpan>[]) {
      if (hijo is TextSpan && hijo.text?.trim() == palabra) {
        return hijo.style?.color;
      }
    }
  }
  return null;
}

void main() {
  testWidgets('muestra la frase guardada en español', (tester) async {
    usarPantallaDeCelular(tester);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.textContaining('Tengo mucha hambre'), findsOneWidget);
    expect(find.text('Escribí la traducción...'), findsOneWidget);
  });

  testWidgets('si no hay frases para esos verbos, lo avisa', (tester) async {
    usarPantallaDeCelular(tester);
    await tester.pumpWidget(_app(frases: _frases('{"frases": []}')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Todavía no hay frases'), findsOneWidget);
  });

  testWidgets('un asset roto no rompe la pantalla', (tester) async {
    usarPantallaDeCelular(tester);
    await tester.pumpWidget(_app(frases: _frases('esto no es JSON')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Todavía no hay frases'), findsOneWidget);
  });

  testWidgets('descarta la frase que no trae la conjugación esperada',
      (tester) async {
    usarPantallaDeCelular(tester);
    await tester.pumpWidget(_app(
      frases: _frases('''
        {"frases": [
          {"verbo": "avere", "tiempo": "presente", "persona": "io",
           "espanol": "Tengo hambre", "italiano": "O molta fame", "pista": ""}
        ]}
      '''),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('Todavía no hay frases'), findsOneWidget);
  });

  group('verificar', () {
    testWidgets('sin escribir nada no muestra la respuesta', (tester) async {
      usarPantallaDeCelular(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Verificar'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Ho molta fame'), findsNothing);
      expect(find.widgetWithText(ElevatedButton, 'Verificar'), findsOneWidget);
    });

    testWidgets('con la respuesta bien, todas las palabras en verde',
        (tester) async {
      usarPantallaDeCelular(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      await _escribir(tester, 'ho molta fame');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Verificar'));
      await tester.pumpAndSettle();

      expect(_colorDe(tester, 'Ho'), Tema.correcto);
      expect(_colorDe(tester, 'molta'), Tema.correcto);
      expect(_colorDe(tester, 'fame'), Tema.correcto);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Siguiente'), findsOneWidget);
    });

    testWidgets('marca en rojo solo la palabra equivocada', (tester) async {
      usarPantallaDeCelular(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      await _escribir(tester, 'ho molto fame');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Verificar'));
      await tester.pumpAndSettle();

      expect(_colorDe(tester, 'Ho'), Tema.correcto);
      expect(_colorDe(tester, 'molta'), Tema.incorrecto);
      expect(_colorDe(tester, 'fame'), Tema.correcto);
      expect(find.byIcon(Icons.cancel), findsOneWidget);
    });

    testWidgets('no hace falta acertar el orden', (tester) async {
      usarPantallaDeCelular(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      await _escribir(tester, 'fame molta ho');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Verificar'));
      await tester.pumpAndSettle();

      expect(_colorDe(tester, 'Ho'), Tema.correcto);
      expect(_colorDe(tester, 'molta'), Tema.correcto);
      expect(_colorDe(tester, 'fame'), Tema.correcto);
    });

    testWidgets('Siguiente limpia la respuesta y el campo', (tester) async {
      usarPantallaDeCelular(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      await _escribir(tester, 'ho');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Verificar'));
      await tester.pumpAndSettle();
      expect(_colorDe(tester, 'molta'), Tema.incorrecto);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Siguiente'));
      await tester.pumpAndSettle();

      expect(_colorDe(tester, 'molta'), isNull);
      expect(find.text('Escribí la traducción...'), findsOneWidget);
    });
  });

  group('pista', () {
    testWidgets('arranca escondida y se revela al tocar el botón',
        (tester) async {
      usarPantallaDeCelular(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      expect(find.text('hambre = fame'), findsNothing);

      await tester.tap(find.widgetWithText(TextButton, 'Pista'));
      await tester.pumpAndSettle();

      expect(find.text('hambre = fame'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Pista'), findsNothing);
    });

    testWidgets('si la frase no trae pista, no aparece el botón',
        (tester) async {
      usarPantallaDeCelular(tester);
      await tester.pumpWidget(_app(
        frases: _frases('''
          {"frases": [
            {"verbo": "avere", "tiempo": "presente", "persona": "io",
             "espanol": "Tengo hambre", "italiano": "Ho fame", "pista": ""}
          ]}
        '''),
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('Tengo hambre'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Pista'), findsNothing);
    });

    testWidgets('se esconde de nuevo en la frase siguiente', (tester) async {
      usarPantallaDeCelular(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextButton, 'Pista'));
      await tester.pumpAndSettle();
      expect(find.text('hambre = fame'), findsOneWidget);

      await _escribir(tester, 'ho');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Verificar'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Siguiente'));
      await tester.pumpAndSettle();

      expect(find.text('hambre = fame'), findsNothing);
    });
  });
}
