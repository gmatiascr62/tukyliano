import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tukyliano/datos/android.dart';
import 'package:tukyliano/datos/audio_de_fondo.dart';
import 'package:tukyliano/datos/donde_suena_la_radio.dart';
import 'package:tukyliano/datos/repositorio_radios.dart';
import 'package:tukyliano/pantallas/pantalla_radio.dart';

import 'reproductor_falso.dart';

/// El archivo de verdad que viaja en el APK.
final _json = File('assets/radios.json').readAsStringSync();

RepositorioRadios _repositorio({String? asset}) =>
    RepositorioRadios(leerAsset: (_) async => asset ?? _json);

/// Baja hasta el pie de la pantalla.
///
/// La pantalla entró en una lista que dibuja solo lo que se ve, así que el
/// crédito y el estado del audio no existen hasta que se llega abajo.
Future<void> _bajarDelTodo(WidgetTester tester) async {
  await tester.drag(find.byType(ListView), const Offset(0, -900));
  await tester.pumpAndSettle();
}

/// Un balanceador que no contesta, que es lo normal en un test.
///
/// Va explícito y no se deja el de verdad porque el de verdad saldría a
/// internet: un test no puede depender de que haya red, ni esperar a que una
/// consulta se dé por vencida. Sin balanceador la radio suena por la
/// dirección del catálogo, que es lo que esperan los tests de abajo.
DondeSuenaLaRadio _sinBalanceador() => DondeSuenaLaRadio(
      cliente: MockClient((_) async => throw const SocketException('')),
    );

