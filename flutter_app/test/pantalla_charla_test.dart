import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tukyliano/datos/repositorio_charlas.dart';
import 'package:tukyliano/pantallas/pantalla_charla.dart';
import 'package:tukyliano/tema.dart';

import 'util_pantalla.dart';
import 'voz_falsa.dart';

const _guion = '''
{
  "version": 1,
  "charlas": [
    {
      "id": "bar",
      "titulo": "Al bar",
      "donde": "Entrás a un bar.",
      "primero": "saludo",
      "pasos": [
        {
          "id": "saludo",
          "dice": "Cosa prende?",
          "espanol": "¿Qué va a tomar?",
          "respuestas": [
            {
              "texto": "Un caffè, per favore",
              "espanol": "Un café, por favor",
              "claves": ["caffe"],
              "sigue": "fin"
            }
          ]
        },
        {
          "id": "fin",
          "dice": "Grazie e arrivederci!",
          "espanol": "¡Gracias y hasta luego!",
          "respuestas": []
        }
      ]
    }
  ]
}
''';

Future<VozFalsa> _abrir(WidgetTester tester) async {
  final voz = VozFalsa();
  usarPantallaDeCelular(tester);
  await tester.pumpWidget(MaterialApp(
    theme: Tema.datos,
    home: Scaffold(
      body: PantallaCharla(
        repositorio: RepositorioCharlas(leerAsset: (_) async => _guion),
        voz: voz,
      ),
    ),
  ));
  await tester.pumpAndSettle();
  return voz;
}

Future<void> _contestar(WidgetTester tester, String texto) async {
  await tester.enterText(find.byType(TextField), texto);
  await tester.pumpAndSettle();
  await tester.tap(find.byIcon(Icons.send_rounded));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('arranca con la escena y lo que dice Tuky', (tester) async {
    await _abrir(tester);

    expect(find.text('Entrás a un bar.'), findsOneWidget);
    expect(find.text('Cosa prende?'), findsOneWidget);
    // La traducción va abajo: es para aprender, no para adivinar.
    expect(find.text('¿Qué va a tomar?'), findsOneWidget);
  });

  testWidgets('las opciones no se ven hasta que se piden', (tester) async {
    await _abrir(tester);

    expect(find.text('Podés decir:'), findsNothing);

    await tester.tap(find.byIcon(Icons.help_outline));
    await tester.pumpAndSettle();

    expect(find.text('Podés decir:'), findsOneWidget);
    expect(find.text('Un caffè, per favore'), findsOneWidget);
  });

  testWidgets('contestar bien hace avanzar la charla, sin corregir',
      (tester) async {
    await _abrir(tester);
    await _contestar(tester, 'Un caffè, per favore');

    expect(find.text('Grazie e arrivederci!'), findsOneWidget);
    expect(find.text('Se dice así:'), findsNothing);
  });

  testWidgets('decirlo mal muestra cómo se dice y la charla sigue igual',
      (tester) async {
    await _abrir(tester);
    await _contestar(tester, 'io volere un caffè');

    expect(find.text('Se dice así:'), findsOneWidget);
    // La frase correcta sale del guion: no puede estar mal.
    expect(find.text('Un caffè, per favore'), findsOneWidget);
    // Y no se frena: el error ya quedó mostrado.
    expect(find.text('Grazie e arrivederci!'), findsOneWidget);
  });

  testWidgets('lo que no se entiende lo dice y deja ver las opciones',
      (tester) async {
    await _abrir(tester);
    await _contestar(tester, 'dove è la stazione?');

    expect(find.text('Non ho capito. Puoi ripetere?'), findsOneWidget);
    expect(find.text('Podés decir:'), findsOneWidget);
    // No avanzó.
    expect(find.text('Grazie e arrivederci!'), findsNothing);
  });

  testWidgets('tocar una opción la escribe en el campo, no la manda',
      (tester) async {
    await _abrir(tester);
    await tester.tap(find.byIcon(Icons.help_outline));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Un caffè, per favore'));
    await tester.pumpAndSettle();

    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'Un caffè, per favore',
    );
    // Sigue sin avanzar: todavía hay que mandarla.
    expect(find.text('Grazie e arrivederci!'), findsNothing);
  });

  testWidgets('al final ofrece empezar de nuevo', (tester) async {
    await _abrir(tester);
    await _contestar(tester, 'Un caffè, per favore');

    expect(find.text('Terminó la charla.'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);

    await tester.tap(find.text('Empezar de nuevo'));
    await tester.pumpAndSettle();

    expect(find.text('Cosa prende?'), findsOneWidget);
    expect(find.text('Grazie e arrivederci!'), findsNothing);
  });

  testWidgets('tocar lo que dice Tuky lo pronuncia', (tester) async {
    final voz = await _abrir(tester);

    await tester.tap(find.text('Cosa prende?'));
    await tester.pumpAndSettle();

    expect(voz.dicho, ['Cosa prende?']);
  });

  testWidgets('sin guion lo avisa y no se cae', (tester) async {
    usarPantallaDeCelular(tester);
    await tester.pumpWidget(MaterialApp(
      theme: Tema.datos,
      home: Scaffold(
        body: PantallaCharla(
          repositorio: RepositorioCharlas(leerAsset: (_) async => 'roto'),
          voz: VozFalsa(),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('No se pudo abrir la charla.'), findsOneWidget);
  });
}
