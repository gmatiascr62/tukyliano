// Las tres pastillas de Escuchar.
//
// Lo que se prueba acá no es el contenido de cada una —eso lo prueban sus
// propios tests— sino que la pastilla lleve a donde dice, y que cambiar de
// una a otra arme la pantalla de nuevo en vez de quedarse con el estado de
// la anterior.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tukyliano/datos/repositorio_diccionario.dart';
import 'package:tukyliano/datos/repositorio_lecturas.dart';
import 'package:tukyliano/modelos/lectura.dart';
import 'package:tukyliano/pantallas/pantalla_escuchar.dart';
import 'package:tukyliano/pantallas/pantalla_lecturas.dart';
import 'package:tukyliano/tema.dart';

import 'descargas_falsas.dart';
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

  _elCatalogoDePinocchio();
}

/// El catálogo de Pinocchio, leído como lo lee la app.
///
/// No alcanza con que el archivo exista: tiene que tener los treinta y seis
/// capítulos, cada uno con su audio, su duración, su peso y su texto. Si
/// alguno viene vacío, en la app se ve una fila que no suena y no se sabe
/// por qué.
void _elCatalogoDePinocchio() {
  group('el catálogo de Pinocchio', () {
    late Lecturas catalogo;

    setUpAll(() async {
      // Con dart:io y no con rootBundle: en un archivo que además tiene
      // tests de widget, leer un asset con rootBundle no termina nunca
      // —el reloj es falso y esa espera nunca se resuelve— y el test se
      // cuelga doce minutos hasta que lo matan.
      catalogo = await RepositorioLecturas(
        leerAsset: (cual) async => File(cual).readAsStringSync(),
        archivo: QueSeEscucha.pinocchio.archivo,
        clave: QueSeEscucha.pinocchio.clave,
      ).cargar();
    });

    test('están los treinta y seis', () {
      expect(catalogo.lecturas.length, 36);
    });

    test('cada uno tiene todo lo que hace falta para sonar', () {
      for (final capitulo in catalogo.lecturas) {
        expect(capitulo.archivo, endsWith('.mp3'), reason: capitulo.titulo);
        expect(capitulo.segundos, greaterThan(0), reason: capitulo.titulo);
        expect(capitulo.bytes, greaterThan(0), reason: capitulo.titulo);
        expect(capitulo.renglones, isNotEmpty, reason: capitulo.titulo);
        expect(capitulo.titulo.trim(), isNotEmpty);
      }
    });

    test('los títulos dicen de qué va el capítulo, no el número romano', () {
      // Salían "II.", "III." cuando el título se sacaba del primer párrafo
      // de la página. Ahora salen del índice del libro.
      for (final capitulo in catalogo.lecturas) {
        expect(capitulo.titulo.length, greaterThan(12),
            reason: capitulo.titulo);
      }
      expect(catalogo.lecturas[3].titulo, contains('Grillo-parlante'));
    });

    test('se baja de donde dice el catálogo, y lo firma Collodi', () {
      expect(catalogo.base, contains('pinocchio-1'));
      expect(catalogo.deQuien, contains('Collodi'));
      expect(catalogo.donde(catalogo.lecturas.first), startsWith('https://'));
    });

    testWidgets('no se ofrece bajar los 131 MB de un saque',
        (tester) async {
      // Con las fábulas, "bajar todas" son 18 MB y es una comodidad. Con
      // Pinocchio son 131, y un botón que con un toque se lleva 131 MB de
      // datos no es una comodidad: es una trampa para el que lo toca en la
      // calle creyendo que es como el otro.
      usarPantallaDeCelular(tester);
      await tester.pumpWidget(MaterialApp(
        theme: Tema.datos,
        home: Scaffold(
          body: PantallaLecturas(
            repositorio: RepositorioLecturas(
              leerAsset: (cual) async => File(cual).readAsStringSync(),
              archivo: QueSeEscucha.pinocchio.archivo,
              clave: QueSeEscucha.pinocchio.clave,
            ),
            descargas: DescargasFalsas(),
            reproductor: ReproductorFalso(),
            diccionario: RepositorioDiccionario(
              leerAsset: (_) async => '{"version":1,"it":{},"es":{}}',
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('Bajar todas'), findsNothing);
      // Y cada capítulo se sigue pudiendo bajar al tocarlo.
      expect(find.textContaining('Come andò che maestro Ciliegia'),
          findsOneWidget);
    });

    test('el texto está partido en oraciones, no en párrafos', () {
      // En prosa un párrafo dura entre medio minuto y un minuto, y un
      // renglón iluminado de un minuto no dice dónde va el audio.
      final renglones =
          catalogo.lecturas.fold<int>(0, (n, c) => n + c.renglones.length);
      final segundos =
          catalogo.lecturas.fold<int>(0, (n, c) => n + c.segundos);
      expect(segundos / renglones, lessThan(12));
    });
  });
}
