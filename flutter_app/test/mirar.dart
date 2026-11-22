// Banco de pruebas para VER una pantalla sin compilar el APK.
//
// Dibuja la pantalla al tamaño real del celular y la guarda como PNG, así se
// puede mirar un cambio de diseño en segundos en vez de esperar quince
// minutos a que la CI arme el APK.
//
// Se corre a mano:  flutter test test/mirar.dart
// Las imágenes quedan en  /tmp/pantallas/.
//
// No forma parte de la suite: no verifica nada, solo dibuja.
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tukyliano/datos/progreso.dart';
import 'package:tukyliano/datos/repositorio_diccionario.dart';
import 'package:tukyliano/datos/repositorio_frases.dart';
import 'package:tukyliano/datos/repositorio_lecturas.dart';
import 'package:tukyliano/ia/chat.dart';
import 'package:tukyliano/ia/servidor.dart';
import 'package:tukyliano/modelos/verbo.dart';
import 'package:tukyliano/pantallas/pantalla_chat.dart';
import 'package:tukyliano/pantallas/pantalla_frases.dart';
import 'package:tukyliano/pantallas/pantalla_lecturas.dart';
import 'package:tukyliano/pantallas/pantalla_inicio.dart';
import 'package:tukyliano/pantallas/pantalla_radio.dart';
import 'package:tukyliano/tema.dart';

import 'descargas_falsas.dart';
import 'reproductor_falso.dart';
import 'voz_falsa.dart';

/// Sin esto el texto sale como cajas negras y los íconos no aparecen: el
/// entorno de tests no trae fuentes. Las saca del propio SDK de Flutter.
Future<void> cargarFuentes() async {
  // La carpeta de fuentes cuelga del SDK, y el SDK se encuentra subiendo desde
  // el dart que está corriendo. Cuántos escalones hay que subir cambia según
  // cómo esté instalado Flutter, así que se sube hasta encontrarla en vez de
  // contar carpetas.
  Directory? donde;
  var actual = File(Platform.resolvedExecutable).parent;
  for (var i = 0; i < 8; i++) {
    final prueba = Directory('${actual.path}/artifacts/material_fonts');
    if (prueba.existsSync()) {
      donde = prueba;
      break;
    }
    if (actual.parent.path == actual.path) break;
    actual = actual.parent;
  }
  if (donde == null) {
    throw StateError('no encontré las fuentes del SDK de Flutter');
  }

  final fuentes = {
    'Roboto': [
      'Roboto-Regular.ttf',
      'Roboto-Medium.ttf',
      'Roboto-Bold.ttf',
      'Roboto-Black.ttf',
    ],
    'MaterialIcons': ['MaterialIcons-Regular.otf'],
  };

  for (final entrada in fuentes.entries) {
    final cargador = FontLoader(entrada.key);
    for (final nombre in entrada.value) {
      final archivo = File('${donde.path}/$nombre');
      if (!archivo.existsSync()) continue;
      cargador.addFont(
        Future.value(ByteData.view(archivo.readAsBytesSync().buffer)),
      );
    }
    await cargador.load();
  }
}

/// El Poco F7 de Matías: 395 x 855 puntos, con la barra de estado arriba y la
/// de gestos abajo.
const double _ancho = 395;
const double _alto = 855;
const double _escala = 3;

