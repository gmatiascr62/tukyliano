import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tukyliano/modelos/verbo.dart';
import 'package:tukyliano/pantallas/pantalla_quiz.dart';

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
        estado: '',
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

void main() {
  testWidgets('muestra la pregunta en español y el puntaje en cero',
      (tester) async {
    await tester.pumpWidget(_app(_unicaConjugacion));

    expect(find.textContaining("yo soy/estoy"), findsOneWidget);
    expect(find.text('Puntaje: 0/0'), findsOneWidget);
    expect(find.text('Escribí la conjugación...'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Verificar'), findsOneWidget);
  });

  testWidgets('una respuesta correcta suma puntaje', (tester) async {
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
    await tester.pumpWidget(_app(_unicaConjugacion));

    await _escribir(tester, 'sei');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Verificar'));
    await tester.pump();

    expect(find.text('Incorrecto. Era: sono'), findsOneWidget);
    expect(find.text('Puntaje: 0/1'), findsOneWidget);
  });

  testWidgets('la tecla de borrar saca el último carácter', (tester) async {
    await tester.pumpWidget(_app(_unicaConjugacion));

    await _escribir(tester, 'son');
    await tester.tap(find.widgetWithText(ElevatedButton, '<--'));
    await tester.pump();

    expect(find.text('so'), findsOneWidget);
  });

  testWidgets('verificar con el campo vacío no hace nada', (tester) async {
    await tester.pumpWidget(_app(_unicaConjugacion));

    await tester.tap(find.widgetWithText(ElevatedButton, 'Verificar'));
    await tester.pump();

    // Sigue en la misma pregunta, sin contarla como intento.
    expect(find.text('Puntaje: 0/0'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Verificar'), findsOneWidget);
  });

  testWidgets('"Siguiente" limpia el campo y el feedback', (tester) async {
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
    final viejos = DatosVerbos.desdeJson(jsonDecode(
        '{"verbos": {"volere": {"conjugaciones": {"io": "voglio"}}}}') as Map<String, dynamic>);

    await tester.pumpWidget(_app(viejos));

    expect(find.textContaining('No hay verbos con datos cargados'), findsOneWidget);
  });
}
