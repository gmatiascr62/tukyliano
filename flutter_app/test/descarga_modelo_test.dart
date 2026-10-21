import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tukyliano/datos/descarga_modelo.dart';
import 'package:tukyliano/ia/modelo.dart';

/// El "modelo" de los tests: unos bytes cualesquiera, con su huella.
final List<int> _modeloFalso = utf8.encode('esto hace de modelo' * 50);
final String _huellaFalsa = sha256.convert(_modeloFalso).toString();

Directory _carpeta() {
  final dir = Directory.systemTemp.createTempSync('modelo_ia');
  addTearDown(() => dir.deleteSync(recursive: true));
  return dir;
}

/// Un servidor de mentira que manda [cuerpo] y entiende la cabecera Range.
MockClient _servidor(
  List<int> cuerpo, {
  List<String>? pedidos,
  bool entiendeRange = true,
  int estado = 200,
}) {
  return MockClient.streaming((pedido, _) async {
    pedidos?.add(pedido.headers['Range'] ?? 'entero');
    if (estado != 200) {
      return http.StreamedResponse(const Stream.empty(), estado);
    }

    final desde = entiendeRange
        ? int.tryParse(
              RegExp(r'bytes=(\d+)-')
                      .firstMatch(pedido.headers['Range'] ?? '')
                      ?.group(1) ??
                  '',
            ) ??
            0
        : 0;

    final trozo = cuerpo.sublist(desde);
    return http.StreamedResponse(
      Stream.fromIterable([trozo]),
      desde > 0 ? 206 : 200,
      contentLength: trozo.length,
    );
  });
}

DescargaModelo _descarga(
  Directory dir, {
  required http.Client cliente,
  String? huella,
}) =>
    DescargaModelo(
      cliente: cliente,
      carpeta: () async => dir,
      huellaEsperada: huella ?? _huellaFalsa,
    );

