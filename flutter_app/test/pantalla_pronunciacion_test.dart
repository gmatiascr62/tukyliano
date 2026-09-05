import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tukyliano/datos/escucha.dart';
import 'package:tukyliano/datos/palabras_habladas.dart';
import 'package:tukyliano/modelos/palabra_hablada.dart';
import 'package:tukyliano/pantallas/pantalla_pronunciacion.dart';
import 'package:tukyliano/tema.dart';
import 'package:tukyliano/widgets/pastilla.dart';

import 'escucha_falsa.dart';
import 'util_pantalla.dart';
import 'voz_falsa.dart';

/// Casi todos los tests van con una sola palabra: el orden es al azar, así que
/// con más de una no se sabría cuál está en pantalla.
const _una = [
  PalabraHablada(
    italiano: 'cinque',
    espanol: 'cinco',
    pista: 'chín-cue',
    sonido: 'ci = ch',
  ),
];

const _tres = [
  ..._una,
  PalabraHablada(
    italiano: 'gnocchi',
    espanol: 'ñoquis',
    pista: 'ñó-qui',
    sonido: 'gn = ñ',
  ),
  PalabraHablada(
    italiano: 'pesce',
    espanol: 'pescado',
    pista: 'pé-she',
    sonido: 'sce = sh',
  ),
];

