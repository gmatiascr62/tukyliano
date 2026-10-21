import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tukyliano/datos/descarga_modelo.dart';
import 'package:tukyliano/ia/chat.dart';
import 'package:tukyliano/ia/modelo.dart';
import 'package:tukyliano/pantallas/pantalla_chat.dart';
import 'package:tukyliano/tema.dart';
import 'package:tukyliano/widgets/pastilla.dart';

import 'motor_falso.dart';
import 'util_pantalla.dart';
import 'voz_falsa.dart';

/// La semilla que usan los tests: con ella la charla arranca siempre con el
/// mismo saludo, aunque en el celular salga uno al azar.
const _semilla = 3;
final _saludoFijo = saludoAlAzar(azar: Random(_semilla));

final List<int> _modeloFalso = utf8.encode('hace de modelo' * 50);

/// Una carpeta con el modelo ya bajado, como la de alguien que ya lo tiene.
Directory _carpetaConModelo({bool conModelo = true}) {
  final dir = Directory.systemTemp.createTempSync('chat_modelo');
  addTearDown(() => dir.deleteSync(recursive: true));
  if (conModelo) {
    File('${dir.path}/$archivoDelModelo').writeAsBytesSync(_modeloFalso);
  }
  return dir;
}

DescargaModelo _descarga(Directory dir) => DescargaModelo(
      cliente: MockClient.streaming(
        (_, _) async => http.StreamedResponse(
          Stream.fromIterable([_modeloFalso]),
          200,
          contentLength: _modeloFalso.length,
        ),
      ),
      carpeta: () async => dir,
      huellaEsperada: sha256.convert(_modeloFalso).toString(),
    );

