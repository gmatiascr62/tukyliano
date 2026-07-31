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

  Widget app({List<String>? verbosMarcados, List<String>? tiemposMarcados}) =>
      MaterialApp(
        home: Scaffold(
          body: PantallaSeleccion(
            verbos: _datos.verbos,
            verbosMarcados: verbosMarcados,
            tiemposMarcados: tiemposMarcados,
            alConfirmar: (v, t) {
              verbosElegidos = v;
              tiemposElegidos = t;
            },
          ),
        ),
      );

  /// Si la fila está tildada. Se mira el Checkbox de esa fila.
  bool tildado(WidgetTester tester, String texto) {
    final fila = find.ancestor(
      of: find.text(texto),
      matching: find.byType(Row),
    );
    final casilla = tester.widget<Checkbox>(
      find.descendant(of: fila.first, matching: find.byType(Checkbox)),
    );
    return casilla.value!;
  }

  testWidgets('arranca con todo tildado y devuelve todo', (tester) async {
    await tester.pumpWidget(app());

    await tester.tap(find.widgetWithText(ElevatedButton, 'Empezar'));
    await tester.pump();

    expect(verbosElegidos, containsAll(['essere', 'avere']));
    // Los cuatro tiempos más el gerundio.
    expect(tiemposElegidos.length, 5);
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
    expect(tiemposElegidos.length, 4);
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

  group('vuelve a mostrar lo que se había elegido', () {
    testWidgets('sin selección previa arranca con todo tildado',
        (tester) async {
      await tester.pumpWidget(app());

      expect(tildado(tester, 'essere (ser/estar)'), isTrue);
      expect(tildado(tester, 'avere (tener)'), isTrue);
      expect(tildado(tester, 'presente'), isTrue);
    });

    testWidgets('con selección previa solo esos quedan tildados',
        (tester) async {
      await tester.pumpWidget(app(
        verbosMarcados: ['avere'],
        tiemposMarcados: ['presente', 'gerundio'],
      ));

      expect(tildado(tester, 'avere (tener)'), isTrue);
      expect(tildado(tester, 'essere (ser/estar)'), isFalse);
      expect(tildado(tester, 'presente'), isTrue);
      expect(tildado(tester, 'gerundio'), isTrue);
      expect(tildado(tester, 'imperfetto'), isFalse);
    });

    testWidgets('y al confirmar devuelve esa misma selección', (tester) async {
      await tester.pumpWidget(app(
        verbosMarcados: ['avere'],
        tiemposMarcados: ['presente'],
      ));

      await tester.tap(find.widgetWithText(ElevatedButton, 'Empezar'));
      await tester.pump();

      expect(verbosElegidos, ['avere']);
      expect(tiemposElegidos, ['presente']);
    });

    testWidgets('un verbo que no está en la lista previa no rompe nada',
        (tester) async {
      // Puede pasar si el verbo se borró del JSON entre una vez y la otra.
      await tester.pumpWidget(app(verbosMarcados: ['mangiare']));

      expect(tildado(tester, 'essere (ser/estar)'), isFalse);
      expect(tildado(tester, 'avere (tener)'), isFalse);
      // Sin nada tildado, al confirmar se usa todo, como siempre.
      await tester.tap(find.widgetWithText(ElevatedButton, 'Empezar'));
      await tester.pump();
      expect(verbosElegidos, containsAll(['essere', 'avere']));
    });
  });
}