Future<void> _abrir(
  WidgetTester tester, {
  required ReproductorFalso reproductor,
  String? asset,
  DondeSuenaLaRadio? dondeSuena,
}) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: PantallaRadio(
        repositorio: _repositorio(asset: asset),
        reproductor: reproductor,
        dondeSuena: dondeSuena ?? _sinBalanceador(),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  group('el archivo de emisoras', () {
    final datos = jsonDecode(_json) as Map<String, dynamic>;
    final radios = (datos['radios'] as List).cast<Map<String, dynamic>>();

    test('tiene al menos una emisora', () {
      expect(radios, isNotEmpty);
    });

    test('todas tienen nombre, stream y de quién son', () {
      for (final radio in radios) {
        expect(radio['id'], isA<String>(), reason: 'id de $radio');
        expect(radio['nombre'], isNotEmpty);
        expect(radio['stream'], isNotEmpty);
        // Quién la hace va a la vista en la pantalla. Sin esto la app
        // reproduciría el trabajo de otro sin decir de quién es.
        expect(radio['quien'], isNotEmpty, reason: '${radio['nombre']}');
      }
    });

    test('los streams van por https', () {
      // Android bloquea el tráfico sin cifrar desde hace años: un stream
      // http:// no suena en el celular, y el error que da no lo explica.
      for (final radio in radios) {
        expect(
          radio['stream'],
          startsWith('https://'),
          reason: '${radio['nombre']} tiene que ir por https',
        );
      }
    });

    test('no hay dos emisoras con el mismo id', () {
      final ids = radios.map((r) => r['id']).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('todas dicen para qué no sirven', () {
      // El "ojo" es la mitad del valor de la pantalla: una radio que promete
      // más de lo que da se abre una vez y no se vuelve a abrir.
      for (final radio in radios) {
        expect(radio['ojo'], isNotEmpty, reason: '${radio['nombre']}');
      }
    });
  });

  group('el repositorio', () {
    test('lee las emisoras del archivo', () async {
      final radios = await _repositorio().cargar();
      expect(radios, isNotEmpty);
      expect(radios.first.stream, startsWith('https://'));
    });

    test('con un archivo roto no se cae: devuelve ninguna', () async {
      final radios = await _repositorio(asset: 'esto no es json').cargar();
      expect(radios, isEmpty);
    });

    test('lee el archivo una sola vez', () async {
      var leidas = 0;
      final repositorio = RepositorioRadios(leerAsset: (_) async {
        leidas++;
        return _json;
      });
      await repositorio.cargar();
      await repositorio.cargar();
      expect(leidas, 1);
    });
  });

  group('la pantalla', () {
    testWidgets('muestra la emisora sin conectarse a nada', (tester) async {
      final reproductor = ReproductorFalso();
      await _abrir(tester, reproductor: reproductor);

      expect(find.text('Radio Senti Chi Parla'), findsOne);
      expect(find.text('En vivo desde Italia'), findsOne);
      // Entrar a mirar no tiene por qué gastar datos.
      expect(reproductor.laUrl, isNull);
      expect(reproductor.andando, isFalse);
    });

    testWidgets('dice de quién es la emisora', (tester) async {
      await _abrir(tester, reproductor: ReproductorFalso());
      await _bajarDelTodo(tester);

      expect(
        find.textContaining('Senti Chi Parla! OdV'),
        findsOne,
      );
    });

    testWidgets('avisa que no es una radio para aprender', (tester) async {
      await _abrir(tester, reproductor: ReproductorFalso());

      expect(find.textContaining('No es una radio para aprender'), findsOne);
    });

    testWidgets('el play abre el stream y arranca', (tester) async {
      final reproductor = ReproductorFalso();
      await _abrir(tester, reproductor: reproductor);

      await tester.tap(find.byIcon(Icons.play_arrow));
      await tester.pumpAndSettle();

      expect(
        reproductor.laUrl,
        'https://24293.live.streamtheworld.com/SAM01AAC222_SC',
      );
      expect(reproductor.andando, isTrue);
      expect(find.text('Sonando en vivo'), findsOne);
      expect(find.byIcon(Icons.stop), findsOne);
    });

    testWidgets('no le pregunta al balanceador si la de siempre anda',
        (tester) async {
      // El balanceador reparte entre decenas de nodos y el que toca puede
      // estar lejos o cargado. La dirección del catálogo es la que se
      // escuchó y se sabe que llega bien, así que no se cambia por una
      // sorteada mientras funcione. Estuvo al revés un rato y se oía
      // entrecortado.
      var preguntaron = false;
      final reproductor = ReproductorFalso();
      await _abrir(
        tester,
        reproductor: reproductor,
        dondeSuena: DondeSuenaLaRadio(cliente: MockClient((_) async {
          preguntaron = true;
          return http.Response('', 302);
        })),
      );

      await tester.tap(find.byIcon(Icons.play_arrow));
      await tester.pumpAndSettle();

      expect(
        reproductor.laUrl,
        'https://24293.live.streamtheworld.com/SAM01AAC222_SC',
      );
      expect(preguntaron, isFalse);
      expect(find.text('Sonando en vivo'), findsOne);
    });

    testWidgets('si la de siempre no abre, prueba con el balanceador',
        (tester) async {
      // El día que ese nodo deje de servir, el balanceador es lo único que
      // sabe cuál lo reemplazó.
      final reproductor = _ReproductorQueFallaCon(
        'https://24293.live.streamtheworld.com/SAM01AAC222_SC',
      );
      await _abrir(
        tester,
        reproductor: reproductor,
        dondeSuena: DondeSuenaLaRadio(
          cliente: MockClient.streaming((_, _) async => http.StreamedResponse(
                const Stream<List<int>>.empty(),
                302,
                headers: {
                  'location':
                      'http://15113.live.streamtheworld.com/SAM01AAC222_SC',
                },
              )),
        ),
      );

      await tester.tap(find.byIcon(Icons.play_arrow));
      await tester.pumpAndSettle();

      // Y por https, aunque el balanceador conteste http: Android bloquea
      // el tráfico sin cifrar.
      expect(
        reproductor.laUrl,
        'https://15113.live.streamtheworld.com/SAM01AAC222_SC',
      );
      expect(find.text('Sonando en vivo'), findsOne);
    });

    testWidgets('el segundo toque la para', (tester) async {
      final reproductor = ReproductorFalso();
      await _abrir(tester, reproductor: reproductor);

      await tester.tap(find.byIcon(Icons.play_arrow));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.stop));
      await tester.pumpAndSettle();

      expect(reproductor.andando, isFalse);
      expect(find.text('Pausada'), findsOne);
    });

    testWidgets('seguir no vuelve a conectarse de cero', (tester) async {
      var cuantasVeces = 0;
      final reproductor = _ReproductorQueCuenta(() => cuantasVeces++);
      await _abrir(tester, reproductor: reproductor);

      await tester.tap(find.byIcon(Icons.play_arrow));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.stop));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.play_arrow));
      await tester.pumpAndSettle();

      expect(cuantasVeces, 1);
      expect(reproductor.andando, isTrue);
    });

    testWidgets('si no se puede conectar lo dice, con el motivo',
        (tester) async {
      final reproductor = ReproductorFalso(hayArchivo: false);
      await _abrir(tester, reproductor: reproductor);

      await tester.tap(find.byIcon(Icons.play_arrow));
      await tester.pumpAndSettle();

      expect(find.text('No se pudo conectar'), findsOne);
      expect(find.textContaining('Fijate que tengas internet'), findsOne);
      // El motivo técnico va igual: una radio falla por tres cosas distintas
      // y sin él no se puede saber cuál.
      expect(find.textContaining('de mentira: la radio no abre'), findsOne);
      expect(reproductor.andando, isFalse);
    });

    testWidgets('si se corta la transmisión lo dice', (tester) async {
      final reproductor = ReproductorFalso();
      await _abrir(tester, reproductor: reproductor);

      await tester.tap(find.byIcon(Icons.play_arrow));
      await tester.pumpAndSettle();

      // Una radio en vivo no "termina": si el reproductor dice que terminó,
      // es que se cortó.
      reproductor.terminar();
      await tester.pumpAndSettle();

      expect(find.text('Se cortó'), findsOne);
      expect(find.textContaining('Tocá de nuevo para reconectar'), findsOne);
      expect(find.byIcon(Icons.play_arrow), findsOne);
    });

    testWidgets('después de cortarse, el play reconecta', (tester) async {
      var cuantasVeces = 0;
      final reproductor = _ReproductorQueCuenta(() => cuantasVeces++);
      await _abrir(tester, reproductor: reproductor);

      await tester.tap(find.byIcon(Icons.play_arrow));
      await tester.pumpAndSettle();
      reproductor.terminar();
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.play_arrow));
      await tester.pumpAndSettle();

      expect(cuantasVeces, 2);
      expect(find.text('Sonando en vivo'), findsOne);
    });

    testWidgets('sin emisoras no se cae', (tester) async {
      await _abrir(
        tester,
        reproductor: ReproductorFalso(),
        asset: '{"version": 1, "radios": []}',
      );

      expect(find.textContaining('Todavía no hay emisoras'), findsOne);
    });

    testWidgets('con más de una emisora muestra la lista', (tester) async {
      await _abrir(
        tester,
        reproductor: ReproductorFalso(),
        asset: jsonEncode({
          'version': 1,
          'radios': [
            {
              'id': 'una',
              'nombre': 'Radio Una',
              'que': 'La primera',
              'ojo': 'Cuidado',
              'stream': 'https://ejemplo.test/una',
              'quien': 'Alguien',
            },
            {
              'id': 'otra',
              'nombre': 'Radio Otra',
              'que': 'La segunda',
              'ojo': 'Cuidado',
              'stream': 'https://ejemplo.test/otra',
              'quien': 'Otro',
            },
          ],
        }),
      );

      expect(find.text('Radio Una'), findsOne);
      expect(find.text('Radio Otra'), findsOne);
      // Nada de botón grande todavía: primero hay que elegir cuál.
      expect(find.byIcon(Icons.play_arrow), findsNothing);

      await tester.tap(find.text('Radio Otra'));
      await tester.pumpAndSettle();

      expect(find.text('En vivo desde Italia'), findsOne);
      expect(find.byIcon(Icons.play_arrow), findsOne);
      await _bajarDelTodo(tester);
      expect(find.text('Ver las otras emisoras'), findsOne);
    });

    testWidgets('al salir pausa, pero no suelta el reproductor',
        (tester) async {
      final reproductor = ReproductorFalso();
      await _abrir(tester, reproductor: reproductor);
      await tester.tap(find.byIcon(Icons.play_arrow));
      await tester.pumpAndSettle();

      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await tester.pumpAndSettle();

      // Pausa: una radio que sigue sonando con la pantalla cerrada gasta
      // datos sin que nadie la escuche.
      expect(reproductor.andando, isFalse);
      // Pero no lo suelta: el reproductor es uno solo para toda la app y lo
      // suelta main.dart. Soltarlo acá dejaría al podcast sin reproductor.
      expect(reproductor.soltadas, 0);
    });

    testWidgets('le manda a la notificación qué está sonando', (tester) async {
      final reproductor = ReproductorFalso();
      await _abrir(tester, reproductor: reproductor);

      await tester.tap(find.byIcon(Icons.play_arrow));
      await tester.pumpAndSettle();

      // Es lo que se lee con el celular bloqueado, y además lo que hace que
      // Android deje seguir sonando: sin notificación, corta el audio.
      expect(reproductor.elTitulo, 'Radio Senti Chi Parla');
      expect(reproductor.deQuienEs, 'Senti Chi Parla! OdV');
    });
  });

  group('el aviso de que se va a cortar', () {
    tearDown(() => AudioDeFondo.comoSi(anda: true));

    testWidgets('aparece cuando el audio de fondo no se pudo prender',
        (tester) async {
      AudioDeFondo.comoSi(anda: false, porQue: 'falló, de mentira');

      await _abrir(tester, reproductor: ReproductorFalso());
      await _bajarDelTodo(tester);

      expect(find.text('Se va a cortar al bloquear la pantalla'), findsOne);
      // El motivo técnico va a la vista: sin él, desde afuera esto es "se
      // corta a los treinta segundos" y no se sabe si es el celular o la app.
      expect(find.text('falló, de mentira'), findsOne);
    });

    testWidgets('no aparece cuando el audio de fondo anda', (tester) async {
      AudioDeFondo.comoSi(anda: true);

      await _abrir(tester, reproductor: ReproductorFalso());
      await _bajarDelTodo(tester);

      expect(find.text('Se va a cortar al bloquear la pantalla'), findsNothing);
    });

    testWidgets('avisa cuando falta el permiso de notificar', (tester) async {
      // Sin ese permiso no hay notificación, y sin notificación Android
      // corta el audio. Hay que decirlo porque el sistema deja de preguntar
      // después de dos negativas.
      Android.comoSi(puedeNotificar: false);
      addTearDown(() => Android.comoSi(puedeNotificar: true));

      await _abrir(tester, reproductor: ReproductorFalso());
      await _bajarDelTodo(tester);

      expect(find.text('Falta darle permiso para notificar'), findsOne);
      expect(find.textContaining('Ajustes'), findsOne);
    });

    testWidgets('no molesta con eso si el permiso está dado', (tester) async {
      Android.comoSi(puedeNotificar: true);

      await _abrir(tester, reproductor: ReproductorFalso());
      await _bajarDelTodo(tester);

      expect(find.text('Falta darle permiso para notificar'), findsNothing);
    });

    testWidgets('el detalle técnico aparece solo cuando algo anda mal',
        (tester) async {
      // Con esa línea se encontró por qué el audio se cortaba, pero no tiene
      // por qué estar a la vista del alumno cuando todo funciona.
      // 'servicio:' solo lo dice el renglón técnico, no el cartel de aviso.
      AudioDeFondo.comoSi(anda: true);
      await _abrir(tester, reproductor: ReproductorFalso());
      await _bajarDelTodo(tester);
      expect(find.textContaining('servicio:'), findsNothing);

      AudioDeFondo.comoSi(anda: false, porQue: 'falló, de mentira');
      await _abrir(tester, reproductor: ReproductorFalso());
      await _bajarDelTodo(tester);
      expect(find.textContaining('servicio:'), findsOne);
    });
  });
}

/// Un reproductor al que una dirección puntual no le abre.
///
/// Sirve para probar qué hace la pantalla cuando el nodo del catálogo deja
/// de servir, que es el día para el que está el balanceador.
class _ReproductorQueFallaCon extends ReproductorFalso {
  _ReproductorQueFallaCon(this.laQueNoAbre);

  final String laQueNoAbre;

  @override
  Future<bool> cargarDesdeInternet(
    String url, {
    String? titulo,
    String? deQuien,
  }) async {
    if (url == laQueNoAbre) return false;
    return super.cargarDesdeInternet(url, titulo: titulo, deQuien: deQuien);
  }
}

/// Igual que el falso, pero cuenta cuántas veces se le pidió abrir el stream.
class _ReproductorQueCuenta extends ReproductorFalso {
  _ReproductorQueCuenta(this.anotar);

  final VoidCallback anotar;

  @override
  Future<bool> cargarDesdeInternet(
    String url, {
    String? titulo,
    String? deQuien,
  }) {
    anotar();
    return super.cargarDesdeInternet(url, titulo: titulo, deQuien: deQuien);
  }
}
