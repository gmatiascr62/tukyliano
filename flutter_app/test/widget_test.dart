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

    // Sin clave de Gemini guardada, Frases lleva primero a pedirla.
    await tester.tap(find.widgetWithText(ElevatedButton, 'Frases'));
    await tester.pumpAndSettle();
    expect(
      find.text('Necesitás una clave gratis de la IA (Gemini)'),
      findsOneWidget,
    );
    expect(find.widgetWithText(ElevatedButton, 'Pegar clave'), findsOneWidget);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Articoli'));
    await tester.pumpAndSettle();
    expect(find.text('Articoli'), findsNWidgets(2));

    await tester.tap(find.widgetWithText(ElevatedButton, 'Verbos'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ElevatedButton, 'Pegar clave'), findsNothing);
  });
}