Future<void> dibujar(
  WidgetTester tester,
  String nombre,
  Widget pantalla, {
  /// Para mirar la misma pantalla en un celular más chico o más bajo. Sale
  /// de las variables ANCHO y ALTO.
  double? ancho,
  double? alto,
  /// Para sacar la foto con la pantalla ya usada —una charla empezada, por
  /// ejemplo— en vez de recién abierta.
  Future<void> Function(WidgetTester)? despuesDeAbrir,
}) async {
  final clave = GlobalKey();

  final w = ancho ?? double.parse(Platform.environment['ANCHO'] ?? '$_ancho');
  final h = alto ?? double.parse(Platform.environment['ALTO'] ?? '$_alto');

  tester.view
    ..physicalSize = Size(w * _escala, h * _escala)
    ..devicePixelRatio = _escala
    ..padding = const FakeViewPadding(top: 102, bottom: 60);

  // El tamaño de letra que eligió el dueño del celular. Vale 1 salvo que se
  // pida otra cosa, que es como se dibujó siempre; pero Android deja subirlo
  // hasta 1,3 o más, y ahí es donde se rompen los altos fijos. Sin poder
  // moverlo, un recorte que el alumno ve todos los días es invisible acá.
  final letra = double.parse(Platform.environment['LETRA'] ?? '1');

  await tester.pumpWidget(
    RepaintBoundary(
      key: clave,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: Tema.datos,
        home: Builder(
          builder: (contexto) => MediaQuery(
            data: MediaQuery.of(contexto)
                .copyWith(textScaler: TextScaler.linear(letra)),
            child: pantalla,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  if (despuesDeAbrir != null) {
    await despuesDeAbrir(tester);
    await tester.pumpAndSettle();
  }

  final limite =
      clave.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final imagen = await limite.toImage(pixelRatio: _escala);
  final bytes = await imagen.toByteData(format: ui.ImageByteFormat.png);
  // Sin esto el test termina de dibujar pero no termina nunca: la imagen queda
  // viva y el banco de pruebas se queda esperándola.
  imagen.dispose();

  final carpeta = Directory('/tmp/pantallas')..createSync(recursive: true);
  File('${carpeta.path}/$nombre.png')
      .writeAsBytesSync(bytes!.buffer.asUint8List());
  // ignore: avoid_print
  print('>>> /tmp/pantallas/$nombre.png');

  tester.view.reset();
}

/// Un progreso parecido al que tiene el celular de Matías: nivel 1 arrancado
/// y cuatro de los últimos siete días practicados.
///
/// Se arma escribiendo el archivo que la app escribiría, así pasa por el mismo
/// camino de carga que en el celular.
Future<Progreso> progresoDeMentira({
  int aciertos = 18,
  List<int> diasAtras = const [0, 1, 3, 5],
}) async {
  final hoy = DateTime.now();
  String comoTexto(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  final carpeta = Directory('/tmp/pantallas/progreso')
    ..createSync(recursive: true);
  File('${carpeta.path}/$archivoProgreso').writeAsStringSync(jsonEncode({
    'aciertos': aciertos,
    'dias': [
      for (final atras in diasAtras)
        comoTexto(hoy.subtract(Duration(days: atras))),
    ],
  }));

  final p = Progreso(carpeta: () async => carpeta);
  await p.cargar();
  return p;
}

/// El armazón que pone main.dart alrededor de cualquier pantalla.
Widget comoEnLaApp(Widget pantalla) => Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(children: [Expanded(child: pantalla)]),
        ),
      ),
    );

/// El catálogo de verdad, pero leído del disco y no del paquete de la app.
///
/// Bajo el reloj falso de los tests de widget, leer un asset con rootBundle
/// no termina nunca: la pantalla se queda cargando y la foto sale en blanco.
/// Se lee el mismo archivo con dart:io, que sí contesta.
RepositorioLecturas _elCatalogoDeVerdad({
  String archivo = 'assets/favole.json',
  String clave = 'favole',
}) =>
    RepositorioLecturas(
      leerAsset: (cual) async => File(cual).readAsStringSync(),
      archivo: archivo,
      clave: clave,
    );

/// Un diccionario chiquito. El de verdad son 770 KB y para una foto no hace
/// falta: leerlo entero acá hace que la pantalla no termine de cargar nunca.
RepositorioDiccionario _diccionarioChico() => RepositorioDiccionario(
      leerAsset: (_) async => '{"version":1,"it":{},"es":{}}',
    );

/// Descargas de mentira para la foto: con las tres primeras ya bajadas, que
/// es como se ve la pantalla después de usarla un rato.
DescargasFalsas _descargasDeMentira() => DescargasFalsas(yaBajadas: const {
      'favole_01_libro01_lafontaine_64kb.mp3',
      'favole_02_libro01_lafontaine_64kb.mp3',
      'favole_03_libro01_lafontaine_64kb.mp3',
      'favole_05_libro01_lafontaine_64kb.mp3',
    });

/// Lo justo para que la pantalla de frases tenga algo que preguntar.
final _unVerbo = DatosVerbos.desdeJson(jsonDecode('''
  {"verbos": {"dovere": {"traduccion": "deber", "tiempos": {
    "passato": {"loro": {"italiano": "hanno dovuto",
                         "espanol": "ellos tuvieron que"}}
  }}}}
''') as Map<String, dynamic>);

/// La frase de la foto, que es larga a propósito: es la que se cortaba.
RepositorioFrases _laFraseLarga() => RepositorioFrases(
      leerAsset: (_) async => '''
        {"frases": [
          {"verbo": "dovere", "tiempo": "passato", "persona": "loro",
           "espanol": "Los chicos tuvieron que estudiar",
           "italiano": "I bambini hanno dovuto studiare",
           "pista": "chicos = bambini"}
        ]}
      ''',
      cliente: MockClient((_) async => http.Response('', 404)),
      carpeta: () async => null,
    );

/// Un barista de mentira que contesta la escena entera, para la foto.
Servidor _baristaDeMentira() {
  const dice = [
    'Hai scritto: yo querer un café\n'
        'Volevi dire: Vorrei un caffè\n\nEcco a te.',
    'Un euro e cinquanta.',
    'Ecco il resto. Arrivederci!\nFINE',
  ];
  var cual = 0;
  return Servidor(
    url: 'https://de-mentira',
    cliente: MockClient((_) async => http.Response(
          jsonEncode({'texto': dice[cual++ % dice.length]}),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        )),
  );
}

void main() {
  setUpAll(cargarFuentes);

  // Una pantalla por corrida: en este contenedor sin pantalla de verdad, una
  // vez que se sacó la foto el motor no vuelve a dibujar. Cuál se dibuja lo
  // dice la variable MIRAR:
  //
  //   MIRAR=charla flutter test test/mirar.dart
  testWidgets('dibujar', (tester) async {
    final cual = Platform.environment['MIRAR'] ?? 'inicio';

    switch (cual) {
      case 'inicio':
        final progreso = await progresoDeMentira();
        await dibujar(
          tester,
          cual,
          comoEnLaApp(PantallaInicio(progreso: progreso, alElegir: (_) {})),
        );

      case 'radio':
        await dibujar(
          tester,
          cual,
          comoEnLaApp(PantallaRadio(reproductor: ReproductorFalso())),
        );

      case 'radio-sonando':
        await dibujar(
          tester,
          cual,
          comoEnLaApp(PantallaRadio(reproductor: ReproductorFalso())),
          despuesDeAbrir: (t) async {
            await t.tap(find.byIcon(Icons.play_arrow));
            await t.pumpAndSettle();
          },
        );

      case 'una-lectura':
        // La del lobo, que es la que tiene los tiempos marcados, con el
        // reloj puesto en medio de un verso: así se ve el renglón iluminado,
        // que es lo que hay que mirar.
        final reproductor = ReproductorFalso();
        await dibujar(
          tester,
          cual,
          comoEnLaApp(PantallaLecturas(
            repositorio: _elCatalogoDeVerdad(),
            descargas: _descargasDeMentira(),
            reproductor: reproductor,
            diccionario: _diccionarioChico(),
          )),
          despuesDeAbrir: (t) async {
            await t.tap(find.text('Il Lupo e il Cane'));
            await t.pumpAndSettle();
            reproductor.correrA(const Duration(seconds: 28));
            await t.pumpAndSettle();
          },
        );

      case 'lecturas':
        await dibujar(
          tester,
          cual,
          comoEnLaApp(PantallaLecturas(
            repositorio: _elCatalogoDeVerdad(),
            descargas: _descargasDeMentira(),
            reproductor: ReproductorFalso(),
            diccionario: _diccionarioChico(),
          )),
        );

      case 'pinocchio':
        await dibujar(
          tester,
          cual,
          comoEnLaApp(PantallaLecturas(
            repositorio: _elCatalogoDeVerdad(
              archivo: 'assets/pinocchio.json',
              clave: 'capitulos',
            ),
            descargas: _descargasDeMentira(),
            reproductor: ReproductorFalso(),
            diccionario: _diccionarioChico(),
          )),
        );

      case 'pinocchio-titulo':
        // El capítulo 1 con el reloj puesto mientras el lector lee el
        // título: así se ve que el título es la primera línea del texto y
        // se pinta como cualquier renglón, en vez de estar clavado arriba.
        final conTitulo = ReproductorFalso();
        await dibujar(
          tester,
          cual,
          comoEnLaApp(PantallaLecturas(
            repositorio: _elCatalogoDeVerdad(
              archivo: 'assets/pinocchio.json',
              clave: 'capitulos',
            ),
            descargas: _descargasDeMentira(),
            reproductor: conTitulo,
            diccionario: _diccionarioChico(),
          )),
          despuesDeAbrir: (t) async {
            await t.tap(find.textContaining('Come andò che maestro Ciliegia'));
            await t.pumpAndSettle();
            conTitulo.correrA(const Duration(seconds: 36));
            await t.pumpAndSettle();
          },
        );

      case 'frases':
        // Con la frase larga que Matías mandó en la foto: 'Los chicos
        // tuvieron que estudiar' no entra en un renglón, y con la letra
        // grande del celular el segundo se cortaba a la mitad.
        //
        // LETRA sube el tamaño de letra del sistema, que es lo que hay que
        // mirar: con LETRA=1 no se rompe nada y por eso nunca lo vi.
        //
        //   MIRAR=frases LETRA=1.3 flutter test test/mirar.dart
        await dibujar(
          tester,
          cual,
          comoEnLaApp(PantallaFrases(
            verbos: _unVerbo.verbos.values.toList(),
            tiempos: const ['passato'],
            frasesLocales: _laFraseLarga(),
            azar: Random(1),
          )),
        );

      case 'bar':
        // Con la escena ya empezada, una corrección adentro y el barista
        // cerrando: es lo que hay que mirar. Recién abierta solo se ve el
        // saludo.
        await dibujar(
          tester,
          cual,
          comoEnLaApp(PantallaChat(
            escena: Escena.bar,
            voz: VozFalsa(),
            servidor: _baristaDeMentira(),
          )),
          despuesDeAbrir: (t) async {
            for (final mio in const [
              'io volere un caffè',
              'quanto costa?',
              'ecco cinque euro',
            ]) {
              await t.enterText(find.byType(TextField), mio);
              await t.pumpAndSettle();
              await t.tap(find.byIcon(Icons.send_rounded));
              await t.pumpAndSettle();
            }
          },
        );

      default:
        throw ArgumentError('no sé dibujar "$cual"');
    }

    // El test dibuja bien pero no termina nunca de cerrarse. Como esto no
    // verifica nada, se sale y listo.
    exit(0);
  });
}
