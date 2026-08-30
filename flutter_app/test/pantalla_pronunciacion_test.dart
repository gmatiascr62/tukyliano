import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tukyliano/datos/escucha.dart';
import 'package:tukyliano/modelos/palabra_hablada.dart';
import 'package:tukyliano/pantallas/pantalla_pronunciacion.dart';
import 'package:tukyliano/tema.dart';

import 'escucha_falsa.dart';
import 'util_pantalla.dart';
import 'voz_falsa.dart';

const _dos = [
  PalabraHablada(
    italiano: 'cinque',
    espanol: 'cinco',
    pista: 'chín-cue',
    sonido: 'ci = ch',
  ),
  PalabraHablada(
    italiano: 'gnocchi',
    espanol: 'ñoquis',
    pista: 'ñó-qui',
    sonido: 'gn = ñ',
  ),
];

Future<void> _abrir(
  WidgetTester tester, {
  required EscuchaFalsa escucha,
  VozFalsa? voz,
}) async {
  usarPantallaDeCelular(tester);
  await tester.pumpWidget(MaterialApp(
    theme: Tema.datos,
    home: Scaffold(
      body: PantallaPronunciacion(
        voz: voz ?? VozFalsa(),
        escucha: escucha,
        palabras: _dos,
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

Future<void> _hablar(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.mic));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('muestra la palabra, la traducción y cómo suena',
      (WidgetTester tester) async {
    await _abrir(tester, escucha: EscuchaFalsa());

    expect(find.text('cinque'), findsOneWidget);
    expect(find.text('cinco'), findsOneWidget);
    expect(find.text('suena chín-cue'), findsOneWidget);
    expect(find.text('ci = ch'), findsOneWidget);
  });

  testWidgets('decirla bien la da por buena y suma al puntaje',
      (WidgetTester tester) async {
    final escucha = EscuchaFalsa(
      respuesta: const LoEscuchado(mejor: 'cinque', alternativas: ['cinque']),
    );
    await _abrir(tester, escucha: escucha);
    await _hablar(tester);

    expect(escucha.escuchadas, 1);
    expect(find.text('¡Bien dicho!'), findsOneWidget);
    expect(find.text('Puntaje: 1/1'), findsOneWidget);
  });

  testWidgets('el número escrito con cifra también vale',
      (WidgetTester tester) async {
    // Android devuelve "5" cuando se dice "cinque", y eso es decirlo bien.
    await _abrir(
      tester,
      escucha: EscuchaFalsa(
        respuesta: const LoEscuchado(mejor: '5', alternativas: ['5']),
      ),
    );
    await _hablar(tester);

    expect(find.text('¡Bien dicho!'), findsOneWidget);
  });

  testWidgets('si entendió otra cosa lo dice y muestra qué escuchó',
      (WidgetTester tester) async {
    await _abrir(
      tester,
      escucha: EscuchaFalsa(
        respuesta: const LoEscuchado(
          mejor: 'quinque',
          alternativas: ['quinque'],
        ),
      ),
    );
    await _hablar(tester);

    expect(find.text('Entendió otra cosa.'), findsOneWidget);
    expect(find.text('Escuché: "quinque"'), findsOneWidget);
    expect(find.text('Puntaje: 0/1'), findsOneWidget);
  });

  testWidgets('el silencio no cuenta como error', (WidgetTester tester) async {
    await _abrir(tester, escucha: EscuchaFalsa());
    await _hablar(tester);

    expect(find.text('No te escuché. Probá de nuevo.'), findsOneWidget);
    expect(find.text('Puntaje: 0/0'), findsOneWidget);
  });

  testWidgets('muestra el detalle técnico del micrófono',
      (WidgetTester tester) async {
    // Mientras esto sea una prueba, el detalle es lo único que dice por qué un
    // celular no escucha: sin él, todas las fallas se ven igual.
    await _abrir(
      tester,
      escucha: EscuchaFalsa(
        diagnostico: 'idioma: it_IT · error: error_no_match',
      ),
    );
    await _hablar(tester);

    expect(
      find.text('idioma: it_IT · error: error_no_match'),
      findsOneWidget,
    );
  });

  testWidgets('sin micrófono avisa por qué no pasa nada',
      (WidgetTester tester) async {
    await _abrir(
      tester,
      escucha: EscuchaFalsa(
        puedeEscuchar: false,
        problema: 'Falta el permiso del micrófono.',
      ),
    );

    expect(find.text('Falta el permiso del micrófono.'), findsOneWidget);
  });

  testWidgets('el botón de escuchar pronuncia la palabra',
      (WidgetTester tester) async {
    final voz = VozFalsa();
    await _abrir(tester, escucha: EscuchaFalsa(), voz: voz);

    await tester.tap(find.text('Escuchar'));
    await tester.pumpAndSettle();

    expect(voz.dicho, ['cinque']);
  });

  testWidgets('antes de escuchar corta la voz, para no oírse a sí mismo',
      (WidgetTester tester) async {
    final voz = VozFalsa();
    await _abrir(tester, escucha: EscuchaFalsa(), voz: voz);
    await _hablar(tester);

    expect(voz.callados, greaterThan(0));
  });

  testWidgets('"Otra palabra" pasa a la siguiente y limpia el resultado',
      (WidgetTester tester) async {
    await _abrir(
      tester,
      escucha: EscuchaFalsa(
        respuesta: const LoEscuchado(mejor: 'cinque', alternativas: ['cinque']),
      ),
    );
    await _hablar(tester);
    await tester.tap(find.text('Otra palabra'));
    await tester.pumpAndSettle();

    expect(find.text('gnocchi'), findsOneWidget);
    expect(find.text('¡Bien dicho!'), findsNothing);
    // El puntaje sí se conserva: es de toda la vuelta, no de la palabra.
    expect(find.text('Puntaje: 1/1'), findsOneWidget);
  });

  testWidgets('después de la última vuelve a la primera',
      (WidgetTester tester) async {
    await _abrir(tester, escucha: EscuchaFalsa());

    for (var i = 0; i < _dos.length; i++) {
      await tester.tap(find.text('Otra palabra'));
      await tester.pumpAndSettle();
    }

    expect(find.text('cinque'), findsOneWidget);
  });
}
