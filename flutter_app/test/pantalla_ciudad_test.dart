// La ciudad por dentro.
//
// Lo que hay que cuidar acá es que haya UNA sola cosa para apretar. El
// camino existe porque el que no sabe nada se pierde entre seis puertas; si
// adentro de la ciudad vuelve a haber tres botones iguales, no se arregló
// nada, se movió de lugar.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tukyliano/datos/progreso.dart';
import 'package:tukyliano/modelos/destino.dart';
import 'package:tukyliano/modelos/percorso.dart';
import 'package:tukyliano/pantallas/pantalla_ciudad.dart';
import 'package:tukyliano/tema.dart';

import 'util_pantalla.dart';

Leccion _leccion(String id, String titulo, {bool prueba = false}) => Leccion(
  id: id,
  titulo: titulo,
  deQueVa: 'de qué va',
  palabras: prueba
      ? const []
      : const [PalabraDeLeccion(italiano: 'gatto', espanol: 'gato')],
  esPrueba: prueba,
);

final _palermo = Ciudad(
  id: 'palermo',
  nombre: 'Palermo',
  subtitulo: 'las primeras palabras',
  icono: '',
  x: 0.6,
  y: 0.75,
  lecciones: [
    _leccion('p1', 'Il gatto è in cucina'),
    _leccion('p2', 'Ha fame'),
    _leccion('p3', 'Sul tavolo'),
    _leccion('pz', 'La prueba de Palermo', prueba: true),
  ],
);

/// Un progreso que no toca el disco, con unas lecciones ya hechas.
Progreso _progresoCon(List<String> hechas) {
  final progreso = Progreso(carpeta: () async => null);
  for (final id in hechas) {
    progreso.termino(id);
  }
  return progreso;
}

Future<void> _abrir(
  WidgetTester tester,
  Progreso progreso, {
  void Function(Leccion)? alEmpezar,
  void Function(Destino)? alIrA,
}) async {
  usarPantallaDeCelular(tester);
  await tester.pumpWidget(
    MaterialApp(
      theme: Tema.datos,
      home: Scaffold(
        body: PantallaCiudad(
          ciudad: _palermo,
          progreso: progreso,
          alEmpezar: alEmpezar,
          alIrA: alIrA,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('hay un solo botón de Empezar, en la lección que toca', (
    tester,
  ) async {
    await _abrir(tester, _progresoCon(['p1']));

    expect(find.text('Empezar'), findsOneWidget);

    // Y está en la segunda, que es la primera sin hacer.
    final caja = find.ancestor(
      of: find.text('Empezar'),
      matching: find.byType(Column),
    );
    expect(
      find.descendant(of: caja.last, matching: find.text('Ha fame')),
      findsOneWidget,
    );
  });

  testWidgets('las hechas muestran el tilde y no se pueden apretar', (
    tester,
  ) async {
    await _abrir(tester, _progresoCon(['p1', 'p2']));

    expect(find.byIcon(Icons.check_circle_rounded), findsNWidgets(2));
    expect(find.text('Empezar'), findsOneWidget);
  });

  testWidgets('el contador no cuenta la prueba', (tester) async {
    // Son cuatro lecciones pero tres de hacer: la prueba es el final, no
    // un escalón más. Si contara, el camino nunca llegaría al 100%.
    await _abrir(tester, _progresoCon(['p1']));

    expect(find.text('1 de 3'), findsOneWidget);
  });

  testWidgets('apretar Empezar avisa cuál lección es', (tester) async {
    Leccion? pedida;
    await _abrir(
      tester,
      _progresoCon(const []),
      alEmpezar: (leccion) => pedida = leccion,
    );

    await tester.tap(find.text('Empezar'));
    await tester.pumpAndSettle();

    expect(pedida?.id, 'p1');
  });

  testWidgets('terminada la última, no queda nada para apretar', (
    tester,
  ) async {
    await _abrir(tester, _progresoCon(['p1', 'p2', 'p3', 'pz']));

    expect(find.text('Empezar'), findsNothing);
    expect(find.text('3 de 3'), findsOneWidget);
  });

  testWidgets('gramática y hablar están acá, abajo de todo y chiquitas', (
    tester,
  ) async {
    // Son las dos que Matías sacó del mapa. Tienen que terminar en algún
    // lado, y el lado es este.
    Destino? pedido;
    await _abrir(
      tester,
      _progresoCon(const []),
      alIrA: (destino) => pedido = destino,
    );

    for (final destino in paraPracticarMas) {
      await tester.scrollUntilVisible(find.text(destino.etiqueta), 150);
      expect(find.text(destino.etiqueta), findsOneWidget, reason: destino.name);
    }
    expect(find.text('Practicá más'), findsOneWidget);

    await tester.tap(find.text(Destino.gramatica.etiqueta));
    await tester.pumpAndSettle();
    expect(pedido, Destino.gramatica);
  });

  testWidgets('abajo de todo de verdad: después de la última lección', (
    tester,
  ) async {
    // Si "practicá más" quedara arriba de la fila sería lo primero que se
    // ve al entrar, o sea volvería a ser el menú del que el camino saca.
    await _abrir(tester, _progresoCon(const []), alIrA: (_) {});

    await tester.scrollUntilVisible(find.text('Practicá más'), 150);
    expect(
      tester.getTopLeft(find.text('Practicá más')).dy,
      greaterThan(tester.getTopLeft(find.text('La prueba de Palermo')).dy),
    );
  });
}
