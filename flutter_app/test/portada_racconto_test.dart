import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tukyliano/tema.dart';
import 'package:tukyliano/widgets/portada_racconto.dart';

Future<void> _mostrar(WidgetTester tester, Widget widget) =>
    tester.pumpWidget(MaterialApp(
      theme: Tema.datos,
      home: Scaffold(body: Center(child: widget)),
    ));

void main() {
  group('el catálogo', () {
    test('cada portada del catálogo tiene su dibujo', () {
      for (final (nombre, portada) in portadas.entries.map((e) => (e.key, e.value))) {
        expect(Dibujo.values, contains(portada.dibujo), reason: nombre);
      }
    });

    test('una portada que esta versión no conoce usa la de por defecto', () {
      // Un cuento nuevo puede pedir un dibujo que todavía no existe en el APK
      // instalado: tiene que verse bien igual, no romperse.
      expect(portadaDe('todavia-no-existe'), portadaPorDefecto);
      expect(portadaDe(''), portadaPorDefecto);
    });

    test('las que sí conoce devuelven la suya', () {
      expect(portadaDe('mare').dibujo, Dibujo.mare);
      expect(portadaDe('mistero').dibujo, Dibujo.villa);
    });

    test('no hay dos portadas con el mismo dibujo y color', () {
      // Dos cuentos seguidos con la misma tapa se leerían como el mismo.
      final vistas = portadas.values
          .map((p) => '${p.dibujo}-${p.color.toARGB32()}')
          .toList();

      expect(vistas.toSet().length, vistas.length);
    });
  });

  group('el cuadradito', () {
    testWidgets('dibuja la portada que le toca al cuento', (tester) async {
      await _mostrar(tester, const PortadaRacconto(imagen: 'pizza'));

      final pintor = tester
          .widget<CustomPaint>(find.byType(CustomPaint).last)
          .painter;
      expect(pintor, isA<DibujoPortada>());
      expect((pintor! as DibujoPortada).dibujo, Dibujo.pizza);
    });

    testWidgets('mide lo que se le pide', (tester) async {
      await _mostrar(tester, const PortadaRacconto(imagen: 'mare', lado: 40));

      expect(tester.getSize(find.byType(PortadaRacconto)), const Size(40, 40));
    });

    testWidgets('los diez dibujos se pintan sin romperse', (tester) async {
      // El dibujo son cuentas: un paréntesis de más y la pantalla no aparece.
      for (final dibujo in Dibujo.values) {
        await _mostrar(
          tester,
          CustomPaint(
            painter: DibujoPortada(dibujo),
            size: const Size(54, 54),
          ),
        );
        expect(tester.takeException(), isNull, reason: dibujo.name);
      }
    });

    testWidgets('el mismo dibujo entra igual en chico y en grande',
        (tester) async {
      // Está todo medido en fracciones del lado: si algo quedara en píxeles
      // fijos, en el cuadradito de la lista se saldría del recuadro.
      for (final lado in [40.0, 54.0, 104.0]) {
        await _mostrar(tester, PortadaRacconto(imagen: 'gatto', lado: lado));
        expect(tester.takeException(), isNull, reason: '$lado');
      }
    });
  });

  group('la banda de presentación', () {
    testWidgets('muestra el título y el subtítulo', (tester) async {
      await _mostrar(
        tester,
        const BandaPortada(
          imagen: 'mistero',
          titulo: 'Il segreto dei Ferrante',
          subtitulo: 'El secreto de los Ferrante',
        ),
      );

      expect(find.text('Il segreto dei Ferrante'), findsOneWidget);
      expect(find.text('El secreto de los Ferrante'), findsOneWidget);
    });

    testWidgets('lleva el dibujo de la obra', (tester) async {
      await _mostrar(
        tester,
        const BandaPortada(imagen: 'telefono', titulo: 'T', subtitulo: 't'),
      );

      final pintor = tester
          .widget<CustomPaint>(find.byType(CustomPaint).last)
          .painter;
      expect((pintor! as DibujoPortada).dibujo, Dibujo.telefono);
    });
  });
}
