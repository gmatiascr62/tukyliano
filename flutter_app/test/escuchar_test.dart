// Las tres pastillas de Escuchar.
//
// Lo que se prueba acá no es el contenido de cada una —eso lo prueban sus
// propios tests— sino que la pastilla lleve a donde dice, y que cambiar de
// una a otra arme la pantalla de nuevo en vez de quedarse con el estado de
// la anterior.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tukyliano/pantallas/pantalla_escuchar.dart';
import 'package:tukyliano/tema.dart';

import 'reproductor_falso.dart';
import 'util_pantalla.dart';

Future<void> _abrir(WidgetTester tester, {QueSeEscucha? empezarEn}) async {
  usarPantallaDeCelular(tester);
  await tester.pumpWidget(MaterialApp(
    theme: Tema.datos,
    home: Scaffold(
      body: PantallaEscuchar(
        reproductor: ReproductorFalso(),
        empezarEn: empezarEn ?? QueSeEscucha.podcast,
      ),
    ),
  ));
  await tester.pump();
}

void main() {
  testWidgets('están las tres y se ven', (tester) async {
    await _abrir(tester);

    for (final cual in QueSeEscucha.values) {
      expect(find.text(cual.nombre), findsOneWidget, reason: cual.nombre);
    }
  });

  testWidgets('cada lectura sabe de qué catálogo sale', (tester) async {
    // Es lo único que las distingue: la misma pantalla con otro archivo.
    // Si estos dos se cruzan, Pinocchio muestra las fábulas y nadie se
    // entera hasta abrirlo.
    expect(QueSeEscucha.favole.archivo, 'assets/favole.json');
    expect(QueSeEscucha.favole.clave, 'favole');
    expect(QueSeEscucha.pinocchio.archivo, 'assets/pinocchio.json');
    expect(QueSeEscucha.pinocchio.clave, 'capitulos');

    // El podcast no es una lectura: sus episodios vienen de otro lado.
    expect(QueSeEscucha.podcast.esLectura, isFalse);
    expect(QueSeEscucha.favole.esLectura, isTrue);
    expect(QueSeEscucha.pinocchio.esLectura, isTrue);
  });

  testWidgets('se puede entrar derecho a Pinocchio', (tester) async {
    await _abrir(tester, empezarEn: QueSeEscucha.pinocchio);
    await tester.pump();

    // La pantalla de lecturas se armó con el catálogo de Pinocchio.
    expect(find.byKey(const ValueKey('pinocchio')), findsOneWidget);
  });

  testWidgets('cambiar de pastilla arma la pantalla de nuevo', (tester) async {
    // Con la misma key, Flutter reusaría el estado y la lista de Pinocchio
    // arrancaría mostrando lo que quedó de las fábulas.
    await _abrir(tester, empezarEn: QueSeEscucha.favole);
    await tester.pump();
    expect(find.byKey(const ValueKey('favole')), findsOneWidget);

    await tester.tap(find.text('Pinocchio'));
    await tester.pump();

    expect(find.byKey(const ValueKey('pinocchio')), findsOneWidget);
    expect(find.byKey(const ValueKey('favole')), findsNothing);
  });
}
