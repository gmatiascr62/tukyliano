import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tukyliano/widgets/campo_texto.dart';

/// Las respuestas más largas que existen en el JSON: si estas entran, entran
/// todas. Se leen del asset para que el test siga al día si se agregan frases.
List<String> _lasMasLargas(int cuantas) {
  final json = jsonDecode(File('assets/frases.json').readAsStringSync())
      as Map<String, dynamic>;
  final italianos = (json['frases'] as List)
      .map((f) => (f as Map<String, dynamic>)['italiano'] as String)
      .toList()
    ..sort((a, b) => b.length.compareTo(a.length));
  return italianos.take(cuantas).toList();
}

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

/// ¿Entró todo en un renglón, sin recortar?
bool _entraEnUnRenglon(({String texto, TextStyle estilo, Size caja}) p) {
  final medidor = TextPainter(
    text: TextSpan(text: p.texto, style: p.estilo),
    textDirection: TextDirection.ltr,
    textAlign: TextAlign.center,
    maxLines: 1,
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
  testWidgets('las respuestas más largas del JSON entran enteras y en un solo '
      'renglón', (tester) async {
    _celular(tester);

    for (final respuesta in _lasMasLargas(15)) {
      await _mostrar(tester, respuesta);
      final p = _pintado(tester);

      expect(p.texto, respuesta, reason: 'no se dibuja el texto completo');
      expect(_entraEnUnRenglon(p), isTrue,
          reason: '"$respuesta" no entra a ${p.estilo.fontSize}px '
              'en ${p.caja.width}px');
    }
  });

  testWidgets('el texto nunca se parte en dos renglones', (tester) async {
    // Dos renglones no entran en el alto de la caja: el segundo quedaba
    // cortado por el borde.
    _celular(tester);
    await _mostrar(tester, 'Abbiamo avuto la febbre la settimana scorsa');

    expect(tester.widget<Text>(find.byType(Text)).maxLines, 1);
    final caja = tester.renderObject<RenderBox>(find.byType(Text)).size;
    expect(caja.height, lessThan(40), reason: 'entró más de un renglón');
  });

  testWidgets('una respuesta corta no se achica', (tester) async {
    _celular(tester);
    await _mostrar(tester, 'ho fame');

    expect(_pintado(tester).estilo.fontSize, 22);
  });

  testWidgets('una respuesta larga se achica lo que haga falta',
      (tester) async {
    _celular(tester);
    await _mostrar(tester, 'Abbiamo avuto la febbre la settimana scorsa');

    expect(_pintado(tester).estilo.fontSize, lessThan(22));
  });

  testWidgets('el placeholder se muestra tal cual cuando está vacío',
      (tester) async {
    _celular(tester);
    await _mostrar(tester, '');

    expect(_pintado(tester).texto, 'Escribí la conjugación...');
  });

  testWidgets('una palabra sola más ancha que la caja también se achica',
      (tester) async {
    // No puede cortarse, así que solo queda achicarla. Lo detecta el chequeo
    // por ancho: contar renglones no alcanza.
    //
    // Una palabra de 45 letras no entra ni en el mínimo, y ahí sí se recorta:
    // es el único caso que queda, y en italiano no existe.
    _celular(tester);
    await _mostrar(tester, 'unapalabralarguisimaquenoentradeningunamanera');

    expect(_pintado(tester).estilo.fontSize, 8);
  });
}
