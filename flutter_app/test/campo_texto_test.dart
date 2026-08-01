import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tukyliano/widgets/campo_texto.dart';

/// Frases reales de la práctica, de las más largas que puede tocar escribir.
const _respuestasLargas = [
  'ho',
  'non abbiamo avuto tempo',
  'non abbiamo avuto tempo mai',
  'avete avuto una macchina vecchia',
  'abbiamo avuto la febbre la settimana scorsa',
  'i miei cugini hanno avuto un gatto',
];

/// Deja el tester con el ancho de un celular real.
void _celular(WidgetTester tester) {
  tester.view.physicalSize = const Size(1280, 2772);
  tester.view.devicePixelRatio = 1280 / 411;
  addTearDown(tester.view.reset);
}

/// El texto que finalmente se dibuja, con el tamaño que quedó.
({String texto, TextStyle estilo, Size caja}) _pintado(WidgetTester tester) {
  final widget = tester.widget<Text>(find.byType(Text));
  final span = widget.textSpan! as TextSpan;
  return (
    texto: span.text!,
    estilo: span.style!,
    caja: tester.renderObject<RenderBox>(find.byType(Text)).size,
  );
}

/// ¿Entró todo, sin recortar?
bool _entraCompleto(({String texto, TextStyle estilo, Size caja}) p) {
  final medidor = TextPainter(
    text: TextSpan(text: p.texto, style: p.estilo),
    textDirection: TextDirection.ltr,
    textAlign: TextAlign.center,
    maxLines: 2,
  )..layout(maxWidth: p.caja.width);
  return !medidor.didExceedMaxLines && medidor.width <= p.caja.width + 0.5;
}

Future<void> _mostrar(WidgetTester tester, String texto) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(14),
            child: CampoTexto(texto: texto),
          ),
        ),
      ),
    );

void main() {
  testWidgets('cualquier respuesta larga se ve entera, sin puntos suspensivos',
      (tester) async {
    _celular(tester);

    for (final respuesta in _respuestasLargas) {
      await _mostrar(tester, respuesta);
      final p = _pintado(tester);

      expect(p.texto, respuesta, reason: 'no se dibuja el texto completo');
      expect(_entraCompleto(p), isTrue,
          reason: '"$respuesta" no entra a ${p.estilo.fontSize}px '
              'en ${p.caja.width}px');
    }
  });

  testWidgets('una respuesta corta no se achica', (tester) async {
    _celular(tester);
    await _mostrar(tester, 'ho fame');

    expect(_pintado(tester).estilo.fontSize, 22);
  });

  testWidgets('una respuesta larga se achica, pero no hasta ser ilegible',
      (tester) async {
    _celular(tester);
    await _mostrar(tester, 'abbiamo avuto la febbre la settimana scorsa');
    final tamano = _pintado(tester).estilo.fontSize!;

    expect(tamano, lessThan(22));
    expect(tamano, greaterThanOrEqualTo(13));
  });

  testWidgets('el placeholder se muestra tal cual cuando está vacío',
      (tester) async {
    _celular(tester);
    await _mostrar(tester, '');

    expect(_pintado(tester).texto, 'Escribí la conjugación...');
  });

  testWidgets('una palabra sola larguísima igual se ve entera', (tester) async {
    // Flutter parte la palabra entre renglones cuando no le queda otra, así
    // que con dos renglones entra; si no alcanzara, se achica.
    _celular(tester);
    await _mostrar(tester, 'unapalabralarguisimaquenoentradeningunamanera');

    final p = _pintado(tester);
    expect(p.estilo.fontSize, lessThan(22));
    expect(_entraCompleto(p), isTrue);
  });
}
