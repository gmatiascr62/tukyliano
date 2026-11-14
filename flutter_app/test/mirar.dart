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
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tukyliano/datos/progreso.dart';
import 'package:tukyliano/pantallas/pantalla_charla.dart';
import 'package:tukyliano/pantallas/pantalla_inicio.dart';
import 'package:tukyliano/tema.dart';

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
  /// Para sacar la foto con la pantalla ya usada —una charla empezada, por
  /// ejemplo— en vez de recién abierta.
  Future<void> Function(WidgetTester)? despuesDeAbrir,
}) async {
  final clave = GlobalKey();

  tester.view
    ..physicalSize = const Size(_ancho * _escala, _alto * _escala)
    ..devicePixelRatio = _escala
    ..padding = const FakeViewPadding(top: 102, bottom: 60);

  await tester.pumpWidget(
    RepaintBoundary(
      key: clave,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: Tema.datos,
        home: pantalla,
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

      case 'charla':
        // Con la charla ya empezada y un error adentro, que es lo que hay que
        // mirar: una pantalla recién abierta no muestra la corrección.
        await dibujar(
          tester,
          cual,
          comoEnLaApp(PantallaCharla(voz: VozFalsa())),
          despuesDeAbrir: (t) async {
            Future<void> contestar(String texto) async {
              await t.enterText(find.byType(TextField), texto);
              await t.pumpAndSettle();
              await t.tap(find.byIcon(Icons.send_rounded));
              await t.pumpAndSettle();
            }

            await contestar('Un caffè, per favore');
            await contestar('io volere normale');
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
