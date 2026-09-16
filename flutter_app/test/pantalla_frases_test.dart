import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tukyliano/datos/repositorio_frases.dart';
import 'package:tukyliano/modelos/verbo.dart';
import 'package:tukyliano/pantallas/pantalla_frases.dart';
import 'package:tukyliano/tema.dart';
import 'package:tukyliano/widgets/ficha_palabra.dart';

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
      theme: Tema.datos,
      home: Scaffold(
        body: PantallaFrases(
          verbos: _verbos.verbos.values.toList(),
          tiempos: const ['presente'],
          frasesLocales: frases ?? _frases(),
          azar: Random(1),
        ),
      ),
    );

/// Las fichas de la frase de prueba, las únicas que están bien. La primera va
/// en minúscula: la ficha no lleva la mayúscula del principio de la frase.
const _correctas = ['ho', 'molta', 'fame'];

/// Una ficha del banco (las de abajo) o de la frase armada (las verdes).
Finder _ficha(String palabra, {bool puesta = false}) => find.byWidgetPredicate(
      (w) => w is FichaPalabra && w.palabra == palabra && w.puesta == puesta,
    );

/// Todas las palabras que hay en el banco.
List<String> _delBanco(WidgetTester tester) => tester
    .widgetList<FichaPalabra>(find.byType(FichaPalabra))
    .where((f) => !f.puesta)
    .map((f) => f.palabra)
    .toList();

Future<void> _armar(WidgetTester tester, List<String> palabras) async {
  for (final palabra in palabras) {
    await tester.tap(_ficha(palabra));
    await tester.pump();
  }
}

/// Cambia al modo de teclado y escribe. El modo que viene puesto es el de
/// armar con fichas, así que hay que pedirlo.
Future<void> _escribir(WidgetTester tester, String texto) async {
  await tester.tap(find.text('Escribir'));
  await tester.pumpAndSettle();
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
    expect(find.text('Tocá las palabras de abajo'), findsOneWidget);
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

  group('armar con fichas', () {
    testWidgets('arranca armando, sin teclado a la vista', (tester) async {
      usarPantallaDeCelular(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      expect(find.text('ARMÁ LA FRASE EN ITALIANO'), findsOneWidget);
      // La barra de espacio del teclado propio: si no está, no hay teclado.
      expect(find.widgetWithText(ElevatedButton, 'espacio'), findsNothing);
    });

    testWidgets('el banco trae las palabras de la frase y alguna de más',
        (tester) async {
      usarPantallaDeCelular(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      final banco = _delBanco(tester);
      for (final palabra in _correctas) {
        expect(banco, contains(palabra), reason: palabra);
      }
      expect(banco.length, greaterThan(_correctas.length));
    });

    testWidgets('tocar una ficha la pone en la frase y tocarla la saca',
        (tester) async {
      usarPantallaDeCelular(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      await _armar(tester, ['molta']);
      expect(_ficha('molta', puesta: true), findsOneWidget);
      expect(find.text('Tocá las palabras de abajo'), findsNothing);

      await tester.tap(_ficha('molta', puesta: true));
      await tester.pumpAndSettle();
      expect(_ficha('molta', puesta: true), findsNothing);
      expect(find.text('Tocá las palabras de abajo'), findsOneWidget);
    });

    testWidgets('con la frase bien armada, todo verde', (tester) async {
      usarPantallaDeCelular(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      await _armar(tester, _correctas);
      await tester.tap(find.widgetWithText(ElevatedButton, 'Verificar'));
      await tester.pumpAndSettle();

      // La respuesta correcta se muestra como está escrita, con su mayúscula,
      // aunque la ficha que se tocó fuera "ho".
      for (final palabra in ['Ho', 'molta', 'fame']) {
        expect(_colorDe(tester, palabra), Tema.correcto, reason: palabra);
      }
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('poner una ficha de más no cuenta como acertada',
        (tester) async {
      usarPantallaDeCelular(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      final deMas =
          _delBanco(tester).firstWhere((p) => !_correctas.contains(p));
      await _armar(tester, [..._correctas, deMas]);
      await tester.tap(find.widgetWithText(ElevatedButton, 'Verificar'));
      await tester.pumpAndSettle();

      // La frase correcta queda toda verde —están todas sus palabras—, así que
      // lo que dice que está mal es el sobrante.
      expect(find.byIcon(Icons.cancel), findsOneWidget);
      expect(find.text('Te sobró: $deMas'), findsOneWidget);
    });

    testWidgets('después de verificar no se tocan más fichas', (tester) async {
      usarPantallaDeCelular(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      await _armar(tester, ['ho']);
      await tester.tap(find.widgetWithText(ElevatedButton, 'Verificar'));
      await tester.pumpAndSettle();

      await tester.tap(_ficha('molta'));
      await tester.pumpAndSettle();

      expect(_ficha('molta', puesta: true), findsNothing);
    });

    testWidgets('Siguiente vacía la frase armada', (tester) async {
      usarPantallaDeCelular(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      await _armar(tester, _correctas);
      await tester.tap(find.widgetWithText(ElevatedButton, 'Verificar'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Siguiente'));
      await tester.pumpAndSettle();

      expect(find.text('Tocá las palabras de abajo'), findsOneWidget);
      expect(_ficha('ho', puesta: true), findsNothing);
    });

    testWidgets('el que quiere escribir todavía puede', (tester) async {
      usarPantallaDeCelular(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Escribir'));
      await tester.pumpAndSettle();

      expect(find.text('Escribí la traducción...'), findsOneWidget);
      expect(find.byType(FichaPalabra), findsNothing);
      expect(find.widgetWithText(ElevatedButton, 'espacio'), findsOneWidget);
    });

    testWidgets('cambiar de modo borra lo que se había armado', (tester) async {
      usarPantallaDeCelular(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      await _armar(tester, _correctas);
      await tester.tap(find.text('Escribir'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Armar'));
      await tester.pumpAndSettle();

      expect(find.text('Tocá las palabras de abajo'), findsOneWidget);
    });
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