void main() {
  group('bajar el modelo', () {
    test('lo baja, lo verifica y lo deja guardado', () async {
      final dir = _carpeta();
      final descarga = _descarga(dir, cliente: _servidor(_modeloFalso));

      final pasos = await descarga.bajar().toList();

      expect(pasos.last.paso, PasoDescarga.listo);
      expect(pasos.map((p) => p.paso), contains(PasoDescarga.verificando));
      expect(File('${dir.path}/$archivoDelModelo').existsSync(), isTrue);
      expect(await descarga.rutaSiEsta(), endsWith(archivoDelModelo));
    });

    test('mientras baja va contando cuánto lleva', () async {
      final dir = _carpeta();
      final descarga = _descarga(dir, cliente: _servidor(_modeloFalso));

      final pasos = await descarga.bajar().toList();
      final bajando = pasos.where((p) => p.paso == PasoDescarga.bajando);

      expect(bajando, isNotEmpty);
      expect(bajando.last.total, _modeloFalso.length);
      expect(pasos.last.cuanto, 1);
    });

    test('si ya está, no toca la red', () async {
      final dir = _carpeta();
      File('${dir.path}/$archivoDelModelo').writeAsBytesSync(_modeloFalso);
      final pedidos = <String>[];
      final descarga = _descarga(
        dir,
        cliente: _servidor(_modeloFalso, pedidos: pedidos),
      );

      final pasos = await descarga.bajar().toList();

      expect(pasos.last.paso, PasoDescarga.listo);
      expect(pedidos, isEmpty);
    });

    test('lo que se bajó a medias se retoma desde ahí', () async {
      // Son cientos de megas: empezar de cero cada vez que se corta el wifi
      // sería insoportable.
      final dir = _carpeta();
      final mitad = _modeloFalso.sublist(0, 400);
      File('${dir.path}/$archivoDelModeloAMedias').writeAsBytesSync(mitad);

      final pedidos = <String>[];
      final descarga = _descarga(
        dir,
        cliente: _servidor(_modeloFalso, pedidos: pedidos),
      );

      final pasos = await descarga.bajar().toList();

      expect(pedidos.single, 'bytes=400-');
      expect(pasos.last.paso, PasoDescarga.listo);
      expect(
        File('${dir.path}/$archivoDelModelo').readAsBytesSync(),
        _modeloFalso,
      );
    });

    test('si el servidor no entiende Range, empieza de nuevo', () async {
      final dir = _carpeta();
      File('${dir.path}/$archivoDelModeloAMedias')
          .writeAsBytesSync(_modeloFalso.sublist(0, 400));

      final descarga = _descarga(
        dir,
        cliente: _servidor(_modeloFalso, entiendeRange: false),
      );

      final pasos = await descarga.bajar().toList();

      // Y el archivo tiene que quedar entero, no con los 400 bytes repetidos.
      expect(pasos.last.paso, PasoDescarga.listo);
      expect(
        File('${dir.path}/$archivoDelModelo').readAsBytesSync(),
        _modeloFalso,
      );
    });

    test('dice cuánto hay bajado de antes', () async {
      final dir = _carpeta();
      File('${dir.path}/$archivoDelModeloAMedias')
          .writeAsBytesSync(_modeloFalso.sublist(0, 400));
      final descarga = _descarga(dir, cliente: _servidor(_modeloFalso));

      expect(await descarga.cuantoHayAMedias(), 400);
    });
  });

  group('verificar lo que llegó', () {
    test('si la huella no coincide, lo tira y avisa', () async {
      // Puede ser una bajada cortada mal, o puede no ser el archivo que
      // esperábamos. En los dos casos no se puede usar.
      final dir = _carpeta();
      final descarga = _descarga(
        dir,
        cliente: _servidor(_modeloFalso),
        huella: 'otra huella cualquiera',
      );

      final pasos = await descarga.bajar().toList();

      expect(pasos.last.paso, PasoDescarga.fallo);
      expect(pasos.last.problema, contains('no es el que esperábamos'));
      expect(File('${dir.path}/$archivoDelModelo').existsSync(), isFalse);
      expect(File('${dir.path}/$archivoDelModeloAMedias').existsSync(), isFalse);
      expect(await descarga.rutaSiEsta(), isNull);
    });

    test('el archivo bueno recién existe cuando está verificado', () async {
      final dir = _carpeta();
      final descarga = _descarga(dir, cliente: _servidor(_modeloFalso));

      await for (final paso in descarga.bajar()) {
        if (paso.paso != PasoDescarga.listo) {
          expect(
            File('${dir.path}/$archivoDelModelo').existsSync(),
            isFalse,
            reason: '${paso.paso}',
          );
        }
      }
    });
  });

  group('cuando sale mal', () {
    test('un error del servidor se cuenta en castellano', () async {
      final dir = _carpeta();
      final descarga = _descarga(
        dir,
        cliente: _servidor(_modeloFalso, estado: 404),
      );

      final pasos = await descarga.bajar().toList();

      expect(pasos.last.paso, PasoDescarga.fallo);
      expect(pasos.last.problema, contains('404'));
    });

    test('sin internet lo dice y deja seguir después', () async {
      final dir = _carpeta();
      final descarga = _descarga(
        dir,
        cliente: MockClient.streaming(
          (_, _) async => throw const SocketException('sin red'),
        ),
      );

      final pasos = await descarga.bajar().toList();

      expect(pasos.last.paso, PasoDescarga.fallo);
      expect(pasos.last.problema, contains('internet'));
    });

    test('sin carpeta donde guardar, lo avisa', () async {
      final descarga = DescargaModelo(
        cliente: _servidor(_modeloFalso),
        carpeta: () async => null,
      );

      final pasos = await descarga.bajar().toList();

      expect(pasos.last.paso, PasoDescarga.fallo);
      expect(await descarga.rutaSiEsta(), isNull);
    });
  });

  group('borrar', () {
    test('se lleva el modelo y lo que haya a medias', () async {
      final dir = _carpeta();
      File('${dir.path}/$archivoDelModelo').writeAsBytesSync(_modeloFalso);
      File('${dir.path}/$archivoDelModeloAMedias').writeAsBytesSync([1, 2, 3]);
      final descarga = _descarga(dir, cliente: _servidor(_modeloFalso));

      await descarga.borrar();

      expect(File('${dir.path}/$archivoDelModelo').existsSync(), isFalse);
      expect(File('${dir.path}/$archivoDelModeloAMedias').existsSync(), isFalse);
    });

    test('borrar lo que no está no rompe nada', () async {
      final dir = _carpeta();
      final descarga = _descarga(dir, cliente: _servidor(_modeloFalso));

      await expectLater(descarga.borrar(), completes);
    });
  });
}
