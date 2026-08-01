import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tukyliano/tema.dart';
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

/// Se usa el tema de la app a propósito: fija una tipografía, y la versión
/// anterior fallaba justamente porque medía con una distinta a la que dibuja.
Future<void> _mostrar(WidgetTester tester, String texto) => tester.pumpWidget(
      MaterialApp(
        theme: Tema.datos,
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(14),
            child: CampoTexto(texto: texto),
          ),
        ),
      ),
    );

Text _texto(WidgetTester tester) => tester.widget<Text>(find.byType(Text));

/// Cuánto se achicó: 1 es tamaño original.
double _escala(WidgetTester tester) {
  final caja = tester.renderObject<RenderBox>(find.byType(FittedBox)).size;
  final contenido = tester.renderObject<RenderBox>(find.byType(Text)).size;
  if (contenido.width <= caja.width) return 1;
  return caja.width / contenido.width;
}

void main() {
  testWidgets('las respuestas más largas del JSON se dibujan enteras',
      (tester) async {
    _celular(tester);

    for (final respuesta in _lasMasLargas(15)) {
      await _mostrar(tester, respuesta);
      final texto = _texto(tester);

      expect((texto.textSpan! as TextSpan).text, respuesta,
          reason: 'no se dibuja el texto completo');
      expect(texto.overflow, TextOverflow.visible,
          reason: '"$respuesta" se puede recortar');
    }
  });

  testWidgets('una respuesta larga se achica', (tester) async {
    _celular(tester);
    await _mostrar(tester, 'Abbiamo avuto la febbre la settimana scorsa');

    expect(_escala(tester), lessThan(1));
  });

  testWidgets('una respuesta corta no se achica', (tester) async {
    _celular(tester);
    await _mostrar(tester, 'ho fame');

    expect(_escala(tester), 1);
  });

  testWidgets('nunca ocupa dos renglones', (tester) async {
    _celular(tester);
    await _mostrar(tester, 'Abbiamo avuto la febbre la settimana scorsa');

    expect(_texto(tester).maxLines, 1);
    expect(_texto(tester).softWrap, isFalse);
  });

  testWidgets('el texto entra en la caja, no se pasa', (tester) async {
    _celular(tester);
    await _mostrar(tester, 'Abbiamo avuto la febbre la settimana scorsa');

    final fitted = tester.renderObject<RenderBox>(find.byType(FittedBox));
    final campo = tester.renderObject<RenderBox>(find.byType(CampoTexto));
    expect(fitted.size.width, lessThanOrEqualTo(campo.size.width));
    expect(fitted.size.height, lessThanOrEqualTo(campo.size.height));
  });

  testWidgets('el placeholder se muestra tal cual cuando está vacío',
      (tester) async {
    _celular(tester);
    await _mostrar(tester, '');

    expect((_texto(tester).textSpan! as TextSpan).text,
        'Escribí la conjugación...');
  });

  testWidgets('una palabra sola más ancha que la caja también se achica',
      (tester) async {
    _celular(tester);
    await _mostrar(tester, 'unapalabralarguisimaquenoentradeningunamanera');

    expect(_escala(tester), lessThan(1));
    expect(_texto(tester).overflow, TextOverflow.visible);
  });
}
