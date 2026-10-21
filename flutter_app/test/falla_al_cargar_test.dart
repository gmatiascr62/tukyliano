import 'package:flutter_test/flutter_test.dart';
import 'package:tukyliano/ia/falla_al_cargar.dart';

void main() {
  group('decir corto por qué falló', () {
    test('el error anidado del motor se dice en una línea', () {
      const crudo = 'LlamaException: Error loading model: LlamaException: '
          'Failed to initialize Llama (LlamaException: Could not load model at '
          '/data/user/0/org.gmatiascr62.tukyliano.flutter/app_flutter/modelo.gguf)';

      expect(motivoCorto(crudo), 'no pudo abrir el modelo');
    });

    test('si el modelo cargó y lo que falló fue el contexto, se nota', () {
      expect(
        motivoCorto('LlamaException: Could not create context!'),
        'no pudo armar el contexto',
      );
    });

    test('un error que no conozco se limpia pero se muestra', () {
      expect(
        motivoCorto('LlamaException: vaya a saber qué pasó acá'),
        'vaya a saber qué pasó acá',
      );
    });

    test('un error larguísimo se corta', () {
      expect(motivoCorto('x' * 300).length, 91);
    });
  });

  group('el mensaje de la pantalla', () {
    const unIntento = (
      nombre: 'libmtmd.so',
      motivo: 'LlamaException: Could not load model at /data/modelo.gguf',
    );

    test('lo que dijo el motor va primero, que es lo que se lee', () {
      final mensaje = mensajeDeFalla(
        intentos: [unIntento],
        dicho: 'llama_model_load: error loading model: lo que sea',
        archivo: 'un GGUF v3 de 378 MB con 310 tensores',
      );

      expect(
        mensaje.indexOf('Dice:'),
        lessThan(mensaje.indexOf('El archivo')),
      );
      expect(mensaje, contains('error loading model: lo que sea'));
    });

    test('cuatro intentos iguales se cuentan una sola vez', () {
      final mensaje = mensajeDeFalla(
        intentos: [
          unIntento,
          (nombre: 'libmtmd.so sin mapear', motivo: unIntento.motivo),
          (nombre: 'libllama.so', motivo: unIntento.motivo),
          (nombre: 'libllama.so sin mapear', motivo: unIntento.motivo),
        ],
        dicho: 'error loading model',
      );

      expect(mensaje, contains('Probé de 4 formas'));
      expect(mensaje, contains('en todas no pudo abrir el modelo'));
      expect('no pudo abrir el modelo'.allMatches(mensaje).length, 1);
    });

    test('si los intentos fallan distinto, se dice cada uno', () {
      final mensaje = mensajeDeFalla(
        intentos: [
          unIntento,
          (nombre: 'libllama.so', motivo: 'LlamaException: Could not create context!'),
        ],
      );

      expect(mensaje, contains('libmtmd.so, no pudo abrir el modelo'));
      expect(mensaje, contains('libllama.so, no pudo armar el contexto'));
    });

    test('cuando el motor no dijo nada, se dice que no dijo nada', () {
      // Es información: significa que no se pudo atrapar su salida.
      expect(
        mensajeDeFalla(intentos: [unIntento]),
        contains('El motor no dijo por qué.'),
      );
    });

    test('sin ficha del archivo no inventa una', () {
      expect(mensajeDeFalla(intentos: [unIntento]), isNot(contains('El archivo')));
    });
  });
}
