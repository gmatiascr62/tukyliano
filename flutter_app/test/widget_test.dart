import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tukyliano/main.dart';

void main() {
  // En los tests no hay plugins de plataforma, así que la carga de verbos
  // (path_provider) falla y la pantalla de Verbos queda sin datos. Acá se
  // verifica la navegación; el parseo se prueba en modelo_verbo_test.dart.
  testWidgets('muestra las tres secciones en la barra de arriba',
      (WidgetTester tester) async {
    await tester.pumpWidget(const TukylianoApp());

    expect(find.widgetWithText(ElevatedButton, 'Articoli'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Frases'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Verbos'), findsOneWidget);
  });

  testWidgets('la barra de arriba cambia de sección',
      (WidgetTester tester) async {
    await tester.pumpWidget(const TukylianoApp());

    // Frases ya no pide ninguna clave: acá sin verbos cargados queda
    // esperándolos.
    await tester.tap(find.widgetWithText(ElevatedButton, 'Frases'));
    await tester.pumpAndSettle();
    expect(find.text('Cargando verbos...'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Pegar clave'), findsNothing);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Articoli'));
    await tester.pumpAndSettle();
    expect(find.text('Articoli'), findsNWidgets(2));
    expect(find.text('Cargando verbos...'), findsNothing);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Verbos'));
    await tester.pumpAndSettle();
    // Sin path_provider los verbos nunca llegan, así que las dos secciones
    // que dependen de ellos quedan esperando.
    expect(find.text('Cargando verbos...'), findsOneWidget);
  });
}
