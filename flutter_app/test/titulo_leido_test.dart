// El título que el lector lee en voz alta.
//
// En Pinocchio el lector dice "Capitolo primo" y después el título entero, y
// recién a los cuarenta y un segundos empieza el cuento. La app saltaba
// directo al cuento para ahorrarle a quien escucha la presentación de
// LibriVox —quién lee, de qué libro, cuarenta segundos— y de paso se
// salteaba el título: quedaba escrito arriba en negrita sin que se oyera
// nunca. Matías lo vio enseguida: "el audio la primera frase no la lee y
// queda siempre en negrita ahí arriba".
//
// Ahora el título tiene su momento igual que cualquier renglón: se empieza
// ahí y se pinta mientras lo leen. Sigue viviendo en el encabezado y no en
// la lista, porque como renglón aparecería dos veces.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tukyliano/modelos/diccionario.dart';
import 'package:tukyliano/modelos/lectura.dart';
import 'package:tukyliano/pantallas/pantalla_una_lectura.dart';
import 'package:tukyliano/tema.dart';

import 'reproductor_falso.dart';
import 'util_pantalla.dart';

const _elTitulo = '1. Come andò che maestro Ciliegia';

Lectura _elCapitulo({bool conTitulo = true}) => Lectura.desdeJson({
      'id': 'pinocchio_01',
      'titulo': _elTitulo,
      'archivo': 'uno.mp3',
      'segundos': 335,
      'bytes': 2683216,
      if (conTitulo) 'tituloDesde': 33.0,
      if (conTitulo) 'tituloHasta': 41.26,
      'renglones': [
        {'t': '— C’era una volta.... — Un re!', 'desde': 41.26,
          'hasta': 43.66},
        {'t': '— No, ragazzi, avete sbagliato.', 'desde': 43.66,
          'hasta': 50.43},
      ],
    });

Future<ReproductorFalso> _abrir(
  WidgetTester tester, {
  bool conTitulo = true,
}) async {
  usarPantallaDeCelular(tester);
  final reproductor = ReproductorFalso();
  await tester.pumpWidget(MaterialApp(
    theme: Tema.datos,
    home: Scaffold(
      body: PantallaUnaLectura(
        lectura: _elCapitulo(conTitulo: conTitulo),
        ruta: '/no/importa/uno.mp3',
        reproductor: reproductor,
        diccionario: const Diccionario(),
        alVolver: () {},
      ),
    ),
  ));
  await tester.pumpAndSettle();
  return reproductor;
}

/// De qué color está pintado el encabezado, si lo está.
Color? _comoEstaElTitulo(WidgetTester tester) {
  final cajas = tester.widgetList<Container>(
    find.ancestor(
      of: find.text(_elTitulo),
      matching: find.byType(Container),
    ),
  );
  for (final caja in cajas) {
    if (caja.color != null) return caja.color;
  }
  return null;
}

void main() {
  testWidgets('el título es la primera línea del texto, no una barra fija',
      (tester) async {
    // Estuvo un rato clavado arriba en una cabecera propia y Matías lo
    // marcó enseguida: "debería verse como el resto de la historia, que se
    // vaya para arriba a medida que va pasando la historia". Tiene razón,
    // y es como funciona un libro: el título está arriba de la página y se
    // va cuando uno avanza. Clavado arriba se quedaba a la vista el
    // capítulo entero, ocupando lugar y repitiendo algo que ya pasó.
    await _abrir(tester);

    // Adentro de la lista que se desplaza, no afuera.
    expect(
      find.descendant(
        of: find.byType(ListView),
        matching: find.text(_elTitulo),
      ),
      findsOneWidget,
    );
    // Y una sola vez: si además quedara en una cabecera, se vería dos veces.
    expect(find.text(_elTitulo), findsOneWidget);
  });

  testWidgets('las palabras del título se pueden tocar', (tester) async {
    // Al pasar el título adentro del texto quedó como texto plano, sin los
    // toques por palabra que tienen los renglones. Matías lo encontró
    // enseguida: "no me deja traducir el título del primer capítulo,
    // quiero traducir bambino y no aparece la traducción".
    //
    // Si el título es la primera línea del capítulo, tocar una palabra ahí
    // tiene que funcionar igual que en el resto.
    await _abrir(tester);

    // El título ya no es un Text con una cadena adentro sino uno armado con
    // un pedazo por palabra, cada uno con su reconocedor de toques.
    final palabras = <String>[];
    for (final texto in tester.widgetList<Text>(find.byType(Text))) {
      final span = texto.textSpan;
      if (span is! TextSpan) continue;
      final pedazos = (span.children ?? []).whereType<TextSpan>();
      if (!pedazos.any((p) => (p.text ?? '').contains('Ciliegia'))) continue;
      palabras.addAll(pedazos
          .where((p) => p.recognizer != null)
          .map((p) => p.text ?? ''));
    }

    expect(palabras, isNotEmpty, reason: 'ninguna palabra del título se toca');
    expect(palabras.join(), contains('Ciliegia'));
  });

  testWidgets('se empieza por el título, no por el cuento', (tester) async {
    final reproductor = await _abrir(tester);

    // Cuatro segundos antes de donde el alineado dice que arranca el
    // título: ahí el lector está terminando la presentación y diciendo
    // "Capitolo primo", que oírlo no molesta, y así no se come el
    // principio del título.
    expect(reproductor.donde, const Duration(seconds: 29));
  });

  testWidgets('el título se pinta mientras lo leen', (tester) async {
    final reproductor = await _abrir(tester);
    expect(_comoEstaElTitulo(tester), isNull,
        reason: 'antes de que lo lean no se pinta');

    reproductor.correrA(const Duration(seconds: 35));
    await tester.pumpAndSettle();
    expect(_comoEstaElTitulo(tester), Tema.verdeSuave);

    // Y se apaga cuando empieza el cuento, o se verían dos cosas pintadas
    // a la vez.
    reproductor.correrA(const Duration(seconds: 42));
    await tester.pumpAndSettle();
    expect(_comoEstaElTitulo(tester), isNull);
  });

  testWidgets('sin título leído, se empieza por el primer renglón',
      (tester) async {
    // Las fábulas son así: el lector no lee el título, así que no hay nada
    // que esperar antes del primer verso.
    final reproductor = await _abrir(tester, conTitulo: false);

    expect(reproductor.donde, const Duration(milliseconds: 41260));
    reproductor.correrA(const Duration(seconds: 35));
    await tester.pumpAndSettle();
    expect(_comoEstaElTitulo(tester), isNull);
  });
}
