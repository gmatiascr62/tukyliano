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

  testWidgets('sin practicar esta semana invita en vez de retar',
      (WidgetTester tester) async {
    await _abrir(tester);

    expect(find.text('Esta semana'), findsOneWidget);
    expect(find.text('Empezá hoy'), findsOneWidget);
    expect(find.text('0 de 7 días'), findsNothing);
  });

  testWidgets('cuenta los días practicados', (WidgetTester tester) async {
    await _abrir(tester, progreso: await _conAciertos(1));

    expect(find.text('1 de 7 días'), findsOneWidget);
  });

  testWidgets('la semana dibuja los siete días y marca el de hoy',
      (WidgetTester tester) async {
    await _abrir(tester, progreso: await _conAciertos(1));

    // Siete días, y practicado solo hoy: una sola palomita.
    final hoy = DateTime.now();
    for (var atras = 0; atras < 7; atras++) {
      final letra = const ['L', 'M', 'M', 'J', 'V', 'S', 'D'][
          hoy.subtract(Duration(days: atras)).weekday - 1];
      expect(find.text(letra), findsWidgets, reason: 'falta el día $letra');
    }
    expect(find.byIcon(Icons.check), findsOneWidget);
  });

  testWidgets('dice cuánto falta para el nivel que sigue',
      (WidgetTester tester) async {
    await _abrir(tester, progreso: await _conAciertos(18));

    // 50 para Alunno, 18 hechos.
    expect(find.text('faltan 32'), findsOneWidget);
  });

  // El bug de verdad que tenía esta pantalla: el cuadrado de los botones se
  // calculaba contra un ancho fijo de 392. En una pantalla donde, descontados
  // los márgenes, entraban 367, Flutter achicaba el cuadrado pero las cuentas
  // seguían usando 196 como medio en vez de 183, y los cuatro botones quedaban
  // trece puntos corridos a la derecha. Se veía a simple vista.
  testWidgets('los cuatro botones quedan centrados aunque sobre poco ancho',
      (WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(1185, 2565)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final tocados = <Destino>[];
    await tester.pumpWidget(MaterialApp(
      theme: Tema.datos,
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(14),
          child: PantallaInicio(
            progreso: Progreso(carpeta: () async => null),
            alElegir: tocados.add,
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    final medioDeLaPantalla = tester.view.physicalSize.width / 2 / 3;
    double medioDe(Destino destino) =>
        tester.getCenter(find.byIcon(destino.icono)).dx;

    for (final (izquierda, derecha) in const [
      (Destino.racconti, Destino.hablar),
      (Destino.gramatica, Destino.chat),
    ]) {
      expect(
        (medioDe(izquierda) + medioDe(derecha)) / 2,
        closeTo(medioDeLaPantalla, 0.5),
        reason: '${izquierda.name} y ${derecha.name} no quedaron centrados',
      );
    }
  });
}
