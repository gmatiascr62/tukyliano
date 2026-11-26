// Los racconti del camino están cerrados hasta aprobar su ciudad.
//
// Son el premio: leer el cuento de Olbia antes de aprobar Olbia no sería
// un premio, sería un examen con palabras que todavía no se dieron. Y al
// revés, aprobar sin enterarse de lo que se ganó es media fiesta, así
// que el cartel del final lo dice.

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tukyliano/datos/progreso.dart';
import 'package:tukyliano/logica/leccion.dart';
import 'package:tukyliano/main.dart';
import 'package:tukyliano/modelos/destino.dart';
import 'package:tukyliano/modelos/percorso.dart';
import 'package:tukyliano/modelos/racconto.dart';
import 'package:tukyliano/pantallas/pantalla_leccion.dart';
import 'package:tukyliano/tema.dart';

import 'util_pantalla.dart';
import 'voz_falsa.dart';

Map<String, dynamic> _leer(String archivo) =>
    jsonDecode(File(archivo).readAsStringSync()) as Map<String, dynamic>;

Percorso get _camino => Percorso.desdeJson(_leer('assets/percorso.json'));
DatosRacconti get _racconti =>
    DatosRacconti.desdeJson(_leer('assets/racconti.json'));

void main() {
  test('cada ciudad del nivel 1 reclama un cuento que existe', () {
    final cuentos = {for (final o in _racconti.obras) o.id};
    final conCuento = _camino.ciudades.where((c) => c.racconto.isNotEmpty);

    expect(conCuento.map((c) => c.id), [
      'olbia',
      'cagliari',
    ], reason: 'hoy son las dos de Cerdeña');
    for (final ciudad in conCuento) {
      expect(
        cuentos,
        contains(ciudad.racconto),
        reason:
            '${ciudad.id} reclama "${ciudad.racconto}", que no está '
            'en el catálogo',
      );
    }
  });

  test('los cuentos del camino tienen trece frases y sus cuadros', () {
    for (final ciudad in _camino.ciudades.where((c) => c.racconto.isNotEmpty)) {
      final obra = _racconti.obras.firstWhere((o) => o.id == ciudad.racconto);
      final cuento = obra.capitulos.single;

      expect(cuento.lineas.length, 13, reason: ciudad.id);
      expect(cuento.foto, isNotEmpty, reason: '${ciudad.id}: sin fotos');

      // Cada cuadro nombrado tiene que existir como archivo: una foto que
      // falta no rompe nada, pero el cuento se lee sin dibujos y nadie se
      // entera de por qué.
      final nombrados = <String>{
        cuento.fotoTapa,
        cuento.fotoPortada,
        for (var i = 0; i < cuento.lineas.length; i++)
          if (cuento.fotoDeLinea(i).isNotEmpty) cuento.fotoDeLinea(i),
      };
      for (final foto in nombrados) {
        expect(
          File('assets/racconti/$foto.jpg').existsSync(),
          isTrue,
          reason: 'falta assets/racconti/$foto.jpg',
        );
      }
      expect(
        nombrados.length,
        greaterThanOrEqualTo(4),
        reason: '${ciudad.id}: tapa, portada y al menos dos cuadros',
      );
    }
  });

  testWidgets('en Racconti, el cuento de Olbia está cerrado al empezar', (
    tester,
  ) async {
    usarPantallaDeCelular(tester);
    await tester.pumpWidget(
      TukylianoApp(
        progreso: Progreso(carpeta: () async => null),
        camino: caminoDePrueba(),
        racconti: raccontiDePrueba(),
        // Sin esto la pantalla se queda en "Cargando cuentos...": espera
        // a que la voz del sistema esté lista, y en un test no hay.
        voz: VozFalsa(),
      ),
    );
    await tester.pumpAndSettle();

    await entrarA(tester, Destino.racconti);

    expect(find.text('Un giorno a Olbia'), findsOneWidget);
    expect(
      find.textContaining('Se abre al pasar la prueba de Olbia'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.lock_rounded), findsWidgets);

    // Y tocarlo no lo abre.
    await tester.tap(find.text('Un giorno a Olbia'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Se abre al pasar la prueba de Olbia'),
      findsOneWidget,
    );
  });

  testWidgets('aprobada la prueba, el cartel dice qué cuento se abrió', (
    tester,
  ) async {
    const prueba = Leccion(
      id: 'olbia-prueba',
      titulo: 'La prueba de Olbia',
      esPrueba: true,
      paraAprobar: 1,
      cuantas: 2,
    );
    final dadas = [
      const Leccion(
        id: 'olbia-1',
        titulo: 'x',
        palabras: [
          PalabraDeLeccion(italiano: 'ciao', espanol: 'hola'),
          PalabraDeLeccion(italiano: 'grazie', espanol: 'gracias'),
        ],
      ),
    ];

    usarPantallaDeCelular(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: Tema.datos,
        home: Scaffold(
          body: PantallaLeccion(
            leccion: prueba,
            antes: dadas,
            abre: 'Un giorno a Olbia',
            voz: VozFalsa(),
            azar: Random(2),
            alSalir: () {},
            alTerminar: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final pasos = pasosDePrueba(prueba, dadas, Random(2));
    await jugarHasta(tester, pasos, pasos.length);

    expect(find.text('¡Aprobaste!'), findsOneWidget);
    expect(find.text('Se abrió un racconto'), findsOneWidget);
    expect(find.text('Un giorno a Olbia'), findsOneWidget);
  });
}
