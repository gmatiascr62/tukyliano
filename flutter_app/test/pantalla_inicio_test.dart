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

  group('en cualquier celular', () {
    /// Los tamaños que importan, en puntos: el Poco F7 de Matías, el celular
    /// donde se vio el problema, uno todavía más bajo y uno grande.
    const celulares = [
      ('Poco F7', Size(395, 855)),
      ('uno de 360 x 720', Size(360, 720)),
      ('uno bajito de 360 x 640', Size(360, 640)),
      ('uno grande de 412 x 915', Size(412, 915)),
    ];

    for (final (nombre, tamano) in celulares) {
      testWidgets('los botones no se salen de su lugar en $nombre',
          (tester) async {
        tester.view.physicalSize = tamano;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(MaterialApp(
          theme: Tema.datos,
          home: Scaffold(
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: PantallaInicio(
                  progreso: await _conAciertos(18),
                  alElegir: (_) {},
                ),
              ),
            ),
          ),
        ));
        await tester.pumpAndSettle();

        // Lo que pasaba en el celular de 360 x 720: la composición se dibujaba
        // siempre al mismo tamaño sin mirar el alto que le quedaba, y como el
        // Stack va con Clip.none, los de arriba se montaban sobre la tarjeta
        // de la semana y los de abajo sobre la barra del podcast.
        final caja = tester.getRect(find.byKey(const ValueKey('los-botones')));

        for (final destino in const [
          Destino.racconti,
          Destino.hablar,
          Destino.gramatica,
          Destino.chat,
        ]) {
          final boton = tester.getRect(find.byKey(ValueKey(destino)));
          expect(
            boton.top,
            greaterThanOrEqualTo(caja.top - 0.5),
            reason: '$destino se sale por arriba en $nombre',
          );
          expect(
            boton.bottom,
            lessThanOrEqualTo(caja.bottom + 0.5),
            reason: '$destino se sale por abajo en $nombre',
          );
          expect(
            boton.left,
            greaterThanOrEqualTo(caja.left - 0.5),
            reason: '$destino se sale por la izquierda en $nombre',
          );
          expect(
            boton.right,
            lessThanOrEqualTo(caja.right + 0.5),
            reason: '$destino se sale por la derecha en $nombre',
          );
        }
      });
    }
  });
}
