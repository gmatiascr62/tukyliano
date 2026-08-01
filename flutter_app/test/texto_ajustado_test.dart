import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tukyliano/widgets/texto_ajustado.dart';

const _estilo = TextStyle(fontSize: 22, fontWeight: FontWeight.w600);

/// Envuelve el texto en un ancho fijo, como el recuadro donde se escribe.
Widget _en(double ancho, String texto, {List<TextSpan>? trozos}) => MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: ancho,
            height: 62,
            child: TextoAjustado(texto, estilo: _estilo, trozos: trozos),
          ),
        ),
      ),
    );

Text _texto(WidgetTester tester) => tester.widget<Text>(find.byType(Text));

/// Cuánto se achicó: 1 es tamaño original, 0.5 es la mitad.
double _escala(WidgetTester tester) {
  final caja = tester.renderObject<RenderBox>(find.byType(FittedBox)).size;
  final contenido = tester.renderObject<RenderBox>(find.byType(Text)).size;
  if (contenido.width <= caja.width) return 1;
  return caja.width / contenido.width;
}

void main() {
  testWidgets('un texto corto se muestra en el tamaño original',
      (tester) async {
    await tester.pumpWidget(_en(300, 'ho fame'));
    expect(_escala(tester), 1);
  });

  testWidgets('un texto largo se achica', (tester) async {
    await tester.pumpWidget(_en(300, 'i miei cugini hanno avuto un gatto'));
    expect(_escala(tester), lessThan(1));
  });

  testWidgets('cuanto más largo, más chico', (tester) async {
    await tester.pumpWidget(_en(300, 'avete avuto una macchina'));
    final corto = _escala(tester);

    await tester.pumpWidget(_en(300, 'avete avuto una macchina vecchia e rossa'));
    expect(_escala(tester), lessThan(corto));
  });

  testWidgets('nunca recorta: sin puntos suspensivos y sin límite de tamaño',
      (tester) async {
    await tester.pumpWidget(_en(
      120,
      'una frase larguísima que no entra de ninguna manera acá adentro',
    ));

    final texto = _texto(tester);
    expect(texto.overflow, TextOverflow.visible);
    expect(texto.softWrap, isFalse);
    // Por chico que quede, el texto está completo.
    expect((texto.textSpan! as TextSpan).text,
        'una frase larguísima que no entra de ninguna manera acá adentro');
  });

  testWidgets('siempre en un solo renglón', (tester) async {
    await tester.pumpWidget(_en(120, 'i miei cugini hanno avuto un gatto'));

    expect(_texto(tester).maxLines, 1);
    final contenido = tester.renderObject<RenderBox>(find.byType(Text)).size;
    // Un renglón de 22px mide bastante menos de 40 de alto.
    expect(contenido.height, lessThan(40));
  });

  testWidgets('una palabra sola larguísima también entra', (tester) async {
    await tester.pumpWidget(_en(120, 'unapalabralarguisimaquenoentra'));

    expect(_escala(tester), lessThan(1));
    expect(_texto(tester).overflow, TextOverflow.visible);
  });

  testWidgets('los trozos con color conservan su color', (tester) async {
    await tester.pumpWidget(_en(
      200,
      'Ho molta fame',
      trozos: const [
        TextSpan(text: 'Ho', style: TextStyle(color: Colors.green)),
        TextSpan(text: ' molta', style: TextStyle(color: Colors.red)),
        TextSpan(text: ' fame', style: TextStyle(color: Colors.green)),
      ],
    ));

    final span = _texto(tester).textSpan! as TextSpan;
    final hijos = span.children!.cast<TextSpan>();
    expect(hijos.map((h) => h.style!.color),
        [Colors.green, Colors.red, Colors.green]);
  });
}
