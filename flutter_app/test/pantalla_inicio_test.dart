import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tukyliano/datos/progreso.dart';
import 'package:tukyliano/pantallas/pantalla_inicio.dart';
import 'package:tukyliano/tema.dart';

import 'util_pantalla.dart';

Future<Progreso> _conAciertos(int cuantos) async {
  final progreso = Progreso(carpeta: () async => null);
  await progreso.cargar();
  for (var i = 0; i < cuantos; i++) {
    progreso.acerto();
  }
  return progreso;
}

Future<List<Destino>> _abrir(
  WidgetTester tester, {
  Progreso? progreso,
}) async {
  final tocados = <Destino>[];
  usarPantallaDeCelular(tester);
  await tester.pumpWidget(MaterialApp(
    theme: Tema.datos,
    home: Scaffold(
      body: PantallaInicio(
        progreso: progreso ?? Progreso(carpeta: () async => null),
        alElegir: tocados.add,
      ),
    ),
  ));
  await tester.pumpAndSettle();
  return tocados;
}

void main() {
  testWidgets('están los cuatro botones', (WidgetTester tester) async {
    await _abrir(tester);

    for (final destino in Destino.values) {
      expect(find.text(destino.etiqueta), findsOneWidget, reason: destino.name);
      expect(find.byIcon(destino.icono), findsOneWidget, reason: destino.name);
    }
  });

  testWidgets('tocar uno avisa a dónde ir', (WidgetTester tester) async {
    final tocados = await _abrir(tester);

    await tester.tap(find.byIcon(Destino.gramatica.icono));
    await tester.pumpAndSettle();

    expect(tocados, [Destino.gramatica]);
  });

  testWidgets('el centro muestra el nivel que se lleva',
      (WidgetTester tester) async {
    await _abrir(tester, progreso: await _conAciertos(60));

    // 60 aciertos ya pasaron el escalón de 50.
    expect(find.text('NIVEL 2'), findsOneWidget);
    expect(find.text('Alunno'), findsOneWidget);
  });

  testWidgets('el anillo se llena con lo que se lleva hecho',
      (WidgetTester tester) async {
    await _abrir(tester, progreso: await _conAciertos(25));

    final anillo = tester.widget<CircularProgressIndicator>(
      find.byType(CircularProgressIndicator),
    );
    // Mitad de camino entre 0 y el escalón de 50.
    expect(anillo.value, closeTo(0.5, 0.001));
  });

  testWidgets('sin practicar esta semana lo dice sin retar',
      (WidgetTester tester) async {
    await _abrir(tester);

    expect(find.text('Todavía no practicaste esta semana'), findsOneWidget);
  });

  testWidgets('cuenta los días practicados', (WidgetTester tester) async {
    await _abrir(tester, progreso: await _conAciertos(1));

    expect(find.text('Practicaste 1 de los últimos 7 días'), findsOneWidget);
  });
}
