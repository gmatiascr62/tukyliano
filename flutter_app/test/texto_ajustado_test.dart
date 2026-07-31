import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tukyliano/widgets/texto_ajustado.dart';

const _estilo = TextStyle(fontSize: 22, fontWeight: FontWeight.w600);

/// Envuelve el texto en un ancho fijo, como el recuadro donde se escribe.
Widget _en(double ancho, String texto, {double minimo = 11}) => MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: ancho,
            child: TextoAjustado(texto, estilo: _estilo, tamanoMinimo: minimo),
          ),
        ),
      ),
    );

double _tamano(WidgetTester tester) {
  final texto = tester.widget<Text>(find.byType(Text));
  return (texto.textSpan! as TextSpan).style!.fontSize!;
}

void main() {
  testWidgets('un texto corto se muestra en el tamaño original',
      (tester) async {
    await tester.pumpWidget(_en(300, 'ho fame'));
    expect(_tamano(tester), 22);
  });

  testWidgets('un texto largo se achica', (tester) async {
    await tester.pumpWidget(_en(300, 'avete avuto una macchina vecchia'));
    expect(_tamano(tester), lessThan(22));
  });

  testWidgets('cuanto más largo, más chico', (tester) async {
    await tester.pumpWidget(_en(300, 'avete avuto una macchina'));
    final corto = _tamano(tester);

    await tester.pumpWidget(_en(300, 'avete avuto una macchina vecchia e rossa'));
    expect(_tamano(tester), lessThan(corto));
  });

  testWidgets('no baja del mínimo', (tester) async {
    await tester.pumpWidget(_en(
      120,
      'una frase larguísima que no entra de ninguna manera acá adentro',
      minimo: 14,
    ));
    expect(_tamano(tester), 14);
  });

  testWidgets('el texto se muestra completo, sin puntos suspensivos',
      (tester) async {
    const largo = 'avete avuto una macchina vecchia';
    await tester.pumpWidget(_en(300, largo));

    // El widget recibe el texto entero; el ajuste es de tamaño, no de recorte.
    final texto = tester.widget<Text>(find.byType(Text));
    expect((texto.textSpan! as TextSpan).text, largo);
  });

  testWidgets('los trozos con color conservan su color y comparten tamaño',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 200,
          child: TextoAjustado(
            'Ho molta fame',
            estilo: _estilo,
            trozos: const [
              TextSpan(text: 'Ho', style: TextStyle(color: Colors.green)),
              TextSpan(text: ' molta', style: TextStyle(color: Colors.red)),
              TextSpan(text: ' fame', style: TextStyle(color: Colors.green)),
            ],
          ),
        ),
      ),
    ));

    final span = tester.widget<Text>(find.byType(Text)).textSpan! as TextSpan;
    final hijos = span.children!.cast<TextSpan>();
    expect(hijos.map((h) => h.style!.color),
        [Colors.green, Colors.red, Colors.green]);
    // Todos con el mismo tamaño, el que resultó del ajuste.
    expect(hijos.map((h) => h.style!.fontSize).toSet().length, 1);
  });
}
