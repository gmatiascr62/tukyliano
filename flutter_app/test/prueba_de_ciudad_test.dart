// La prueba que cierra una ciudad.
//
// Es lo único de la app que se puede no pasar, así que lo que hay que
// cuidar es que reprobar sirva para algo: que no abra la ciudad
// siguiente, que no castigue perdiendo lo hecho, y que al repetirla las
// preguntas sean otras. Una prueba que se repite igual se aprueba de
// memoria a la tercera.

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tukyliano/logica/leccion.dart';
import 'package:tukyliano/modelos/percorso.dart';
import 'package:tukyliano/pantallas/pantalla_leccion.dart';
import 'package:tukyliano/tema.dart';

import 'util_pantalla.dart';
import 'voz_falsa.dart';

PalabraDeLeccion _p(String it, String es) =>
    PalabraDeLeccion(italiano: it, espanol: es);

const _pregunta = Pregunta(
  consigna: 'Completá',
  enunciado: 'Mi ___ Marco.',
  opciones: ['chiamo', 'chiami', 'chiama'],
  correcta: 'chiamo',
  porque: 'Con "io" el verbo termina en -o.',
);

final _dadas = [
  Leccion(
    id: 'u-1',
    titulo: 'Una',
    palabras: [
      _p('ciao', 'hola'),
      _p('grazie', 'gracias'),
      _p('prego', 'de nada'),
      _p('scusi', 'disculpe'),
    ],
    frases: [
      FraseDeLeccion(italiano: 'Ciao, grazie.', espanol: 'Hola, gracias.'),
    ],
    preguntas: const [_pregunta],
  ),
  Leccion(
    id: 'u-2',
    titulo: 'Dos',
    palabras: [
      _p('sono', 'soy'),
      _p('casa', 'casa'),
      _p('oggi', 'hoy'),
      _p('domani', 'mañana'),
    ],
    frases: [
      FraseDeLeccion(italiano: 'Sono a casa.', espanol: 'Estoy en casa.'),
    ],
  ),
];

const _prueba = Leccion(
  id: 'u-prueba',
  titulo: 'La prueba',
  esPrueba: true,
  paraAprobar: 6,
  cuantas: 8,
);

Future<void> _abrir(
  WidgetTester tester, {
  VoidCallback? alTerminar,
  int semilla = 3,
}) async {
  usarPantallaDeCelular(tester);
  await tester.pumpWidget(
    MaterialApp(
      theme: Tema.datos,
      home: Scaffold(
        body: PantallaLeccion(
          leccion: _prueba,
          antes: _dadas,
          voz: VozFalsa(),
          azar: Random(semilla),
          alTerminar: alTerminar,
          alSalir: () {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Contesta mal el paso que esté a la vista. Armar una frase se "contesta
/// mal" poniendo una sola ficha: alcanza para que no dé.
Future<void> _contestarMal(WidgetTester tester, Paso paso) async {
  switch (paso) {
    case ElegirTraduccion(:final opciones, :final correcta):
      await tester.tap(
        find.text(opciones.firstWhere((o) => o != correcta)).last,
      );
      await tester.pumpAndSettle();
    case Contestar(:final pregunta):
      await tester.tap(
        find
            .text(pregunta.opciones.firstWhere((o) => o != pregunta.correcta))
            .last,
      );
      await tester.pumpAndSettle();
    case ArmarLaFrase(:final fichas):
      await tester.tap(find.text(fichas.first).last);
      await tester.pumpAndSettle();
    default:
      break;
  }
}

void main() {
  test('la prueba pregunta, no enseña', () {
    final pasos = pasosDePrueba(_prueba, _dadas, Random(3));

    expect(pasos.whereType<MostrarPalabra>(), isEmpty);
    expect(pasos.whereType<MostrarExplicacion>(), isEmpty);
    expect(pasos.whereType<MostrarFrase>(), isEmpty);
    expect(pasos, everyElement(predicate(seContesta)));
  });

  test('mezcla los tres tipos: no son ocho palabras sueltas', () {
    // Sacadas de una bolsa sola, el azar da pruebas enteras de palabras:
    // aprobadas sin haber armado una frase. Por eso van por turnos.
    for (var semilla = 0; semilla < 20; semilla++) {
      final pasos = pasosDePrueba(_prueba, _dadas, Random(semilla));
      expect(pasos.whereType<ArmarLaFrase>(), isNotEmpty, reason: '$semilla');
      expect(pasos.whereType<Contestar>(), isNotEmpty, reason: '$semilla');
      expect(
        pasos.whereType<ElegirTraduccion>(),
        isNotEmpty,
        reason: '$semilla',
      );
    }
  });

  test('no pregunta más de lo que hay para preguntar', () {
    // Esta ciudad tiene 8 palabras + 2 frases + 1 escrita = 11, así que
    // las 8 salen. Con una ciudad chica, la prueba se achica sola en vez
    // de repetir preguntas.
    final chica = [
      Leccion(id: 'x', titulo: 'x', palabras: [_p('sì', 'sí')]),
    ];
    final pasos = pasosDePrueba(_prueba, chica, Random(1));
    expect(pasos.length, 1);
  });

  testWidgets('aprobada: avisa y la da por hecha', (tester) async {
    var termino = false;
    await _abrir(tester, alTerminar: () => termino = true);

    final pasos = pasosDePrueba(_prueba, _dadas, Random(3));
    await jugarHasta(tester, pasos, pasos.length);

    expect(find.text('¡Aprobaste!'), findsOneWidget);
    expect(
      find.text('${pasos.length} de ${pasos.length} bien'),
      findsOneWidget,
    );

    await botonDeAbajo(tester);
    expect(termino, isTrue);
  });

  testWidgets('reprobada: no se da por hecha y se puede repetir', (
    tester,
  ) async {
    var termino = false;
    await _abrir(tester, alTerminar: () => termino = true);

    final pasos = pasosDePrueba(_prueba, _dadas, Random(3));
    for (final paso in pasos) {
      await _contestarMal(tester, paso);
      await botonDeAbajo(tester);
      await botonDeAbajo(tester);
    }

    expect(find.text('Casi'), findsOneWidget);
    expect(find.text('0 de ${pasos.length} bien'), findsOneWidget);
    expect(find.textContaining('Hacen falta 6'), findsOneWidget);

    // El botón no la termina: la vuelve a empezar.
    expect(find.text('Terminar'), findsNothing);
    await tester.tap(find.text('Volver a intentar'));
    await tester.pumpAndSettle();

    expect(termino, isFalse);
    expect(find.text('Casi'), findsNothing);
    expect(find.text('Comprobar'), findsOneWidget);
  });
}
