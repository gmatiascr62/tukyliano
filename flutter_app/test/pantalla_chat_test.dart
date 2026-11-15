import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tukyliano/datos/quien_soy.dart';
import 'package:tukyliano/datos/repositorio_diccionario.dart';
import 'package:tukyliano/ia/chat.dart';
import 'package:tukyliano/ia/servidor.dart';
import 'package:tukyliano/main.dart';
import 'package:tukyliano/pantallas/pantalla_chat.dart';
import 'package:tukyliano/pantallas/pantalla_inicio.dart';
import 'package:tukyliano/tema.dart';
import 'package:tukyliano/widgets/pastilla.dart';

import 'util_pantalla.dart';
import 'voz_falsa.dart';

/// Los pedidos que salieron al servidor, ya decodificados.
class _Espia {
  final List<Map<String, dynamic>> pedidos = [];

  /// Los mensajes del último pedido: el historial que viajó.
  ///
  /// El saludo va aparte en el pedido, así que se suma acá adelante para que
  /// los índices sigan contando la charla entera, como antes.
  List<Map<String, dynamic>> get ultimosTurnos => [
        {'quien': 'ia', 'texto': pedidos.last['saludo']},
        ...(pedidos.last['mensajes'] as List).cast<Map<String, dynamic>>(),
      ];

  String textoDe(int turno) => ultimosTurnos[turno]['texto'] as String;
}

/// Carpeta de verdad para la clave: es lo que en el celular es la carpeta
/// privada de la app.
Directory _carpeta() {
  final dir = Directory.systemTemp.createTempSync('tukyliano_clave');
  addTearDown(() => dir.deleteSync(recursive: true));
  return dir;
}

/// La semilla fija hace que el saludo con el que arranca la charla sea
/// siempre el mismo, así los tests pueden nombrarlo.
const _semilla = 3;
final _saludoFijo = saludoAlAzar(azar: Random(_semilla));

