import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tukyliano/ia/espia_de_stderr.dart';

void main() {
  group('atrapar la salida de error', () {
    late Directory carpeta;

    setUp(() => carpeta = Directory.systemTemp.createTempSync('espia'));
    tearDown(() => carpeta.deleteSync(recursive: true));

    test('lo que se escribe en la salida de error queda guardado', () async {
      final espia = EspiaDeStderr(File('${carpeta.path}/dicho.txt'));

      expect(espia.empezar(), isTrue);
      stderr.writeln('llama_model_load: error loading model: lo que sea');
      await stderr.flush();
      final dicho = await espia.terminar();

      expect(dicho, contains('error loading model'));
    });

    test('después de terminar, la salida de error vuelve a su lugar', () async {
      final espia = EspiaDeStderr(File('${carpeta.path}/dicho.txt'));
      espia.empezar();
      stderr.writeln('esto va al archivo');
      await stderr.flush();
      await espia.terminar();

      // Lo de después ya no tiene que caer en el archivo.
      stderr.writeln('esto va a la salida de error de siempre');
      await stderr.flush();

      expect(
        File('${carpeta.path}/dicho.txt').readAsStringSync(),
        isNot(contains('de siempre')),
      );
    });

    test('terminar sin haber empezado no rompe nada', () async {
      final espia = EspiaDeStderr(File('${carpeta.path}/no-esta.txt'));

      expect(await espia.terminar(), '');
    });

    test('empezar dos veces no pisa la copia de la salida original', () {
      final espia = EspiaDeStderr(File('${carpeta.path}/dicho.txt'));

      expect(espia.empezar(), isTrue);
      expect(espia.empezar(), isFalse);

      espia.terminar();
    });
  });

  group('quedarse con lo que importa', () {
    test('de un montón de renglones elige los que hablan de un error', () {
      const crudo = '''
llama_model_loader: loaded meta data with 26 key-value pairs
llama_model_loader: - tensor 0: token_embd.weight q4_K
print_info: file size = 378 MiB
llama_model_load: error loading model: unable to allocate buffer
llama_model_load_from_file_impl: failed to load model
''';

      expect(
        loQueImporta(crudo),
        'llama_model_load: error loading model: unable to allocate buffer · '
        'llama_model_load_from_file_impl: failed to load model',
      );
    });

    test('si no hay ningún renglón feo, muestra los últimos', () {
      const crudo = 'uno\ndos\ntres\ncuatro\n';

      expect(loQueImporta(crudo, cuantos: 2), 'tres · cuatro');
    });

    test('corta lo largo, porque entra en una pantalla de celular', () {
      final crudo = 'error ${'x' * 500}';

      expect(loQueImporta(crudo).length, 300);
    });

    test('de nada no inventa nada', () {
      expect(loQueImporta(''), '');
      expect(loQueImporta('\n  \n'), '');
    });
  });
}
