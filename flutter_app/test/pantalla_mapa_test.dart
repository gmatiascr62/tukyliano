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

Ciudad _ciudad(
  String id, {
  List<Leccion> lecciones = const [],
  double x = 0.5,
  double y = 0.5,
}) => Ciudad(
  id: id,
  nombre: id[0].toUpperCase() + id.substring(1),
  icono: '',
  x: x,
  y: y,
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

Future<void> _abrir(
  WidgetTester tester,
  List<Ciudad> ciudades, {
  Progreso? progreso,
  void Function(Ciudad)? alElegir,
}) async {
  usarPantallaDeCelular(tester);
  await tester.pumpWidget(
    MaterialApp(
      theme: Tema.datos,
      home: Scaffold(
        body: PantallaMapa(
          ciudades: ciudades,
          progreso: progreso ?? _progresoCon(const []),
          alElegir: alElegir,
        ),
      ),
    ),
  );
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
      expect(
        donde.left,
        closeTo(-43.1, 0.2),
        reason: 'el dibujo empieza antes del borde izquierdo',
      );
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
    testWidgets('se muestran todas, también las que no tienen contenido', (
      tester,
    ) async {
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
      await _abrir(tester, [
        _ciudad('palermo', lecciones: _conLecciones),
        _ciudad('napoli'),
      ], alElegir: (ciudad) => elegidas.add(ciudad.id));

      await tester.tap(find.text('Napoli'));
      await tester.pump();
      expect(elegidas, isEmpty, reason: 'Napoli todavía no tiene contenido');

      await tester.tap(find.text('Palermo'));
      await tester.pump();
      expect(elegidas, ['palermo']);
    });

    testWidgets('no hay tarjeta abajo: la ciudad encendida ya lo dice', (
      tester,
    ) async {
      // La sacó Matías: "creo que es innecesario". Repetía lo que el mapa
      // ya muestra y tapaba media Sicilia. El test queda para que no
      // vuelva sola.
      await _abrir(tester, [
        _ciudad('palermo', lecciones: _conLecciones),
      ], progreso: _progresoCon(['palermo-1']));

      expect(find.textContaining('Ha fame'), findsNothing);
      expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);
    });
  });

  group('el perrito', () {
    // Se para al lado de la ciudad que toca y se desliza a la siguiente
    // cuando esa se termina. Lo que se mide acá es **dónde queda**, que es
    // justo lo que a ojo no se ve: en una foto chiquita un perrito 20
    // puntos corrido parece bien puesto igual.
    const pantalla = Size(420, 900);
    final mapa = dondeEntraElMapa(pantalla);
    double bordeIzquierdoDe(double x) =>
        mapa.left + x * mapa.width - ladoDeLaChapa / 2;
    double baseDe(double y) =>
        mapa.top + y * mapa.height - loQueSubeLaChapa + ladoDeLaChapa;

    AnimatedPositioned donde(WidgetTester tester) =>
        tester.widget<AnimatedPositioned>(find.byType(AnimatedPositioned));

    final dosCiudades = [
      _ciudad('palermo', lecciones: _conLecciones, x: 0.2, y: 0.3),
      _ciudad(
        'napoli',
        lecciones: [const Leccion(id: 'napoli-1', titulo: 'Due caffè')],
        x: 0.8,
        y: 0.7,
      ),
    ];

    testWidgets('está parado al lado de la ciudad que toca, no encima', (
      tester,
    ) async {
      await _abrir(tester, dosCiudades);
      final perrito = donde(tester);

      // Pegado al borde izquierdo de la chapita, sin pisarla.
      final aLaDerechaDelPerrito = perrito.left! + anchoDelPerrito;
      expect(aLaDerechaDelPerrito, lessThanOrEqualTo(bordeIzquierdoDe(0.2)));
      expect(aLaDerechaDelPerrito, greaterThan(bordeIzquierdoDe(0.2) - 8));

      // Y apoyado en la base de la chapita, para que no quede flotando.
      expect(perrito.top! + altoDelPerrito, closeTo(baseDe(0.3), 1));

      // Más chico que la chapita: la pedida de Matías.
      expect(altoDelPerrito, lessThan(ladoDeLaChapa));
    });

    testWidgets(
      'se corre a la ciudad siguiente cuando se termina la de ahora',
      (tester) async {
        await _abrir(
          tester,
          dosCiudades,
          progreso: _progresoCon(['palermo-1', 'palermo-2']),
        );
        final perrito = donde(tester);

        expect(
          perrito.left! + anchoDelPerrito,
          closeTo(bordeIzquierdoDe(0.8), 8),
          reason: 'Palermo está hecha: el perrito ya tiene que estar en Napoli',
        );
        expect(perrito.top! + altoDelPerrito, closeTo(baseDe(0.7), 1));
      },
    );

    testWidgets('sin ciudades no se cae la pantalla', (tester) async {
      // Mientras el camino carga, la lista viene vacía. La primera versión
      // buscaba igual la ciudad del perrito y se caía entera, con la
      // pantalla en blanco: lo agarraron los tests de las otras secciones,
      // que abren la app sin camino. Queda acá para que no vuelva.
      await _abrir(tester, const []);

      expect(tester.takeException(), isNull);
      expect(find.byType(AnimatedPositioned), findsNothing);
    });

    testWidgets('con todo terminado se queda en la última, no desaparece', (
      tester,
    ) async {
      await _abrir(
        tester,
        dosCiudades,
        progreso: _progresoCon(['palermo-1', 'palermo-2', 'napoli-1']),
      );

      expect(
        donde(tester).left! + anchoDelPerrito,
        closeTo(bordeIzquierdoDe(0.8), 8),
      );
    });
  });
}
