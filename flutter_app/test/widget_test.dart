import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tukyliano/datos/almacenamiento_clave.dart';
import 'package:tukyliano/main.dart';
import 'package:tukyliano/widgets/barra_superior.dart';

import 'util_pantalla.dart';

Future<void> _tocar(WidgetTester tester, String texto) async {
  // La barra se desliza, así que los últimos botones arrancan fuera de la
  // pantalla y hay que traerlos antes de tocarlos.
  final boton = find.widgetWithText(ElevatedButton, texto);
  await tester.scrollUntilVisible(
    boton,
    80,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(boton);
  await tester.pumpAndSettle();
}

void main() {
  // En los tests no hay plugins de plataforma, así que la carga de verbos
  // (path_provider) falla y la sección Verbi queda sin datos. Acá se verifica
  // la navegación; el parseo se prueba en modelo_verbo_test.dart.
  testWidgets('la barra trae las seis secciones, en italiano',
      (WidgetTester tester) async {
    usarPantallaDeCelular(tester);
    await tester.pumpWidget(const TukylianoApp());

    for (final seccion in Seccion.values) {
      expect(
        find.widgetWithText(ElevatedButton, seccion.etiqueta),
        findsOneWidget,
        reason: seccion.name,
      );
    }
  });

  testWidgets('arranca en Frasi, que es la primera de la barra',
      (WidgetTester tester) async {
    usarPantallaDeCelular(tester);
    await tester.pumpWidget(const TukylianoApp());
    await tester.pumpAndSettle();

    // Frasi depende de los verbos, que sin path_provider no llegan.
    expect(find.text('Cargando verbos...'), findsOneWidget);
  });

  testWidgets('la barra cambia de sección', (WidgetTester tester) async {
    usarPantallaDeCelular(tester);
    await tester.pumpWidget(const TukylianoApp());
    await tester.pumpAndSettle();

    // Articoli y Preposizioni no dependen de los verbos, así que entran
    // aunque estos no hayan cargado.
    await _tocar(tester, 'Articoli');
    expect(find.text('Cargando verbos...'), findsNothing);
    expect(find.text('Próximamente'), findsNothing);

    await _tocar(tester, 'Preposizioni');
    expect(find.text('Cargando verbos...'), findsNothing);
    expect(find.text('Próximamente'), findsNothing);

    await _tocar(tester, 'Verbi');
    expect(find.text('Cargando verbos...'), findsOneWidget);
  });

  testWidgets('Racconti entra a los cuentos, no al cartel',
      (WidgetTester tester) async {
    usarPantallaDeCelular(tester);
    await tester.pumpWidget(const TukylianoApp());
    await tester.pumpAndSettle();

    await _tocar(tester, 'Racconti');
    expect(find.text('Próximamente'), findsNothing);
    expect(find.text('Cargando verbos...'), findsNothing);
  });

  testWidgets('Chat entra a la charla y pide la clave de la IA',
      (WidgetTester tester) async {
    usarPantallaDeCelular(tester);
    // Sin carpeta no hay clave guardada, que es lo que pasa la primera vez.
    await tester.pumpWidget(TukylianoApp(
      almacenClave: AlmacenamientoClave(carpeta: () async => null),
    ));
    await tester.pumpAndSettle();

    await _tocar(tester, 'Chat');
    expect(
      find.text('Necesitás una clave gratis de la IA (Gemini)'),
      findsOneWidget,
    );
  });
}