Future<void> _abrir(
  WidgetTester tester, {
  required EscuchaFalsa escucha,
  VozFalsa? voz,
  List<PalabraHablada> palabras = _una,
}) async {
  usarPantallaDeCelular(tester);
  await tester.pumpWidget(MaterialApp(
    theme: Tema.datos,
    home: Scaffold(
      body: PantallaPronunciacion(
        voz: voz ?? VozFalsa(),
        escucha: escucha,
        palabras: palabras,
        // Semilla fija: los tests que miran el orden necesitan que no cambie
        // de una corrida a otra.
        azar: Random(7),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

Future<void> _hablar(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.mic));
  await tester.pumpAndSettle();
}

/// Cuál de las palabras está en pantalla.
String _enPantalla(List<PalabraHablada> palabras) {
  for (final palabra in palabras) {
    if (find.text(palabra.italiano).evaluate().isNotEmpty) {
      return palabra.italiano;
    }
  }
  return '';
}

const _frase = [
  PalabraHablada(
    italiano: 'il conto per favore possiamo pagare con la carta',
    espanol: 'la cuenta por favor, ¿podemos pagar con tarjeta?',
    pista: 'cón-to',
    sonido: 'en el bar',
    grupo: GrupoHabla.frases,
  ),
];

/// De qué color salió cada palabra de la frase en pantalla.
List<Color?> _colores(WidgetTester tester, String frase) {
  final texto = tester.widget<Text>(
    find.byWidgetPredicate(
      (w) => w is Text && w.textSpan != null && w.textSpan!.toPlainText() == frase,
    ),
  );
  return [
    for (final hijo in (texto.textSpan! as TextSpan).children!)
      (hijo as TextSpan).style?.color,
  ];
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

  testWidgets('apenas entiende la palabra corta el micrófono',
      (WidgetTester tester) async {
    // Sin esto había que esperar los segundos que Android se toma para
    // decidir que terminaste de hablar, aunque ya te hubiera entendido.
    final escucha = EscuchaFalsa(parciales: const ['cin', 'cinque']);
    await _abrir(tester, escucha: escucha);
    await _hablar(tester);

    expect(escucha.cortadas, greaterThan(0));
    expect(find.text('¡Bien dicho!'), findsOneWidget);
  });

  testWidgets('si lo que entiende no es la palabra, sigue escuchando',
      (WidgetTester tester) async {
    final escucha = EscuchaFalsa(
      parciales: const ['quin', 'quinque'],
      respuesta: const LoEscuchado(mejor: 'quinque', alternativas: ['quinque']),
    );
    await _abrir(tester, escucha: escucha);
    await _hablar(tester);

    expect(escucha.cortadas, 0);
    expect(find.text('Entendió otra cosa.'), findsOneWidget);
  });

  testWidgets('el silencio no cuenta como error', (WidgetTester tester) async {
    await _abrir(tester, escucha: EscuchaFalsa());
    await _hablar(tester);

    expect(find.text('No te escuché. Probá de nuevo.'), findsOneWidget);
    expect(find.text('Puntaje: 0/0'), findsOneWidget);
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

  group('el orden', () {
    testWidgets('pasa por todas las palabras antes de repetir una',
        (WidgetTester tester) async {
      await _abrir(tester, escucha: EscuchaFalsa(), palabras: _tres);

      final vistas = <String>[_enPantalla(_tres)];
      for (var i = 1; i < _tres.length; i++) {
        await tester.tap(find.text('Otra palabra'));
        await tester.pumpAndSettle();
        vistas.add(_enPantalla(_tres));
      }

      expect(vistas.toSet().length, _tres.length, reason: vistas.join(', '));
    });

    testWidgets('al dar la vuelta no repite la última que se vio',
        (WidgetTester tester) async {
      await _abrir(tester, escucha: EscuchaFalsa(), palabras: _tres);

      for (var i = 1; i < _tres.length; i++) {
        await tester.tap(find.text('Otra palabra'));
        await tester.pumpAndSettle();
      }
      final ultima = _enPantalla(_tres);

      await tester.tap(find.text('Otra palabra'));
      await tester.pumpAndSettle();

      expect(_enPantalla(_tres), isNot(ultima));
    });

    testWidgets('"Otra palabra" limpia el resultado pero deja el puntaje',
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

      expect(find.text('¡Bien dicho!'), findsNothing);
      // El puntaje sí se conserva: es de toda la vuelta, no de la palabra.
      expect(find.text('Puntaje: 1/1'), findsOneWidget);
    });
  });

  group('las frases', () {
    testWidgets('pinta de verde las palabras a medida que salen',
        (WidgetTester tester) async {
      await _abrir(
        tester,
        escucha: EscuchaFalsa(parciales: const ['il conto']),
        palabras: _frase,
      );
      await _hablar(tester);

      final colores = _colores(
        tester,
        'il conto per favore possiamo pagare con la carta',
      );
      expect(colores[0], Tema.correcto);
      expect(colores[1], Tema.correcto);
      expect(colores[2], Tema.titulo);
      expect(colores.last, Tema.titulo);
    });

    testWidgets('al terminar la frase corta el micrófono',
        (WidgetTester tester) async {
      final escucha = EscuchaFalsa(
        parciales: const [
          'il conto',
          'il conto per favore possiamo pagare con la carta',
        ],
      );
      await _abrir(tester, escucha: escucha, palabras: _frase);
      await _hablar(tester);

      expect(escucha.cortadas, greaterThan(0));
      expect(find.text('¡Bien dicho!'), findsOneWidget);
      expect(
        _colores(tester, 'il conto per favore possiamo pagare con la carta'),
        everyElement(Tema.correcto),
      );
    });

    testWidgets('si se traba, dice en qué palabra',
        (WidgetTester tester) async {
      await _abrir(
        tester,
        escucha: EscuchaFalsa(
          parciales: const ['il conto'],
          respuesta: const LoEscuchado(mejor: 'il conto', alternativas: []),
        ),
        palabras: _frase,
      );
      await _hablar(tester);

      expect(find.text('Te trabaste en «per».'), findsOneWidget);
    });

    testWidgets('el botón dice "Otra frase"', (WidgetTester tester) async {
      await _abrir(tester, escucha: EscuchaFalsa(), palabras: _frase);

      expect(find.text('Otra frase'), findsOneWidget);
    });
  });

  group('los grupos', () {
    testWidgets('con uno solo no muestra las pastillas de elegir',
        (WidgetTester tester) async {
      // La palabra de prueba es de sonidos: no habría nada que elegir.
      await _abrir(tester, escucha: EscuchaFalsa());

      expect(find.text('Sonidos'), findsNothing);
      expect(find.text('Números'), findsNothing);
    });

    testWidgets('las pastillas cambian la tanda', (WidgetTester tester) async {
      await _abrir(
        tester,
        escucha: EscuchaFalsa(),
        palabras: [..._una, ...numerosParaDecir],
      );

      expect(find.text('cinque'), findsOneWidget);

      await tester.tap(find.widgetWithText(Pastilla, 'Números'));
      await tester.pumpAndSettle();
      expect(find.text('cinque'), findsNothing);
      expect(_enPantalla(numerosParaDecir), isNotEmpty);

      await tester.tap(find.widgetWithText(Pastilla, 'Sonidos'));
      await tester.pumpAndSettle();
      expect(find.text('cinque'), findsOneWidget);
    });
  });
}
