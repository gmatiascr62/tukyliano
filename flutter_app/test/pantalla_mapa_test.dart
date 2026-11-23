// El mapa, y sobre todo la cuenta de dónde va cada ciudad.
//
// El mapa tapa toda la pantalla y se recorta de los costados, así que una
// ciudad al 61% NO está al 61% de la pantalla: está al 61% del dibujo, que
// empieza antes del borde izquierdo. Armando la maqueta puse los
// porcentajes sobre la pantalla y quedaron todas corridas —Nápoles terminó
// flotando en el agua—, y encima miré la foto y dije que estaba bien.
//
// Por eso la cuenta tiene su propio test con números a mano: es el tipo de
// error que a ojo no se ve.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tukyliano/datos/progreso.dart';
import 'package:tukyliano/modelos/percorso.dart';
import 'package:tukyliano/pantallas/pantalla_mapa.dart';
import 'package:tukyliano/tema.dart';

import 'util_pantalla.dart';

Ciudad _ciudad(String id, {List<Leccion> lecciones = const []}) => Ciudad(
      id: id,
      nombre: id[0].toUpperCase() + id.substring(1),
      icono: '',
      x: 0.5,
      y: 0.5,
      lecciones: lecciones,
    );

final _conLecciones = [
  const Leccion(id: 'palermo-1', titulo: 'Il gatto è in cucina'),
  const Leccion(id: 'palermo-2', titulo: 'Ha fame'),
];

Progreso _progresoCon(List<String> hechas) {
  final progreso = Progreso(carpeta: () async => null);
  for (final id in hechas) {
    progreso.termino(id);
  }
  return progreso;
}

Future<void> _abrir(WidgetTester tester, List<Ciudad> ciudades,
    {Progreso? progreso, void Function(Ciudad)? alElegir}) async {
  usarPantallaDeCelular(tester);
  await tester.pumpWidget(MaterialApp(
    theme: Tema.datos,
    home: Scaffold(
      body: PantallaMapa(
        ciudades: ciudades,
        progreso: progreso ?? _progresoCon(const []),
        alElegir: alElegir,
      ),
    ),
  ));
  await tester.pump();
}

void main() {
  group('dónde entra el mapa', () {
    test('un celular angosto recorta los costados, no el alto', () {
      // Los números son los del Poco F7 en puntos y los del dibujo:
      // 941 de ancho por 1672 de alto.
      final donde = dondeEntraElMapa(const Size(395, 855));

      expect(donde.height, 855, reason: 'tiene que llenar el alto');
      expect(donde.width, closeTo(481.2, 0.2));
      expect(donde.left, closeTo(-43.1, 0.2),
          reason: 'el dibujo empieza antes del borde izquierdo');
      expect(donde.top, 0);
    });

    test('una ciudad al 61% no cae al 61% de la pantalla', () {
      // Esta es la diferencia que me comí en la maqueta: 55 puntos.
      final donde = dondeEntraElMapa(const Size(395, 855));
      final enElMapa = donde.left + 0.61 * donde.width;
      final enLaPantalla = 0.61 * 395;

      expect(enElMapa, closeTo(250.4, 0.5));
      expect(enLaPantalla, closeTo(241.0, 0.5));
      expect((enElMapa - enLaPantalla).abs(), greaterThan(9));
    });

    test('una pantalla más ancha que el dibujo recorta arriba y abajo', () {
      final donde = dondeEntraElMapa(const Size(900, 500));

      expect(donde.width, 900);
      expect(donde.height, closeTo(900 / (941 / 1672), 0.5));
      expect(donde.left, 0);
      expect(donde.top, lessThan(0));
    });
  });

  group('las ciudades', () {
    testWidgets('se muestran todas, también las que no tienen contenido',
        (tester) async {
      await _abrir(tester, [
        _ciudad('palermo', lecciones: _conLecciones),
        _ciudad('napoli'),
        _ciudad('roma'),
      ]);

      // Italia entera desde el primer día: un mapa con una sola ciudad no
      // dice cuánto camino hay.
      expect(find.text('Palermo'), findsOneWidget);
      expect(find.text('Napoli'), findsOneWidget);
      expect(find.text('Roma'), findsOneWidget);
    });

    testWidgets('sólo se puede entrar a la que está abierta', (tester) async {
      final elegidas = <String>[];
      await _abrir(
        tester,
        [
          _ciudad('palermo', lecciones: _conLecciones),
          _ciudad('napoli'),
        ],
        alElegir: (ciudad) => elegidas.add(ciudad.id),
      );

      await tester.tap(find.text('Napoli'));
      await tester.pump();
      expect(elegidas, isEmpty, reason: 'Napoli todavía no tiene contenido');

      await tester.tap(find.text('Palermo'));
      await tester.pump();
      expect(elegidas, ['palermo']);
    });

    testWidgets('la tarjeta de abajo dice qué lección toca', (tester) async {
      await _abrir(
        tester,
        [_ciudad('palermo', lecciones: _conLecciones)],
        progreso: _progresoCon(['palermo-1']),
      );

      expect(find.text('Palermo · Ha fame'), findsOneWidget);
    });

    testWidgets('terminada la ciudad, no queda tarjeta', (tester) async {
      // Con todo hecho y sin ciudad siguiente, no hay nada para ofrecer.
      await _abrir(
        tester,
        [_ciudad('palermo', lecciones: _conLecciones)],
        progreso: _progresoCon(['palermo-1', 'palermo-2']),
      );

      expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);
    });
  });
}
