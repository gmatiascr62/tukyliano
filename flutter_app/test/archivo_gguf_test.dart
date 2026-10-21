import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tukyliano/ia/archivo_gguf.dart';

void main() {
  late Directory carpeta;

  setUp(() => carpeta = Directory.systemTemp.createTempSync('gguf'));
  tearDown(() => carpeta.deleteSync(recursive: true));

  /// Un archivo que arranca como arranca un GGUF de verdad.
  File unGguf({int version = 3, int tensores = 310, int relleno = 0}) {
    final cabecera = ByteData(24);
    for (final (i, letra) in 'GGUF'.codeUnits.indexed) {
      cabecera.setUint8(i, letra);
    }
    cabecera.setUint32(4, version, Endian.little);
    cabecera.setUint64(8, tensores, Endian.little);
    cabecera.setUint64(16, 26, Endian.little);

    final archivo = File('${carpeta.path}/modelo.gguf');
    archivo.writeAsBytesSync([
      ...cabecera.buffer.asUint8List(),
      ...List.filled(relleno, 0),
    ]);
    return archivo;
  }

  test('de un modelo de verdad saca la versión y los tensores', () async {
    final ficha = await mirarElArchivo(unGguf());

    expect(ficha, isNotNull);
    expect(ficha!.esGguf, isTrue);
    expect(ficha.version, 3);
    expect(ficha.tensores, 310);
  });

  test('el resumen es lo que se puede leer en una pantalla de error', () async {
    final ficha = await mirarElArchivo(unGguf(relleno: 2 * 1024 * 1024));

    expect(ficha!.resumen, '2 MB, GGUF v3, 310 tensores');
  });

  test('un archivo que no es GGUF se nota', () async {
    final archivo = File('${carpeta.path}/cualquiera.gguf')
      ..writeAsStringSync('esto es una página de error, no un modelo');

    final ficha = await mirarElArchivo(archivo);

    expect(ficha!.esGguf, isFalse);
    expect(ficha.resumen, contains('no parece un archivo GGUF'));
  });

  test('un archivo cortado a los pocos bytes tampoco pasa por bueno', () async {
    // Lo que queda si la bajada se corta apenas empezó.
    final archivo = File('${carpeta.path}/corto.gguf')
      ..writeAsBytesSync([0x47, 0x47, 0x55, 0x46]);

    final ficha = await mirarElArchivo(archivo);

    expect(ficha!.esGguf, isFalse);
    expect(ficha.bytes, 4);
  });

  test('si el archivo no existe, no se rompe nada', () async {
    expect(await mirarElArchivo(File('${carpeta.path}/no-esta.gguf')), isNull);
  });
}
