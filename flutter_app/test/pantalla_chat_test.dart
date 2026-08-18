import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tukyliano/datos/almacenamiento_clave.dart';
import 'package:tukyliano/ia/chat.dart';
import 'package:tukyliano/ia/gemini.dart';
import 'package:tukyliano/main.dart';
import 'package:tukyliano/pantallas/pantalla_chat.dart';
import 'package:tukyliano/tema.dart';

import 'util_pantalla.dart';
import 'voz_falsa.dart';

/// Los pedidos que salieron a la API, ya decodificados.
class _Espia {
  final List<Map<String, dynamic>> pedidos = [];

  /// Los turnos del último pedido: el historial que se le mandó a la IA.
  List<Map<String, dynamic>> get ultimosTurnos =>
      (pedidos.last['contents'] as List).cast<Map<String, dynamic>>();

  String textoDe(int turno) =>
      ((ultimosTurnos[turno]['parts'] as List).first as Map)['text'] as String;
}

/// Carpeta de verdad para la clave: es lo que en el celular es la carpeta
/// privada de la app.
Directory _carpeta() {
  final dir = Directory.systemTemp.createTempSync('tukyliano_clave');
  addTearDown(() => dir.deleteSync(recursive: true));
  return dir;
}

/// Gemini de mentira: contesta lo que se le diga y anota lo que le pidieron.
Gemini _gemini(_Espia espia, {String respuesta = 'Bene! E tu?', int estado = 200}) {
  return Gemini(
    cliente: MockClient((pedido) async {
      espia.pedidos.add(jsonDecode(pedido.body) as Map<String, dynamic>);
      if (estado != 200) {
        return http.Response(
          '{"error": {"message": "API key not valid"}}',
          estado,
        );
      }
      return http.Response(
        jsonEncode({
          'candidates': [
            {
              'content': {
                'parts': [
                  {'text': respuesta},
                ],
              },
            },
          ],
        }),
        200,
        // Sin el charset la respuesta se leería en latin1 y los acentos
        // italianos llegarían roto.
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }),
  );
}

Future<_Espia> _abrir(
  WidgetTester tester, {
  String? claveGuardada = 'clave-de-prueba',
  String respuesta = 'Bene! E tu?',
  int estado = 200,
  VozFalsa? voz,
  Directory? carpeta,
}) async {
  final dir = carpeta ?? _carpeta();
  if (claveGuardada != null) {
    File('${dir.path}/$archivoClave').writeAsStringSync(claveGuardada);
  }

  final espia = _Espia();
  usarPantallaDeCelular(tester);
  await tester.pumpWidget(MaterialApp(
    theme: Tema.datos,
    home: Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(14),
        child: PantallaChat(
          almacenClave: AlmacenamientoClave(carpeta: () async => dir),
          gemini: _gemini(espia, respuesta: respuesta, estado: estado),
          voz: voz ?? VozFalsa(),
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
  return espia;
}

/// Escribe con el teclado propio de la app, tecla por tecla.
Future<void> _escribir(WidgetTester tester, String texto) async {
  for (final letra in texto.split('')) {
    final tecla = letra == ' '
        ? find.widgetWithText(ElevatedButton, 'espacio')
        : find.widgetWithText(ElevatedButton, letra);
    await tester.tap(tecla);
    await tester.pump();
  }
}

ElevatedButton _botonEnviar(WidgetTester tester) => tester.widget<ElevatedButton>(
      find.ancestor(
        of: find.byIcon(Icons.send_rounded),
        matching: find.byType(ElevatedButton),
      ),
    );

Future<void> _enviar(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.send_rounded));
  await tester.pumpAndSettle();
}

void main() {
  group('la clave', () {
    testWidgets('sin clave guardada la pide antes de charlar', (tester) async {
      await _abrir(tester, claveGuardada: null);

      expect(
        find.text('Necesitás una clave gratis de la IA (Gemini)'),
        findsOneWidget,
      );
      expect(find.text(saludoInicial), findsNothing);
    });

    testWidgets('la clave pegada queda en el celular, nunca en el código',
        (tester) async {
      final dir = _carpeta();
      // El portapapeles del celular, con la clave ya copiada del navegador.
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (llamada) async => llamada.method == 'Clipboard.getData'
            ? <String, dynamic>{'text': 'clave-pegada-a-mano'}
            : null,
      );
      addTearDown(() => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null));

      await _abrir(tester, claveGuardada: null, carpeta: dir);
      await tester.tap(find.text('Pegar clave'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      expect(File('${dir.path}/$archivoClave').readAsStringSync(),
          'clave-pegada-a-mano');
      expect(find.text(saludoInicial), findsOneWidget);
    });

    testWidgets('si la clave no sirve la borra y la pide de nuevo',
        (tester) async {
      final dir = _carpeta();
      await _abrir(tester, estado: 400, carpeta: dir);

      await _escribir(tester, 'ciao');
      await _enviar(tester);

      expect(find.textContaining('La clave no funcionó'), findsOneWidget);
      // Una credencial que ya no vale no tiene por qué seguir guardada.
      expect(File('${dir.path}/$archivoClave').existsSync(), isFalse);
    });
  });

  group('la charla', () {
    testWidgets('arranca con el saludo, sin pedirle nada a la IA',
        (tester) async {
      final espia = await _abrir(tester);

      expect(find.text(saludoInicial), findsOneWidget);
      expect(espia.pedidos, isEmpty);
    });

    testWidgets('se escribe con el teclado propio y contesta la IA',
        (tester) async {
      final espia = await _abrir(tester, respuesta: 'Bene! E tu?');

      await _escribir(tester, 'ciao');
      expect(find.text('ciao'), findsOneWidget);
      await _enviar(tester);

      expect(espia.textoDe(2), 'ciao');
      expect(find.text('Bene! E tu?'), findsOneWidget);
      // El campo queda limpio para el mensaje siguiente.
      expect(find.text('Escribí en italiano...'), findsOneWidget);
    });

    testWidgets('el teclado propio tiene la almohadilla y los acentos',
        (tester) async {
      await _abrir(tester);

      expect(find.widgetWithText(ElevatedButton, '#'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, '?'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'è'), findsOneWidget);
    });

    testWidgets('vacío no se puede enviar', (tester) async {
      await _abrir(tester);

      expect(_botonEnviar(tester).onPressed, isNull);

      await _escribir(tester, 'a');
      expect(_botonEnviar(tester).onPressed, isNotNull);
    });

    testWidgets('la segunda vuelta le manda la charla entera', (tester) async {
      final espia = await _abrir(tester, respuesta: 'Bene! E tu?');

      await _escribir(tester, 'ciao');
      await _enviar(tester);
      await _escribir(tester, 'bene');
      await _enviar(tester);

      // Instrucciones, saludo, ciao, la respuesta de la IA y bene.
      expect(espia.ultimosTurnos.length, 5);
      expect(espia.textoDe(0), promptDeChat);
      expect(espia.textoDe(2), 'ciao');
      expect(espia.textoDe(3), 'Bene! E tu?');
      expect(espia.textoDe(4), 'bene');
    });

    testWidgets('sin internet avisa y la charla sigue viva', (tester) async {
      final espia = _Espia();
      final dir = _carpeta();
      File('${dir.path}/$archivoClave').writeAsStringSync('clave-de-prueba');

      usarPantallaDeCelular(tester);
      await tester.pumpWidget(MaterialApp(
        theme: Tema.datos,
        home: Scaffold(
          body: PantallaChat(
            almacenClave: AlmacenamientoClave(carpeta: () async => dir),
            gemini: Gemini(
              cliente: MockClient((_) async => throw const SocketException('')),
            ),
            voz: VozFalsa(),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      await _escribir(tester, 'ciao');
      await _enviar(tester);

      expect(find.textContaining('Fijate si tenés internet'), findsOneWidget);
      // Lo escrito no se pierde de la pantalla y se puede seguir escribiendo.
      expect(find.text('ciao'), findsOneWidget);
      expect(espia.pedidos, isEmpty);
    });
  });

  group('las traducciones con almohadillas', () {
    testWidgets('una palabra entre almohadillas se manda como pedido',
        (tester) async {
      final espia = await _abrir(tester, respuesta: '#manteca# = #burro#');

      await _escribir(tester, '#pan#');
      await _enviar(tester);

      expect(espia.textoDe(2), startsWith('#pan#'));
      expect(espia.textoDe(2), contains('#pan# = #(traducción)#'));
    });

    testWidgets('la traducción que contesta se ve en la charla',
        (tester) async {
      await _abrir(tester, respuesta: '#manteca# = #burro#\nChe cucini?');

      await _escribir(tester, 'a');
      await _enviar(tester);

      expect(find.text('#manteca# = #burro#\nChe cucini?'), findsOneWidget);
    });

    testWidgets('un pedido suelto muestra solo la traducción', (tester) async {
      // Pedir una palabra es ir al diccionario: la charla de más se recorta,
      // aunque la IA la haya escrito igual.
      await _abrir(
        tester,
        respuesta: '#manteca# = #burro#\n\nCapisco, cosa prepari?',
      );

      await _escribir(tester, '#manteca#');
      await _enviar(tester);

      expect(find.text('#manteca# = #burro#'), findsOneWidget);
      expect(find.textContaining('Capisco'), findsNothing);
    });

    testWidgets('un pedido en medio de una frase no corta la charla',
        (tester) async {
      await _abrir(
        tester,
        respuesta: '#manteca# = #burro#\n\nCapisco, cosa prepari?',
      );

      await _escribir(tester, 'mi serve #manteca#');
      await _enviar(tester);

      expect(find.textContaining('Capisco, cosa prepari?'), findsOneWidget);
    });
  });

  group('solo escuchar', () {
    testWidgets('la respuesta se dice y no se muestra', (tester) async {
      final voz = VozFalsa();
      await _abrir(tester, respuesta: 'Bene! E tu?', voz: voz);

      await tester.tap(find.text('Solo escuchar'));
      await tester.pumpAndSettle();
      await _escribir(tester, 'ciao');
      await _enviar(tester);

      expect(find.text('Bene! E tu?'), findsNothing);
      expect(find.text('Tocá para repetir'), findsOneWidget);
      expect(voz.dicho, contains('Bene! E tu?'));
    });

    testWidgets('el ojito destapa la respuesta que no se entendió',
        (tester) async {
      await _abrir(tester, respuesta: 'Bene! E tu?');

      await tester.tap(find.text('Solo escuchar'));
      await tester.pumpAndSettle();
      await _escribir(tester, 'ciao');
      await _enviar(tester);
      await tester.tap(find.byIcon(Icons.visibility_outlined));
      await tester.pumpAndSettle();

      expect(find.text('Bene! E tu?'), findsOneWidget);
    });

    testWidgets('el audio va sin las almohadillas', (tester) async {
      final voz = VozFalsa();
      await _abrir(tester, respuesta: '#manteca# = #burro#', voz: voz);

      await tester.tap(find.text('Solo escuchar'));
      await tester.pumpAndSettle();
      await _escribir(tester, 'a');
      await _enviar(tester);

      expect(voz.dicho, contains('manteca = burro'));
    });

    testWidgets('lo que ya se leyó no se tapa al prender el modo',
        (tester) async {
      await _abrir(tester);

      await tester.tap(find.text('Solo escuchar'));
      await tester.pumpAndSettle();

      expect(find.text(saludoInicial), findsOneWidget);
    });

    testWidgets('apagar el modo destapa todo lo anterior', (tester) async {
      await _abrir(tester, respuesta: 'Bene! E tu?');

      await tester.tap(find.text('Solo escuchar'));
      await tester.pumpAndSettle();
      await _escribir(tester, 'a');
      await _enviar(tester);
      await tester.tap(find.text('Solo escuchar'));
      await tester.pumpAndSettle();

      expect(find.text('Bene! E tu?'), findsOneWidget);
    });

    testWidgets('con el modo apagado se toca la burbuja para escucharla',
        (tester) async {
      final voz = VozFalsa();
      await _abrir(tester, respuesta: 'Bene! E tu?', voz: voz);

      await _escribir(tester, 'a');
      await _enviar(tester);
      expect(voz.dicho, isEmpty);

      await tester.tap(find.text('Bene! E tu?'));
      await tester.pumpAndSettle();

      expect(voz.dicho, ['Bene! E tu?']);
    });

    testWidgets('sin la voz italiana instalada no se ofrece el modo',
        (tester) async {
      // Hablar italiano con los sonidos de otro idioma enseña mal, así que ahí
      // no hay nada que escuchar: se avisa cómo instalarla.
      await _abrir(tester, voz: VozFalsa(hayItaliano: false));

      expect(find.text('Solo escuchar'), findsNothing);
      expect(find.textContaining('instalá la voz italiana'), findsOneWidget);
    });
  });

  group('la memoria', () {
    testWidgets('salir de la pestaña y volver borra la charla', (tester) async {
      final dir = _carpeta();
      File('${dir.path}/$archivoClave').writeAsStringSync('clave-de-prueba');
      final espia = _Espia();

      usarPantallaDeCelular(tester);
      await tester.pumpWidget(TukylianoApp(
        almacenClave: AlmacenamientoClave(carpeta: () async => dir),
        gemini: _gemini(espia, respuesta: 'Bene! E tu?'),
        voz: VozFalsa(),
      ));
      await tester.pumpAndSettle();

      Future<void> irA(String seccion) async {
        final boton = find.widgetWithText(ElevatedButton, seccion);
        await tester.scrollUntilVisible(
          boton,
          80,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(boton);
        await tester.pumpAndSettle();
      }

      await irA('Chat');
      await _escribir(tester, 'ciao');
      await _enviar(tester);
      expect(find.text('Bene! E tu?'), findsOneWidget);

      await irA('Frasi');
      await irA('Chat');

      // Ni lo que escribí ni lo que contestó: la charla arranca de cero.
      expect(find.text('ciao'), findsNothing);
      expect(find.text('Bene! E tu?'), findsNothing);
      expect(find.text(saludoInicial), findsOneWidget);

      await _escribir(tester, 'ciao');
      await _enviar(tester);

      // Instrucciones, saludo y el mensaje: nada de la charla anterior.
      expect(espia.ultimosTurnos.length, 3);
    });
  });
}
