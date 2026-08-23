import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tukyliano/constantes.dart';
import 'package:tukyliano/datos/repositorio_particelle.dart';
import 'package:tukyliano/pantallas/pantalla_via.dart';
import 'package:tukyliano/tema.dart';
import 'package:tukyliano/widgets/teclado.dart';

import 'util_pantalla.dart';

/// Una sola frase, así la pregunta es siempre la misma y se puede afirmar cuál
/// es la respuesta.
const _unaSola = '''
  {
    "version": 1,
    "frases": [
      {"frase": "___ via il giornale vecchio.", "correcta": "Butto",
       "es": "tiro el diario viejo",
       "opciones": ["Vado", "Butto", "Porto", "Mando"],
       "explicacion": "buttare via = tirar a la basura.",
       "persona": "io"}
    ]
  }
''';

RepositorioParticelle _repo(String json) => RepositorioParticelle(
      asset: assetVia,
      urlRemoto: urlViaRemoto,
      archivoLocal: archivoViaLocal,
      leerAsset: (_) async => json,
      cliente: MockClient((_) async => http.Response('', 404)),
      carpeta: () async => null,
    );

Future<void> _abrir(WidgetTester tester, [String json = _unaSola]) async {
  usarPantallaDeCelular(tester);
  await tester.pumpWidget(MaterialApp(
    theme: Tema.datos,
    home: Scaffold(body: PantallaVia(repositorio: _repo(json))),
  ));
  await tester.pumpAndSettle();
}

Future<void> _escribir(WidgetTester tester, String texto) async {
  for (final letra in texto.split('')) {
    await tester.tap(find.widgetWithText(InkWell, letra == ' ' ? 'espacio' : letra).first);
    await tester.pump();
  }
}

void main() {
  group('el modo de elegir', () {
    testWidgets('muestra la frase con el hueco y los cuatro verbos',
        (tester) async {
      await _abrir(tester);

      expect(find.text('tiro el diario viejo'), findsOneWidget);
      for (final opcion in ['Vado', 'Butto', 'Porto', 'Mando']) {
        expect(find.text(opcion), findsOneWidget, reason: opcion);
      }
    });

    testWidgets('el verbo tocado se mete en el hueco antes de verificar',
        (tester) async {
      await _abrir(tester);
      await tester.tap(find.text('Porto'));
      await tester.pumpAndSettle();

      // La frase se lee entera con lo elegido puesto, no con el hueco.
      final texto = tester.widget<Text>(find.byType(Text).first);
      expect(texto.data ?? texto.textSpan?.toPlainText() ?? '', isNotNull);
      expect(
        find.textContaining('Porto via il giornale', findRichText: true),
        findsOneWidget,
      );
    });

    testWidgets('acertar suma al puntaje y explica por qué', (tester) async {
      await _abrir(tester);
      await tester.tap(find.text('Butto'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Verificar'));
      await tester.pumpAndSettle();

      expect(find.text('¡Correcto!'), findsOneWidget);
      expect(find.text('buttare via = tirar a la basura.'), findsOneWidget);
      expect(find.text('Puntaje: 1/1'), findsOneWidget);
    });

    testWidgets('errar muestra la frase como iba', (tester) async {
      await _abrir(tester);
      await tester.tap(find.text('Mando'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Verificar'));
      await tester.pumpAndSettle();

      expect(find.text('Va: Butto via il giornale vecchio.'), findsOneWidget);
      expect(find.text('Puntaje: 0/1'), findsOneWidget);
    });

    testWidgets('sin elegir nada no se puede verificar', (tester) async {
      await _abrir(tester);

      final boton =
          tester.widget<ElevatedButton>(find.byType(ElevatedButton).first);
      expect(boton.onPressed, isNull);
    });
  });

  group('el modo de escribir', () {
    testWidgets('trae el teclado propio, que en Elegir no está',
        (tester) async {
      await _abrir(tester);
      expect(find.byType(Teclado), findsNothing);

      await tester.tap(find.text('Escribir'));
      await tester.pumpAndSettle();

      expect(find.byType(Teclado), findsOneWidget);
      // La consigna pasa a ser el español: los botones con la respuesta ya no
      // están.
      expect(find.text('Butto'), findsNothing);
      expect(find.textContaining('tiro el diario viejo'), findsOneWidget);
    });

    testWidgets('el teclado tiene el apóstrofo, que las frases necesitan',
        (tester) async {
      await _abrir(tester);
      await tester.tap(find.text('Escribir'));
      await tester.pumpAndSettle();

      expect(find.text("'"), findsOneWidget);
    });

    testWidgets('corrige palabra por palabra lo que se escribió',
        (tester) async {
      await _abrir(tester);
      await tester.tap(find.text('Escribir'));
      await tester.pumpAndSettle();

      // Se escribe solo una palabra de la frase: la corrección tiene que
      // mostrar la respuesta entera igual.
      await _escribir(tester, 'butto');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Verificar'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Butto via il giornale vecchio.',
            findRichText: true),
        findsOneWidget,
      );
      // No acertó todas, así que no suma.
      expect(find.text('Puntaje: 0/1'), findsOneWidget);
    });

    testWidgets('cambiar de modo borra lo que se había contestado',
        (tester) async {
      await _abrir(tester);
      await tester.tap(find.text('Butto'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Escribir'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Elegir'));
      await tester.pumpAndSettle();

      // Vuelve el hueco vacío, no la respuesta que estaba elegida.
      expect(find.textContaining(hueco, findRichText: true), findsOneWidget);
    });
  });

  group('la explicación', () {
    testWidgets('el botón de info abre el via en todas las personas',
        (tester) async {
      await _abrir(tester);
      await tester.tap(find.byIcon(Icons.info_outline));
      await tester.pumpAndSettle();

      expect(find.text('noi andiamo via'), findsOneWidget);
      expect(find.text('loro vanno via'), findsOneWidget);

      // El resto de la explicación está más abajo, en la misma hoja.
      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await tester.pumpAndSettle();
      expect(find.text('Dónde se pone'), findsOneWidget);
    });

    testWidgets('se cierra y el ejercicio sigue donde estaba', (tester) async {
      await _abrir(tester);
      await tester.tap(find.text('Butto'));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.info_outline));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Butto via il giornale', findRichText: true),
        findsOneWidget,
      );
    });
  });

  testWidgets('sin frases cargadas lo avisa', (tester) async {
    await _abrir(tester, '{"version": 1, "frases": []}');

    expect(find.text('Todavía no hay frases cargadas.'), findsOneWidget);
  });
}
