// Una lección de punta a punta.
//
// El test más importante de este archivo es el que la hace entera: toca
// Seguir y Comprobar hasta el final, contestando siempre bien. Si algún
// paso deja la pantalla sin salida —un botón apagado que no se vuelve a
// prender— el test se cuelga ahí en vez de terminar, y eso es exactamente
// lo que hay que cazar: una lección de la que no se puede salir es peor
// que una que no existe.

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tukyliano/logica/leccion.dart';
import 'package:tukyliano/modelos/percorso.dart';
import 'package:tukyliano/pantallas/pantalla_leccion.dart';
import 'package:tukyliano/tema.dart';

import 'util_pantalla.dart';
import 'voz_falsa.dart';

const _leccion = Leccion(
  id: 'palermo-1',
  titulo: 'Il gatto è in cucina',
  palabras: [
    PalabraDeLeccion(italiano: 'il', espanol: 'el'),
    PalabraDeLeccion(italiano: 'gatto', espanol: 'gato'),
    PalabraDeLeccion(italiano: 'cucina', espanol: 'cocina'),
    PalabraDeLeccion(italiano: 'casa', espanol: 'casa'),
  ],
  frases: [
    FraseDeLeccion(
      italiano: 'Il gatto è in cucina.',
      espanol: 'El gato está en la cocina.',
    ),
  ],
);

Future<VozFalsa> _abrir(
  WidgetTester tester, {
  VoidCallback? alTerminar,
  VoidCallback? alSalir,
  int semilla = 7,
}) async {
  usarPantallaDeCelular(tester);
  final voz = VozFalsa();
  await tester.pumpWidget(
    MaterialApp(
      theme: Tema.datos,
      home: Scaffold(
        body: PantallaLeccion(
          leccion: _leccion,
          voz: voz,
          azar: Random(semilla),
          alTerminar: alTerminar,
          alSalir: alSalir,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return voz;
}

void main() {
  testWidgets('arranca mostrando la primera palabra, no preguntándola', (
    tester,
  ) async {
    await _abrir(tester);

    expect(find.text('Palabra nueva'), findsOneWidget);
    expect(find.text('il'), findsOneWidget);
    expect(find.text('el'), findsOneWidget);
    expect(find.text('Seguir'), findsOneWidget);
  });

  testWidgets('la lección se puede hacer entera y avisa al terminar', (
    tester,
  ) async {
    var termino = false;
    await _abrir(tester, alTerminar: () => termino = true);

    final pasos = pasosDe(_leccion, azar: Random(7));
    await jugarHasta(tester, pasos, pasos.length);

    expect(find.text('¡Lección terminada!'), findsOneWidget);
    final cuantasSeContestan = pasos.where(seContesta).length;
    expect(
      find.text('$cuantasSeContestan de $cuantasSeContestan bien'),
      findsOneWidget,
    );

    expect(termino, isFalse, reason: 'todavía no se apretó Terminar');
    await botonDeAbajo(tester);
    expect(termino, isTrue);
  });

  testWidgets('no se puede comprobar sin haber elegido nada', (tester) async {
    await _abrir(tester);

    // Hasta la primera pregunta.
    final pasos = pasosDe(_leccion, azar: Random(7));
    for (final paso in pasos) {
      if (paso is ElegirTraduccion) break;
      await botonDeAbajo(tester);
    }

    expect(find.text('Comprobar'), findsOneWidget);
    final boton = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(boton.onPressed, isNull);
  });

  testWidgets('equivocarse muestra cuál era, y deja seguir igual', (
    tester,
  ) async {
    await _abrir(tester);

    final pasos = pasosDe(_leccion, azar: Random(7));
    late ElegirTraduccion pregunta;
    for (final paso in pasos) {
      if (paso is ElegirTraduccion) {
        pregunta = paso;
        break;
      }
      await botonDeAbajo(tester);
    }

    final mala = pregunta.opciones.firstWhere((o) => o != pregunta.correcta);
    await tester.tap(find.text(mala).last);
    await tester.pumpAndSettle();
    await botonDeAbajo(tester);

    expect(find.text('Era: ${pregunta.correcta}'), findsOneWidget);
    // Y se sigue: equivocarse no es un callejón sin salida.
    expect(find.text('Seguir'), findsOneWidget);
    await botonDeAbajo(tester);
    expect(find.text('Era: ${pregunta.correcta}'), findsNothing);
  });

  testWidgets('las que se erraron no se cuentan como bien', (tester) async {
    await _abrir(tester);

    final pasos = pasosDe(_leccion, azar: Random(7));
    var erradas = 0;
    var contestadas = 0;
    for (final paso in pasos) {
      if (paso is ElegirTraduccion) {
        contestadas++;
        erradas++;
        await tester.tap(
          find.text(paso.opciones.firstWhere((o) => o != paso.correcta)).last,
        );
        await tester.pumpAndSettle();
        await botonDeAbajo(tester);
        await botonDeAbajo(tester);
        continue;
      }
      if (seContesta(paso)) contestadas++;
      await contestarBien(tester, paso);
      await botonDeAbajo(tester);
      if (seContesta(paso)) await botonDeAbajo(tester);
    }

    expect(
      find.text('${contestadas - erradas} de $contestadas bien'),
      findsOneWidget,
    );
  });

  testWidgets('la cruz sale sin dar la lección por hecha', (tester) async {
    var salio = false;
    var termino = false;
    await _abrir(
      tester,
      alSalir: () => salio = true,
      alTerminar: () => termino = true,
    );

    await tester.tap(find.byTooltip('Salir'));
    await tester.pumpAndSettle();

    expect(salio, isTrue);
    expect(termino, isFalse);
  });

  testWidgets('dice la palabra en voz alta y la repite si se la pide', (
    tester,
  ) async {
    final voz = await _abrir(tester);

    expect(voz.dicho, ['il'], reason: 'la primera se dice sola al aparecer');

    await tester.tap(find.text('Escuchar'));
    await tester.pumpAndSettle();
    expect(voz.dicho, ['il', 'il']);
  });
}