/// Servidor de mentira: contesta lo que se le diga y anota lo que le pidieron.
Servidor _servidor(
  _Espia espia, {
  String respuesta = 'Bene! E tu?',
  int estado = 200,
  Duration demora = Duration.zero,
}) {
  return Servidor(
    url: 'https://servidor-de-mentira',
    cliente: MockClient((pedido) async {
      espia.pedidos.add(jsonDecode(pedido.body) as Map<String, dynamic>);
      // Para los tests que miran qué pasa mientras la IA todavía no contestó.
      if (demora > Duration.zero) await Future<void>.delayed(demora);
      if (estado != 200) {
        return http.Response(
          jsonEncode({
            'error': 'caido',
            'mensaje': 'La IA no está respondiendo. Probá en un rato.',
          }),
          estado,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      return http.Response(
        jsonEncode({'texto': respuesta}),
        200,
        // Sin el charset la respuesta se leería en latin1 y los acentos
        // italianos llegarían rotos.
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }),
  );
}

/// Un diccionario chico y conocido: los tests no tienen por qué depender de
/// las catorce mil palabras del de verdad.
const String _diccionarioDePrueba = '''
{
  "version": 1,
  "credito": "de prueba",
  "it": {"burro": ["manteca"], "pane": ["pan"], "finestra": ["ventana"]},
  "es": {"manteca": ["burro"], "pan": ["pane"], "ventana": ["finestra"]}
}
''';

Future<_Espia> _abrir(
  WidgetTester tester, {
  String respuesta = 'Bene! E tu?',
  int estado = 200,
  VozFalsa? voz,
  Directory? carpeta,
  Duration demora = Duration.zero,
  Escena escena = Escena.libre,
}) async {
  final dir = carpeta ?? _carpeta();
  final espia = _Espia();
  usarPantallaDeCelular(tester);
  await tester.pumpWidget(MaterialApp(
    theme: Tema.datos,
    home: Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(14),
        child: PantallaChat(
          escena: escena,
          servidor: _servidor(
            espia,
            respuesta: respuesta,
            estado: estado,
            demora: demora,
          ),
          quienSoy: QuienSoy(carpeta: () async => dir),
          voz: voz ?? VozFalsa(),
          diccionario: RepositorioDiccionario(
            leerAsset: (_) async => _diccionarioDePrueba,
          ),
          azar: Random(_semilla),
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
  return espia;
}

/// Escribe con el teclado del celular, que es el que usa el chat.
Future<void> _escribir(WidgetTester tester, String texto) async {
  await tester.enterText(find.byType(TextField), texto);
  await tester.pump();
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
  group('quién soy', () {
    testWidgets('el número del celular se inventa una vez y se guarda',
        (tester) async {
      // Es lo único que viaja al servidor para identificar al celular, y
      // existe para repartir los topes: sin él, el primero que charlara toda
      // la tarde dejaría a los demás sin mensajes.
      final dir = _carpeta();
      final espia = await _abrir(tester, carpeta: dir);

      await _escribir(tester, 'ciao');
      await _enviar(tester);
      final primero = espia.pedidos.last['quien'] as String;

      expect(primero, isNotEmpty);
      expect(File('${dir.path}/$archivoQuien').readAsStringSync(), primero);

      await _escribir(tester, 'bene');
      await _enviar(tester);
      expect(espia.pedidos.last['quien'], primero, reason: 'no puede cambiar');
    });

    testWidgets('no viaja ninguna clave', (tester) async {
      final espia = await _abrir(tester);

      await _escribir(tester, 'ciao');
      await _enviar(tester);

      // El pedido lleva quién, el código de invitación, en qué escena está,
      // el saludo y la charla. Nada más: el modelo lo corre el servidor.
      expect(
        espia.pedidos.last.keys.toSet(),
        {'quien', 'codigo', 'escena', 'saludo', 'mensajes'},
      );
    });
  });

  group('la charla', () {
    testWidgets('arranca con el saludo, sin pedirle nada a la IA',
        (tester) async {
      final espia = await _abrir(tester);

      expect(find.text(_saludoFijo), findsOneWidget);
      expect(espia.pedidos, isEmpty);
    });

    testWidgets('se escribe con el teclado propio y contesta la IA',
        (tester) async {
      final espia = await _abrir(tester, respuesta: 'Bene! E tu?');

      await _escribir(tester, 'ciao');
      expect(find.text('ciao'), findsOneWidget);
      await _enviar(tester);

      expect(espia.textoDe(1), 'ciao');
      expect(find.text('Bene! E tu?'), findsOneWidget);
      // El campo queda limpio para el mensaje siguiente.
      expect(find.text('Escribí en italiano...'), findsOneWidget);
    });

    testWidgets('usa el teclado del celular, con corrector',
        (tester) async {
      // En el resto de la app el teclado es propio: corregir una conjugación
      // a medio escribir le resolvería el ejercicio al alumno. Acá son frases
      // enteras y el corrector ayuda.
      await _abrir(tester);

      final campo = tester.widget<TextField>(find.byType(TextField));
      expect(campo.autocorrect, isTrue);
      expect(campo.enableSuggestions, isTrue);
      // Y en peso normal: estaba en semi-negrita y la letra engordaba al
      // escribir la primera, porque el texto gris de ayuda va en normal.
      expect(campo.style?.fontWeight, isNull);
      // Y no está el teclado propio de la app.
      expect(find.widgetWithText(ElevatedButton, 'è'), findsNothing);
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

      // Saludo, ciao, la respuesta de la IA y bene. Las instrucciones ya no
      // viajan: las pone el servidor, que es el que habla con el modelo.
      expect(espia.ultimosTurnos.length, 4);
      expect(espia.textoDe(0), _saludoFijo);
      expect(espia.textoDe(1), 'ciao');
      expect(espia.textoDe(2), 'Bene! E tu?');
      expect(espia.textoDe(3), 'bene');
    });

    testWidgets('sin internet avisa y la charla sigue viva', (tester) async {
      final espia = _Espia();

      usarPantallaDeCelular(tester);
      await tester.pumpWidget(MaterialApp(
        theme: Tema.datos,
        home: Scaffold(
          body: PantallaChat(
            servidor: Servidor(
              url: 'https://servidor-de-mentira',
              cliente: MockClient((_) async => throw const SocketException('')),
            ),
            quienSoy: QuienSoy(carpeta: () async => null),
            voz: VozFalsa(),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      await _escribir(tester, 'ciao');
      await _enviar(tester);

      expect(find.textContaining('No hay internet'), findsOneWidget);
      // Lo escrito no se pierde de la pantalla y se puede seguir escribiendo.
      expect(find.text('ciao'), findsOneWidget);
      expect(espia.pedidos, isEmpty);
    });
  });

  group('las traducciones con almohadillas', () {
    testWidgets('la contesta el diccionario, sin molestar a la IA',
        (tester) async {
      final espia = await _abrir(tester);

      await _escribir(tester, '#manteca#');
      await _enviar(tester);

      expect(find.text('#manteca# = #burro#'), findsOneWidget);
      // Ni un pedido a la API: esto anda sin internet y sin gastar cuota.
      expect(espia.pedidos, isEmpty);
    });

    testWidgets('traduce para el lado que corresponde', (tester) async {
      await _abrir(tester);

      await _escribir(tester, '#finestra#');
      await _enviar(tester);

      expect(find.text('#finestra# = #ventana#'), findsOneWidget);
    });

    testWidgets('la palabra que no está lo dice', (tester) async {
      await _abrir(tester);

      await _escribir(tester, '#sciopero#');
      await _enviar(tester);

      expect(
        find.text('#sciopero# no está en el diccionario.'),
        findsOneWidget,
      );
    });

    testWidgets('un pedido en medio de una frase no corta la charla',
        (tester) async {
      final espia = await _abrir(tester, respuesta: 'Capisco, cosa prepari?');

      await _escribir(tester, 'mi serve #manteca#');
      await _enviar(tester);

      // Arriba la traducción, abajo la charla.
      expect(
        find.text('#manteca# = #burro#\nCapisco, cosa prepari?'),
        findsOneWidget,
      );
      // Y a la IA le llegó la frase sin almohadillas.
      expect(espia.textoDe(1), 'mi serve manteca');
    });

    testWidgets('buscar una palabra no queda en la memoria de la IA',
        (tester) async {
      final espia = await _abrir(tester);

      await _escribir(tester, '#manteca#');
      await _enviar(tester);
      await _escribir(tester, 'ciao');
      await _enviar(tester);

      // Saludo y "ciao": del diccionario, nada.
      expect(espia.ultimosTurnos.length, 2);
      expect(espia.textoDe(1), 'ciao');
    });
  });

  group('la corrección', () {
    testWidgets('no se muestra si corrige con la misma frase que escribí',
        (tester) async {
      // Lo que pasó practicando: "io vado al lavoro" está bien escrito y la
      // corrección repetía la frase igual.
      await _abrir(
        tester,
        respuesta: 'Correzione: io vado al lavoro\n'
            'Lavori sempre così presto la mattina?',
      );

      await _escribir(tester, 'io vado al lavoro');
      await _enviar(tester);

      expect(find.textContaining('Correzione'), findsNothing);
      expect(
        find.text('Lavori sempre così presto la mattina?'),
        findsOneWidget,
      );
    });

    testWidgets('la corrección de verdad sí se muestra', (tester) async {
      await _abrir(
        tester,
        respuesta: 'Correzione: io vado al lavoro\nChe lavoro fai?',
      );

      await _escribir(tester, 'io ando al lavoro');
      await _enviar(tester);

      expect(find.textContaining('Correzione: io vado al lavoro'),
          findsOneWidget);
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

      expect(find.text(_saludoFijo), findsOneWidget);
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
      final espia = _Espia();

      usarPantallaDeCelular(tester);
      await tester.pumpWidget(TukylianoApp(
        servidor: _servidor(espia, respuesta: 'Bene! E tu?'),
        voz: VozFalsa(),
      ));
      await tester.pumpAndSettle();

      // Volver al inicio y entrar a otra cosa: es lo que destruye la pantalla
      // del chat y, con ella, la charla.
      Future<void> volverAlInicio() async {
        while (find.byIcon(Icons.arrow_back).evaluate().isNotEmpty) {
          await tester.tap(find.byIcon(Icons.arrow_back));
          await tester.pumpAndSettle();
        }
      }

      Future<void> irA(Destino destino) async {
        await volverAlInicio();
        await tester.tap(find.byIcon(destino.icono));
        await tester.pumpAndSettle();
        // La sección abre en la charla guionada, que anda sin clave. La charla
        // con la IA es la otra pastilla.
        if (destino == Destino.chat) {
          await tester.tap(find.text('Libre'));
          await tester.pumpAndSettle();
        }
      }

      await irA(Destino.chat);
      await _escribir(tester, 'ciao');
      await _enviar(tester);
      expect(find.text('Bene! E tu?'), findsOneWidget);

      await irA(Destino.gramatica);
      await irA(Destino.chat);

      // Ni lo que escribí ni lo que contestó: la charla arranca de cero.
      expect(find.text('ciao'), findsNothing);
      expect(find.text('Bene! E tu?'), findsNothing);
      // Cuál de los saludos salió es al azar; lo que importa es que hay uno.
      expect(find.textContaining('Sono Tuky'), findsOneWidget);

      await _escribir(tester, 'ciao');
      await _enviar(tester);

      // Saludo y el mensaje: nada de la charla anterior.
      expect(espia.ultimosTurnos.length, 2);
    });
  });

  group('otro tema', () {
    testWidgets('empieza una charla nueva, con otro saludo', (tester) async {
      await _abrir(tester);
      await _escribir(tester, 'ciao');
      await _enviar(tester);
      expect(find.text('Bene! E tu?'), findsOneWidget);

      await tester.tap(find.text('Otro tema'));
      await tester.pumpAndSettle();

      // Lo que se dijo se fue con la charla vieja...
      expect(find.text('ciao'), findsNothing);
      expect(find.text('Bene! E tu?'), findsNothing);
      // ...y el saludo nuevo no es el que ya estaba.
      expect(find.text(_saludoFijo), findsNothing);
      expect(find.textContaining('Sono Tuky'), findsOneWidget);
    });

    testWidgets('la IA tampoco se acuerda de la charla anterior',
        (tester) async {
      final espia = await _abrir(tester);
      await _escribir(tester, 'mi chiamo Matías');
      await _enviar(tester);

      await tester.tap(find.text('Otro tema'));
      await tester.pumpAndSettle();
      await _escribir(tester, 'ciao');
      await _enviar(tester);

      // Saludo nuevo y el mensaje: nada de lo de antes.
      expect(espia.ultimosTurnos.length, 2);
      expect(espia.textoDe(0), isNot(_saludoFijo));
      expect(espia.textoDe(1), 'ciao');
    });

    testWidgets('mientras la IA piensa, el botón no se puede tocar',
        (tester) async {
      // Si no, la respuesta llegaría a una charla que ya no existe.
      await _abrir(tester, demora: const Duration(seconds: 1));
      await _escribir(tester, 'ciao');
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pump();

      expect(find.text('Tuky está escribiendo...'), findsOneWidget);
      final pastilla = tester.widget<Pastilla>(
        find.widgetWithText(Pastilla, 'Otro tema'),
      );
      expect(pastilla.alTocar, isNull);

      await tester.pumpAndSettle(const Duration(seconds: 2));
    });
  });

  group('el bar', () {
    testWidgets('arranca con el barista preguntando qué tomás',
        (tester) async {
      await _abrir(tester, escena: Escena.bar);

      expect(find.text(saludoAlAzar(escena: Escena.bar, azar: Random(_semilla))),
          findsOne);
      // El saludo del bar es otro, no uno de los de Tuky.
      expect(find.text(_saludoFijo), findsNothing);
    });

    testWidgets('le dice al servidor en qué escena está', (tester) async {
      final espia = await _abrir(tester, escena: Escena.bar);

      await _escribir(tester, 'un caffè');
      await _enviar(tester);

      // Es lo único que hace que el servidor le hable al modelo como
      // barista: el prompt lo elige él, no la app.
      expect(espia.pedidos.last['escena'], 'bar');
    });

    testWidgets('la charla libre sigue siendo la libre', (tester) async {
      final espia = await _abrir(tester);

      await _escribir(tester, 'ciao');
      await _enviar(tester);

      expect(espia.pedidos.last['escena'], 'libre');
    });

    testWidgets('cuando el barista cierra, la escena termina', (tester) async {
      await _abrir(
        tester,
        escena: Escena.bar,
        respuesta: 'Ecco il resto. Arrivederci!\nFINE',
      );

      await _escribir(tester, 'ecco cinque euro');
      await _enviar(tester);

      expect(find.text('Terminaste la escena'), findsOne);
      // No se escribe más: una escena cerrada no sigue.
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('la marca del final no se muestra', (tester) async {
      await _abrir(
        tester,
        escena: Escena.bar,
        respuesta: 'Ecco il resto. Arrivederci!\nFINE',
      );

      await _escribir(tester, 'ecco cinque euro');
      await _enviar(tester);

      // FINE es una señal para la app, no algo que el barista diga.
      expect(find.textContaining('FINE'), findsNothing);
      expect(find.textContaining('Arrivederci!'), findsOne);
    });

    testWidgets('la marca pegada al final de la frase también cierra',
        (tester) async {
      // El modelo devolvió "Arrivederci. FINE" en vez de ponerla en un
      // renglón aparte, que es como la pide el prompt. Pelearle por dónde
      // pone una palabra se pierde.
      await _abrir(
        tester,
        escena: Escena.bar,
        respuesta: 'Ecco il resto. Arrivederci. FINE',
      );

      await _escribir(tester, 'ecco cinque euro');
      await _enviar(tester);

      expect(find.text('Terminaste la escena'), findsOne);
      expect(find.textContaining('Arrivederci.'), findsOne);
    });

    testWidgets('empezar otra devuelve el campo y cambia el saludo',
        (tester) async {
      await _abrir(
        tester,
        escena: Escena.bar,
        respuesta: 'Arrivederci!\nFINE',
      );
      final primerSaludo =
          saludoAlAzar(escena: Escena.bar, azar: Random(_semilla));

      await _escribir(tester, 'ecco');
      await _enviar(tester);
      await tester.tap(find.text('Otra'));
      await tester.pumpAndSettle();

      expect(find.text('Terminaste la escena'), findsNothing);
      expect(find.byType(TextField), findsOne);
      // El saludo nunca es el mismo dos veces seguidas.
      expect(find.text(primerSaludo), findsNothing);
    });

    testWidgets('en la libre no termina nunca, aunque diga FINE',
        (tester) async {
      // "fine" es una palabra italiana común. En la charla libre no es una
      // señal de nada, y el campo tiene que seguir estando.
      await _abrir(tester, respuesta: 'Che bello! FINE');

      await _escribir(tester, 'ciao');
      await _enviar(tester);

      expect(find.text('Terminaste la escena'), findsNothing);
      expect(find.byType(TextField), findsOne);
    });
  });
}
