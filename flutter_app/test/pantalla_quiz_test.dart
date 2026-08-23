import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tukyliano/modelos/verbo.dart';
import 'package:tukyliano/pantallas/pantalla_quiz.dart';
import 'package:tukyliano/widgets/boton_opcion.dart';
import 'package:tukyliano/widgets/teclado.dart';

import 'util_pantalla.dart';

/// Un solo verbo con una sola conjugación: así la pregunta es determinística
/// y se puede afirmar cuál es la respuesta correcta.
final _unicaConjugacion = DatosVerbos.desdeJson(jsonDecode('''
  {"verbos": {"essere": {"traduccion": "ser/estar", "tiempos": {
    "presente": {"io": {"italiano": "sono", "espanol": "yo soy/estoy"}}
  }}}}
''') as Map<String, dynamic>);

Widget _app(DatosVerbos datos, {List<String> tiempos = const ['presente']}) {
  return MaterialApp(
    home: Scaffold(
      body: PantallaQuiz(
        verbos: datos.verbos.values.toList(),
        tiempos: tiempos,
      ),
    ),
  );
}

Future<void> _escribir(WidgetTester tester, String palabra) async {
  for (final letra in palabra.split('')) {
    await tester.tap(find.widgetWithText(ElevatedButton, letra));
    await tester.pump();
  }
}

/// Un verbo entero, para que el modo de elegir tenga de dónde sacar los
/// distractores: las otras personas del mismo tiempo.
final _verboCompleto = DatosVerbos.desdeJson(jsonDecode('''
  {"verbos": {"andare": {"traduccion": "ir", "tiempos": {
    "presente": {
      "io": {"italiano": "vado", "espanol": "yo voy"},
      "tu": {"italiano": "vai", "espanol": "tú vas"},
      "lui/lei": {"italiano": "va", "espanol": "él/ella va"},
      "noi": {"italiano": "andiamo", "espanol": "nosotros vamos"},
      "voi": {"italiano": "andate", "espanol": "ustedes van"},
      "loro": {"italiano": "vanno", "espanol": "ellos van"}
    }
  }}}}
''') as Map<String, dynamic>);

/// Lo que dicen los cuatro botones de respuesta.
List<String> _opciones(WidgetTester tester) => tester
    .widgetList<BotonOpcion>(find.byType(BotonOpcion))
    .map((b) => b.texto)
    .toList();

