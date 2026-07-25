import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tukyliano/main.dart';

void main() {
  testWidgets('arranca mostrando las tres secciones y la de Verbos',
      (WidgetTester tester) async {
    await tester.pumpWidget(const TukylianoApp());

    expect(find.text('Articoli'), findsOneWidget);
    expect(find.text('Frases'), findsOneWidget);
    // "Verbos" aparece en el botón y en el cuerpo de la sección inicial.
    expect(find.text('Verbos'), findsNWidgets(2));
  });

  testWidgets('la barra de arriba cambia de sección',
      (WidgetTester tester) async {
    await tester.pumpWidget(const TukylianoApp());

    await tester.tap(find.widgetWithText(ElevatedButton, 'Frases'));
    await tester.pumpAndSettle();
    expect(find.text('La práctica con IA llega en la fase 4'), findsOneWidget);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Articoli'));
    await tester.pumpAndSettle();
    expect(find.text('Articoli'), findsNWidgets(2));
  });
}
