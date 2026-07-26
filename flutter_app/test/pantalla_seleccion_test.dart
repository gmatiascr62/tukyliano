import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tukyliano/modelos/verbo.dart';
import 'package:tukyliano/pantallas/pantalla_seleccion.dart';

final _datos = DatosVerbos.desdeJson(jsonDecode('''
  {"verbos": {
    "essere": {"traduccion": "ser/estar", "tiempos": {
      "presente": {"io": {"italiano": "sono", "espanol": "yo soy"}}
    }},
    "avere": {"traduccion": "tener", "tiempos": {
      "presente": {"io": {"italiano": "ho", "espanol": "yo tengo"}}
    }}
  }}
''') as Map<String, dynamic>);

void main() {
  late List<String> verbosElegidos;
  late List<String> tiemposElegidos;

  Widget app() => MaterialApp(
        home: Scaffold(
          body: PantallaSeleccion(
            verbos: _datos.verbos,
            alConfirmar: (v, t) {
              verbosElegidos = v;
              tiemposElegidos = t;
            },
          ),
        ),
      );

  testWidgets('arranca con todo tildado y devuelve todo', (tester) async {
    await tester.pumpWidget(app());

    await tester.tap(find.widgetWithText(ElevatedButton, 'Empezar'));
    await tester.pump();

    expect(verbosElegidos, containsAll(['essere', 'avere']));
    expect(tiemposElegidos.length, 4);
  });

  testWidgets('destildar un verbo lo saca de la selección', (tester) async {
    await tester.pumpWidget(app());

    await tester.tap(find.text('avere (tener)'));
    await tester.pump();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Empezar'));
    await tester.pump();

    expect(verbosElegidos, ['essere']);
  });

  testWidgets('destildar un tiempo lo saca de la selección', (tester) async {
    await tester.pumpWidget(app());

    await tester.tap(find.text('imperfetto'));
    await tester.pump();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Empezar'));
    await tester.pump();

    expect(tiemposElegidos, isNot(contains('imperfetto')));
    expect(tiemposElegidos.length, 3);
  });

  testWidgets('si se destilda todo se usa todo, como en la app Kivy',
      (tester) async {
    await tester.pumpWidget(app());

    await tester.tap(find.text('essere (ser/estar)'));
    await tester.pump();
    await tester.tap(find.text('avere (tener)'));
    await tester.pump();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Empezar'));
    await tester.pump();

    expect(verbosElegidos, containsAll(['essere', 'avere']));
  });
}
