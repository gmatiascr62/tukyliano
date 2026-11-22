// La tarjeta donde se lee lo que hay que traducir.
//
// Tenía un alto fijo, y el alto fijo estaba por una buena razón: que la
// pantalla no pegue un salto cada vez que cambia la pregunta. Pero una
// pregunta que no entra en ese alto no se achica ni se desborda: se corta.
//
// Matías mandó la foto: 'Los chicos tuvieron que estudiar' con el segundo
// renglón partido por la mitad, ilegible. La frase sola no alcanza para
// romperlo —con el tamaño de letra normal entra en un renglón—, hace falta
// además que el dueño del celular haya agrandado la letra del sistema, que
// Android deja llevar a 1,3 y más. Por eso no se veía en ninguna foto de las
// que saco yo: todas salían con la letra en 1.
//
// Estos dos tests son las dos mitades del arreglo, y hacen falta las dos: si
// solo estuviera el primero, dejar la tarjeta sin alto mínimo lo pasaría
// igual y volvería el salto que el alto fijo venía a evitar.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tukyliano/tema.dart';
import 'package:tukyliano/widgets/tarjeta_pregunta.dart';

import 'util_pantalla.dart';

const _alto = 124.0;
const _larga = 'Los chicos tuvieron que estudiar';
const _corta = 'Tengo hambre';

/// La tarjeta sola, con el tamaño de letra que elegiría el celular.
Future<void> _mostrar(
  WidgetTester tester,
  String texto, {
  double letra = 1,
}) async {
  usarPantallaDeCelular(tester);
  await tester.pumpWidget(MaterialApp(
    theme: Tema.datos,
    home: Scaffold(
      body: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(letra)),
        // Adentro de un scroll, que es como la usan las cuatro pantallas: si
        // no, no tendría lugar para crecer.
        child: SingleChildScrollView(
          child: TarjetaPregunta(
            texto: texto,
            etiqueta: 'Armá la frase en italiano',
            alto: _alto,
          ),
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('con la letra grande, la frase larga entra entera',
      (tester) async {
    await _mostrar(tester, _larga, letra: 1.5);

    // Ojo con cómo se mide esto. El texto cortado NO se sale de la tarjeta:
    // lo que pasa es que se lo deja sin lugar, y el renglón que no entra se
    // dibuja a medias adentro. Comparar los bordes no sirve de nada —da
    // bien con el defecto puesto—, y lo probé.
    //
    // Lo que sí distingue un caso del otro es cuánto alto se le dio al
    // texto: con el defecto le tocaban 38 puntos y necesita 82, o sea que no
    // le entraba ni un renglón entero de los dos.
    const unRenglon = 21 * 1.5 * 1.3; // tamaño × letra del sistema × interlínea
    expect(tester.getSize(find.text(_larga)).height,
        greaterThanOrEqualTo(unRenglon * 2),
        reason: 'al texto no le dieron el alto de los dos renglones');

    // Y le entran porque la tarjeta creció, no porque la frase se haya
    // achicado hasta no leerse.
    expect(tester.getSize(find.byType(TarjetaPregunta)).height,
        greaterThan(_alto));
  });

  testWidgets('con una frase que entra, la tarjeta mide lo de siempre',
      (tester) async {
    // Esta es la mitad que cuida lo que ya andaba. El alto está para que la
    // pantalla no salte al cambiar de pregunta, y eso se pierde si la
    // tarjeta mide lo que mide el texto y nada más.
    await _mostrar(tester, _corta);

    expect(tester.getSize(find.byType(TarjetaPregunta)).height, _alto);
  });
}