void main() {
  testWidgets('muestra la pregunta en español y el puntaje en cero',
      (tester) async {
    usarPantallaDeCelular(tester);
    await tester.pumpWidget(_app(_unicaConjugacion));

    expect(find.textContaining("yo soy/estoy"), findsOneWidget);
    expect(find.text('Puntaje: 0/0'), findsOneWidget);
    expect(find.text('Escribí la conjugación...'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Verificar'), findsOneWidget);
  });

  testWidgets('una respuesta correcta suma puntaje', (tester) async {
    usarPantallaDeCelular(tester);
    await tester.pumpWidget(_app(_unicaConjugacion));

    await _escribir(tester, 'sono');
    expect(find.text('sono'), findsOneWidget);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Verificar'));
    await tester.pump();

    expect(find.text('¡Correcto!'), findsOneWidget);
    expect(find.text('Puntaje: 1/1'), findsOneWidget);
    // El botón pasa a "Siguiente".
    expect(find.widgetWithText(ElevatedButton, 'Siguiente'), findsOneWidget);
  });

  testWidgets('una respuesta incorrecta muestra la correcta y no suma',
      (tester) async {
    usarPantallaDeCelular(tester);
    await tester.pumpWidget(_app(_unicaConjugacion));

    await _escribir(tester, 'sei');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Verificar'));
    await tester.pump();

    expect(find.text('Incorrecto. Era: sono'), findsOneWidget);
    expect(find.text('Puntaje: 0/1'), findsOneWidget);
  });

  testWidgets('la tecla de borrar saca el último carácter', (tester) async {
    usarPantallaDeCelular(tester);
    await tester.pumpWidget(_app(_unicaConjugacion));

    await _escribir(tester, 'son');
    await tester.tap(find.widgetWithText(ElevatedButton, '<--'));
    await tester.pump();

    expect(find.text('so'), findsOneWidget);
  });

  testWidgets('verificar con el campo vacío no hace nada', (tester) async {
    usarPantallaDeCelular(tester);
    await tester.pumpWidget(_app(_unicaConjugacion));

    await tester.tap(find.widgetWithText(ElevatedButton, 'Verificar'));
    await tester.pump();

    // Sigue en la misma pregunta, sin contarla como intento.
    expect(find.text('Puntaje: 0/0'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Verificar'), findsOneWidget);
  });

  testWidgets('"Siguiente" limpia el campo y el feedback', (tester) async {
    usarPantallaDeCelular(tester);
    await tester.pumpWidget(_app(_unicaConjugacion));

    await _escribir(tester, 'sono');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Verificar'));
    await tester.pump();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Siguiente'));
    await tester.pump();

    expect(find.text('¡Correcto!'), findsNothing);
    expect(find.text('Escribí la conjugación...'), findsOneWidget);
    // El puntaje acumulado se mantiene entre preguntas.
    expect(find.text('Puntaje: 1/1'), findsOneWidget);
  });

  testWidgets('avisa cuando no hay verbos con datos', (tester) async {
    usarPantallaDeCelular(tester);
    final viejos = DatosVerbos.desdeJson(jsonDecode(
        '{"verbos": {"volere": {"conjugaciones": {"io": "voglio"}}}}') as Map<String, dynamic>);

    await tester.pumpWidget(_app(viejos));

    expect(find.textContaining('No hay verbos con datos cargados'), findsOneWidget);
  });

  group('las dos formas de contestar', () {
    testWidgets('arranca en Escribir, con el teclado', (tester) async {
      usarPantallaDeCelular(tester);
      await tester.pumpWidget(_app(_verboCompleto));

      expect(find.byType(Teclado), findsOneWidget);
      expect(find.byType(BotonOpcion), findsNothing);
      expect(find.text('Escribí la conjugación...'), findsOneWidget);
    });

    testWidgets('en Elegir ofrece cuatro formas del mismo verbo',
        (tester) async {
      usarPantallaDeCelular(tester);
      await tester.pumpWidget(_app(_verboCompleto));

      await tester.tap(find.text('Elegir'));
      await tester.pumpAndSettle();

      // Sin teclado: se contesta tocando.
      expect(find.byType(Teclado), findsNothing);
      final opciones = _opciones(tester);
      expect(opciones.length, 4);
      expect(
        opciones.toSet().difference(
            {'vado', 'vai', 'va', 'andiamo', 'andate', 'vanno'}),
        isEmpty,
        reason: '$opciones',
      );
    });

    testWidgets('tocando la correcta suma, igual que escribiéndola',
        (tester) async {
      usarPantallaDeCelular(tester);
      await tester.pumpWidget(_app(_unicaConjugacion));

      await tester.tap(find.text('Elegir'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(BotonOpcion, 'sono'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Verificar'));
      await tester.pumpAndSettle();

      expect(find.text('¡Correcto!'), findsOneWidget);
      expect(find.text('Puntaje: 1/1'), findsOneWidget);
    });

    testWidgets('sin tocar ninguna no se puede verificar', (tester) async {
      usarPantallaDeCelular(tester);
      await tester.pumpWidget(_app(_verboCompleto));

      await tester.tap(find.text('Elegir'));
      await tester.pumpAndSettle();

      final boton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Verificar'),
      );
      expect(boton.onPressed, isNull);
    });

    testWidgets('cambiar de modo borra lo que se había escrito',
        (tester) async {
      usarPantallaDeCelular(tester);
      await tester.pumpWidget(_app(_unicaConjugacion));

      await _escribir(tester, 'son');
      await tester.tap(find.text('Elegir'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Escribir'));
      await tester.pumpAndSettle();

      // Vuelve el cartel de vacío, no lo que estaba a medio escribir.
      expect(find.text('Escribí la conjugación...'), findsOneWidget);
    });
  });
}
