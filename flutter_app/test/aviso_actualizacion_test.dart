import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tukyliano/datos/actualizacion.dart';
import 'package:tukyliano/tema.dart';
import 'package:tukyliano/widgets/aviso_actualizacion.dart';

const _apk = 'https://github.com/x/y/releases/Tukyliano.apk';
const _rutaBajada = '/tmp/tukyliano/Tukyliano.apk';

VersionNueva _version() => const VersionNueva(
      nombre: '1.0.63',
      build: 63,
      url: _apk,
      bytes: 41 * 1024 * 1024,
    );

/// Actualización de mentira: la de verdad escribe un archivo, y en un test de
/// pantalla eso no llega a terminar nunca (el reloj es falso). Lo que se
/// prueba acá es la pantalla; bajar y comparar versiones se prueba aparte, en
/// actualizacion_test.dart.
class _ActualizacionFalsa extends Actualizacion {
  _ActualizacionFalsa({this.hayNueva = true, this.seBaja = true, this.espera})
      : super(
          instalado: 60,
          carpeta: () async => null,
          cliente: MockClient((_) async => http.Response('', 404)),
        );

  final bool hayNueva;
  final bool seBaja;

  /// Si viene, la bajada se queda a mitad de camino hasta que el test la
  /// suelte. Sirve para mirar la pantalla mientras baja.
  final Completer<void>? espera;

  @override
  Future<VersionNueva?> buscar() async => hayNueva ? _version() : null;

  @override
  Future<File?> bajar(
    VersionNueva version, {
    void Function(double)? alAvanzar,
  }) async {
    alAvanzar?.call(0.4);
    if (espera != null) await espera!.future;
    if (!seBaja) return null;
    alAvanzar?.call(1);
    return File(_rutaBajada);
  }
}

Future<List<String>> _mostrar(
  WidgetTester tester,
  Actualizacion actualizacion,
) async {
  final abiertos = <String>[];
  await tester.pumpWidget(MaterialApp(
    theme: Tema.datos,
    home: Scaffold(
      body: AvisoActualizacion(
        actualizacion: actualizacion,
        abrir: (ruta) async => abiertos.add(ruta),
      ),
    ),
  ));
  await tester.pumpAndSettle();
  return abiertos;
}

void main() {
  testWidgets('sin novedades no ocupa nada', (tester) async {
    await _mostrar(tester, _ActualizacionFalsa(hayNueva: false));

    expect(find.textContaining('versión nueva'), findsNothing);
    expect(tester.getSize(find.byType(AvisoActualizacion)), Size.zero);
  });

  testWidgets('avisa con el tamaño, porque son 40 MB', (tester) async {
    await _mostrar(tester, _ActualizacionFalsa());

    expect(find.text('Hay una versión nueva (41 MB)'), findsOneWidget);
    expect(find.text('Mejor con wifi'), findsOneWidget);
    expect(find.text('Actualizar'), findsOneWidget);
  });

  testWidgets('se puede cerrar y no vuelve a molestar', (tester) async {
    await _mostrar(tester, _ActualizacionFalsa());

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(find.textContaining('versión nueva'), findsNothing);
  });

  testWidgets('mientras baja muestra cuánto lleva', (tester) async {
    final espera = Completer<void>();
    final abiertos =
        await _mostrar(tester, _ActualizacionFalsa(espera: espera));

    await tester.tap(find.text('Actualizar'));
    await tester.pump();

    // Un APK tarda un minuto: sin esto la pantalla parecería colgada.
    expect(find.textContaining('Bajando la versión 1.0.63'), findsOneWidget);
    expect(find.textContaining('40%'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(abiertos, isEmpty);

    espera.complete();
    await tester.pumpAndSettle();

    expect(abiertos, [_rutaBajada]);
  });

  testWidgets('cuando termina le pasa el archivo al instalador',
      (tester) async {
    final abiertos = await _mostrar(tester, _ActualizacionFalsa());

    await tester.tap(find.text('Actualizar'));
    await tester.pumpAndSettle();

    // Lo único que la app no puede hacer sola: instalarse.
    expect(abiertos, [_rutaBajada]);
  });

  testWidgets('si falla la bajada lo dice y deja reintentar', (tester) async {
    final abiertos = await _mostrar(tester, _ActualizacionFalsa(seBaja: false));

    await tester.tap(find.text('Actualizar'));
    await tester.pumpAndSettle();

    expect(find.text('No se pudo bajar. Probá de nuevo.'), findsOneWidget);
    expect(find.text('Actualizar'), findsOneWidget);
    expect(abiertos, isEmpty);
  });
}