Future<MotorFalso> _abrir(
  WidgetTester tester, {
  MotorFalso? motor,
  VozFalsa? voz,
  Directory? carpeta,
}) async {
  final elMotor = motor ?? MotorFalso();
  usarPantallaDeCelular(tester);
  await tester.pumpWidget(MaterialApp(
    theme: Tema.datos,
    home: Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(14),
        child: PantallaChat(
          descarga: _descarga(carpeta ?? _carpetaConModelo()),
          motor: elMotor,
          voz: voz ?? VozFalsa(),
          azar: Random(_semilla),
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
  return elMotor;
}

Future<void> _escribir(WidgetTester tester, String texto) async {
  await tester.enterText(find.byType(TextField), texto);
  await tester.pump();
}

Future<void> _enviar(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.send_rounded));
  await tester.pumpAndSettle();
}

ElevatedButton _botonDeEnviar(WidgetTester tester) =>
    tester.widget<ElevatedButton>(
      find.ancestor(
        of: find.byIcon(Icons.send_rounded),
        matching: find.byType(ElevatedButton),
      ),
    );

void main() {
  group('la charla', () {
    testWidgets('arranca con el saludo, sin molestar al modelo',
        (tester) async {
      final motor = await _abrir(tester);

      expect(find.text(_saludoFijo), findsOneWidget);
      expect(motor.prompts, isEmpty);
    });

    testWidgets('lo que escribo sale a la derecha y la respuesta a la izquierda',
        (tester) async {
      await _abrir(tester, motor: MotorFalso(respuesta: 'Bene! E tu?'));

      await _escribir(tester, 'ciao');
      await _enviar(tester);

      expect(find.text('ciao'), findsOneWidget);
      expect(find.text('Bene! E tu?'), findsOneWidget);
    });

    testWidgets('al modelo le llega el prompt con las instrucciones',
        (tester) async {
      final motor = await _abrir(tester);

      await _escribir(tester, 'ciao');
      await _enviar(tester);

      expect(motor.prompts.single, contains(promptDeChat));
      expect(motor.prompts.single, contains('<|im_start|>user\nciao'));
    });

    testWidgets('sin escribir nada el botón está apagado', (tester) async {
      await _abrir(tester);

      expect(_botonDeEnviar(tester).onPressed, isNull);

      await _escribir(tester, 'ciao');
      expect(_botonDeEnviar(tester).onPressed, isNotNull);
    });

    testWidgets('no manda nada a ningún servidor', (tester) async {
      // Lo que se escribe en el chat no sale del celular: el modelo corre
      // adentro. Si algún día alguien vuelve a poner una llamada a una API,
      // este test tiene que avisar.
      final motor = await _abrir(tester);

      await _escribir(tester, 'mi chiamo Matías');
      await _enviar(tester);

      expect(motor.prompts, hasLength(1));
      expect(motor.liberado, isFalse);
    });
  });

  group('mientras contesta', () {
    testWidgets('se ve lo que lleva escrito', (tester) async {
      // El modelo en el celular tarda varios segundos: mostrar la respuesta
      // recién al final parecería que se colgó.
      await _abrir(
        tester,
        motor: MotorFalso(
          pedazos: const ['Ciao', '! Come', ' stai?'],
          demora: const Duration(milliseconds: 50),
        ),
      );

      await _escribir(tester, 'ciao');
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      await tester.pump(const Duration(milliseconds: 60));

      expect(find.textContaining('Ciao'), findsWidgets);

      await tester.pumpAndSettle();
      expect(find.text('Ciao! Come stai?'), findsOneWidget);
    });

    testWidgets('el botón pasa a ser el de cortar', (tester) async {
      await _abrir(
        tester,
        motor: MotorFalso(
          pedazos: const ['Ciao', '!'],
          demora: const Duration(milliseconds: 50),
        ),
      );

      await _escribir(tester, 'ciao');
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pump();

      expect(find.byIcon(Icons.stop_rounded), findsOneWidget);
      expect(find.byIcon(Icons.send_rounded), findsNothing);

      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.send_rounded), findsOneWidget);
    });

    testWidgets('cortar deja lo que llegó hasta ahí', (tester) async {
      final motor = MotorFalso(
        pedazos: const ['Ciao', ' Matías', ' come stai'],
        demora: const Duration(milliseconds: 50),
      );
      await _abrir(tester, motor: motor);

      await _escribir(tester, 'ciao');
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));

      await tester.tap(find.byIcon(Icons.stop_rounded));
      await tester.pumpAndSettle();

      expect(motor.cortes, 1);
      expect(find.text('Ciao'), findsOneWidget);
      expect(find.byIcon(Icons.send_rounded), findsOneWidget);
    });

    testWidgets('no se puede mandar otro mensaje encima', (tester) async {
      // Una sola generación por vez: dos a la vez no entran en la memoria de
      // un celular.
      await _abrir(
        tester,
        motor: MotorFalso(
          pedazos: const ['Ciao'],
          demora: const Duration(milliseconds: 50),
        ),
      );

      await _escribir(tester, 'ciao');
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pump();

      expect(find.byIcon(Icons.send_rounded), findsNothing);
      await tester.pumpAndSettle();
    });
  });

  group('las traducciones', () {
    testWidgets('un pedido solo va por su propio prompt', (tester) async {
      final motor = await _abrir(tester, motor: MotorFalso(respuesta: 'burro'));

      await _escribir(tester, '#manteca#');
      await _enviar(tester);

      expect(motor.prompts.single, contains(promptDeTraduccion));
      expect(motor.prompts.single, isNot(contains(promptDeChat)));
      expect(find.text('#manteca# = #burro#'), findsOneWidget);
    });

    testWidgets('si contesta de más, se queda con la palabra', (tester) async {
      // Un modelo chico a veces contesta "burro, que es manteca en italiano".
      await _abrir(
        tester,
        motor: MotorFalso(respuesta: 'burro, que significa manteca'),
      );

      await _escribir(tester, '#manteca#');
      await _enviar(tester);

      expect(find.text('#manteca# = #burro#'), findsOneWidget);
    });

    testWidgets('en medio de una frase, la charla sigue como siempre',
        (tester) async {
      final motor = await _abrir(tester);

      await _escribir(tester, 'mi serve la #manteca#');
      await _enviar(tester);

      expect(motor.prompts.single, contains(promptDeChat));
    });
  });

  group('las correcciones', () {
    testWidgets('las reglas corrigen aunque el modelo no se dé cuenta',
        (tester) async {
      // Un modelo de 0.6B no ve la mitad de los errores. Estos no dependen de
      // él.
      await _abrir(tester, motor: MotorFalso(respuesta: 'Tutto bene!'));

      await _escribir(tester, 'no capisco perche');
      await _enviar(tester);

      expect(
        find.textContaining('Correzione: non capisco perché'),
        findsOneWidget,
      );
    });

    testWidgets('si el modelo ya corrigió, no se corrige dos veces',
        (tester) async {
      await _abrir(
        tester,
        motor: MotorFalso(respuesta: 'Correzione: non capisco\nTutto bene!'),
      );

      await _escribir(tester, 'no capisco');
      await _enviar(tester);

      final burbuja = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.textSpan?.toPlainText() ?? t.data ?? '')
          .firstWhere((t) => t.contains('Correzione'));
      expect('Correzione:'.allMatches(burbuja).length, 1);
    });

    testWidgets('una frase bien escrita no se corrige', (tester) async {
      await _abrir(tester, motor: MotorFalso(respuesta: 'Tutto bene!'));

      await _escribir(tester, 'Ciao! Come stai?');
      await _enviar(tester);

      expect(find.textContaining('Correzione'), findsNothing);
    });
  });

  group('cuando algo sale mal', () {
    testWidgets('un error del motor se cuenta en castellano', (tester) async {
      await _abrir(
        tester,
        motor: MotorFalso(
          error: const ProblemaDelMotorFalso('No hay memoria suficiente.'),
        ),
      );

      await _escribir(tester, 'ciao');
      await _enviar(tester);

      expect(find.textContaining('no pudo contestar'), findsOneWidget);
    });

    testWidgets('si el modelo no carga, lo dice y deja borrarlo',
        (tester) async {
      await _abrir(
        tester,
        motor: MotorFalso(
          seCargaBien: false,
          problemaAlCargar: 'Este celular no puede correr el modelo.',
        ),
      );

      expect(
        find.text('Este celular no puede correr el modelo.'),
        findsOneWidget,
      );
      expect(find.textContaining('Borrar la IA'), findsOneWidget);
      expect(find.textContaining('El resto de la app funciona igual'),
          findsOneWidget);
    });
  });

  group('la memoria del celular', () {
    testWidgets('al salir de la pantalla, el modelo se descarga',
        (tester) async {
      // Son cientos de megas: si quedaran ocupados, Android mataría la app
      // apenas se abra otra cosa.
      final motor = MotorFalso();
      await _abrir(tester, motor: motor);

      await tester.pumpWidget(const MaterialApp(home: Scaffold()));
      await tester.pumpAndSettle();

      expect(motor.liberado, isTrue);
    });
  });

  group('otro tema', () {
    testWidgets('empieza una charla nueva, con otro saludo', (tester) async {
      await _abrir(tester);
      await _escribir(tester, 'ciao');
      await _enviar(tester);

      await tester.tap(find.text('Otro tema'));
      await tester.pumpAndSettle();

      expect(find.text('ciao'), findsNothing);
      expect(find.text(_saludoFijo), findsNothing);
      expect(find.textContaining('Sono Tuky'), findsOneWidget);
    });

    testWidgets('mientras contesta, el botón no se puede tocar',
        (tester) async {
      await _abrir(
        tester,
        motor: MotorFalso(
          pedazos: const ['Ciao'],
          demora: const Duration(milliseconds: 50),
        ),
      );

      await _escribir(tester, 'ciao');
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pump();

      final pastilla = tester.widget<Pastilla>(
        find.widgetWithText(Pastilla, 'Otro tema'),
      );
      expect(pastilla.alTocar, isNull);

      await tester.pumpAndSettle();
    });
  });

  group('solo escuchar', () {
    testWidgets('tapa la respuesta y la dice en voz alta', (tester) async {
      final voz = VozFalsa();
      await _abrir(tester, motor: MotorFalso(respuesta: 'Bene!'), voz: voz);

      await tester.tap(find.text('Solo escuchar'));
      await tester.pumpAndSettle();
      await _escribir(tester, 'ciao');
      await _enviar(tester);

      expect(find.text('Bene!'), findsNothing);
      expect(find.text('Tocá para repetir'), findsOneWidget);
      expect(voz.dicho, contains('Bene!'));
    });

    testWidgets('el ojito destapa lo que no se entendió', (tester) async {
      await _abrir(tester, motor: MotorFalso(respuesta: 'Bene!'));

      await tester.tap(find.text('Solo escuchar'));
      await tester.pumpAndSettle();
      await _escribir(tester, 'ciao');
      await _enviar(tester);

      await tester.tap(find.byIcon(Icons.visibility_outlined));
      await tester.pumpAndSettle();

      expect(find.text('Bene!'), findsOneWidget);
    });
  });
}

/// Un error cualquiera del motor, para probar qué se muestra.
class ProblemaDelMotorFalso implements Exception {
  const ProblemaDelMotorFalso(this.mensaje);
  final String mensaje;
}
