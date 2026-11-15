import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tukyliano/datos/repositorio_radios.dart';
import 'package:tukyliano/pantallas/pantalla_radio.dart';

import 'reproductor_falso.dart';

/// El archivo de verdad que viaja en el APK.
final _json = File('assets/radios.json').readAsStringSync();

RepositorioRadios _repositorio({String? asset}) =>
    RepositorioRadios(leerAsset: (_) async => asset ?? _json);

Future<void> _abrir(
  WidgetTester tester, {
  required ReproductorFalso reproductor,
  String? asset,
}) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: PantallaRadio(
        repositorio: _repositorio(asset: asset),
        reproductor: reproductor,
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
