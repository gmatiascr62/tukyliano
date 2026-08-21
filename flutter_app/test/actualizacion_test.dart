import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tukyliano/datos/actualizacion.dart';

/// Lo que contesta GitHub cuando le preguntan por la última publicación.
String _publicacion({
  String etiqueta = 'v1.0.63',
  String archivo = 'Tukyliano.apk',
  int bytes = 41 * 1024 * 1024,
}) =>
    jsonEncode({
      'tag_name': etiqueta,
      'assets': [
        {
          'name': archivo,
          'size': bytes,
          'browser_download_url': 'https://github.com/x/y/releases/$archivo',
        },
      ],
    });

Actualizacion _buscador(String cuerpo, {int estado = 200, int instalado = 60}) =>
    Actualizacion(
      instalado: instalado,
      cliente: MockClient((_) async => http.Response(cuerpo, estado, headers: {
            'content-type': 'application/json; charset=utf-8',
          })),
      carpeta: () async => null,
    );

Directory _carpeta() {
  final dir = Directory.systemTemp.createTempSync('tukyliano_apk');
  addTearDown(() => dir.deleteSync(recursive: true));
  return dir;
}

void main() {
  group('el número de versión', () {
    test('sale de la etiqueta que publica el workflow', () {
      expect(buildDeEtiqueta('v1.0.63'), 63);
      expect(buildDeEtiqueta('v1.0.7'), 7);
    });

    test('una etiqueta rara no se inventa un número', () {
      // Mejor no avisar nada que ofrecer una actualización que no se entiende.
      expect(buildDeEtiqueta('vieja'), 0);
      expect(buildDeEtiqueta(''), 0);
    });
  });

  group('buscar', () {
    test('avisa cuando la publicada es más nueva', () async {
      final nueva = await _buscador(_publicacion()).buscar();

      expect(nueva, isNotNull);
      expect(nueva!.build, 63);
      expect(nueva.nombre, '1.0.63');
      expect(nueva.url, endsWith('Tukyliano.apk'));
      expect(nueva.tamano, '41 MB');
    });

    test('no avisa si es la misma que está instalada', () async {
      final nueva = await _buscador(_publicacion(), instalado: 63).buscar();

      expect(nueva, isNull);
    });

    test('no avisa si la publicada es más vieja', () async {
      // Pasa si alguien borra una publicación: no hay que ofrecer volver atrás.
      final nueva = await _buscador(_publicacion(), instalado: 99).buscar();

      expect(nueva, isNull);
    });

    test('compilando a mano no busca nada', () async {
      // Sin número de build no hay contra qué comparar.
      final nueva = await _buscador(_publicacion(), instalado: 0).buscar();

      expect(nueva, isNull);
    });

    test('sin internet no pasa nada', () async {
      final buscador = Actualizacion(
        instalado: 60,
        cliente: MockClient((_) async => throw const SocketException('')),
        carpeta: () async => null,
      );

      expect(await buscador.buscar(), isNull);
    });

    test('una respuesta rara no rompe nada', () async {
      for (final cuerpo in ['esto no es JSON', '[]', '{}']) {
        expect(await _buscador(cuerpo).buscar(), isNull, reason: cuerpo);
      }
      expect(await _buscador(_publicacion(), estado: 404).buscar(), isNull);
    });

    test('una publicación sin APK adjunto no sirve', () async {
      final cuerpo = _publicacion(archivo: 'notas.txt');

      expect(await _buscador(cuerpo).buscar(), isNull);
    });
  });

  group('bajar', () {
    VersionNueva laVersion({int bytes = 8}) => VersionNueva(
          nombre: '1.0.63',
          build: 63,
          url: 'https://github.com/x/y/Tukyliano.apk',
          bytes: bytes,
        );

    test('guarda el APK y va contando cuánto lleva', () async {
      final dir = _carpeta();
      final avances = <double>[];
      final actualizacion = Actualizacion(
        instalado: 60,
        carpeta: () async => dir,
        cliente: MockClient.streaming((_, _) async => http.StreamedResponse(
              Stream.fromIterable([
                [1, 2, 3, 4],
                [5, 6, 7, 8],
              ]),
              200,
              contentLength: 8,
            )),
      );

      final archivo =
          await actualizacion.bajar(laVersion(), alAvanzar: avances.add);

      expect(archivo, isNotNull);
      expect(archivo!.path, endsWith(archivoActualizacion));
      expect(archivo.readAsBytesSync(), [1, 2, 3, 4, 5, 6, 7, 8]);
      expect(avances, [0.5, 1.0]);
    });

    test('un archivo cortado a la mitad no queda dando vueltas', () async {
      // Android diría que el APK está dañado y no se entendería por qué.
      final dir = _carpeta();
      final actualizacion = Actualizacion(
        instalado: 60,
        carpeta: () async => dir,
        cliente: MockClient.streaming((_, _) async => http.StreamedResponse(
              Stream.fromIterable([
                [1, 2, 3],
              ]),
              200,
              contentLength: 99,
            )),
      );

      expect(await actualizacion.bajar(laVersion(bytes: 99)), isNull);
      expect(File('${dir.path}/$archivoActualizacion').existsSync(), isFalse);
    });

    test('si el servidor contesta mal no devuelve archivo', () async {
      final actualizacion = Actualizacion(
        instalado: 60,
        carpeta: () async => _carpeta(),
        cliente: MockClient.streaming((_, _) async =>
            http.StreamedResponse(const Stream.empty(), 404)),
      );

      expect(await actualizacion.bajar(laVersion()), isNull);
    });

    test('sin dónde guardar no rompe', () async {
      final actualizacion = Actualizacion(
        instalado: 60,
        carpeta: () async => null,
        cliente: MockClient.streaming((_, _) async =>
            http.StreamedResponse(const Stream.empty(), 200)),
      );

      expect(await actualizacion.bajar(laVersion()), isNull);
    });
  });
}
