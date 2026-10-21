import 'package:flutter_test/flutter_test.dart';
import 'package:llama_cpp_dart/llama_cpp_dart.dart';
import 'package:tukyliano/ia/motor_llama.dart';

void main() {
  test('no se le pide ninguna placa de video', () {
    // Este número tuvo el chat roto varios días. Con 0, llama.cpp entiende
    // "usá la placa número 0"; en un celular la lista de placas está vacía, la
    // número 0 no existe, y el modelo no carga:
    // "invalid value for main_gpu: 0 (available devices: 0)".
    expect(parametrosDelModelo(mapear: true).mainGpu, -1);
  });

  test('todo el trabajo va al procesador', () {
    expect(parametrosDelModelo(mapear: true).nGpuLayers, 0);
    expect(parametrosDelModelo(mapear: true).splitMode, LlamaSplitMode.none);
  });

  test('el mapeo del archivo es lo que cambia entre un intento y el otro', () {
    expect(parametrosDelModelo(mapear: true).useMemorymap, isTrue);
    expect(parametrosDelModelo(mapear: false).useMemorymap, isFalse);
  });

  test('no se le pide al sistema que clave el modelo en memoria', () {
    // Son cientos de megas: clavarlos haría que Android mate la app.
    expect(parametrosDelModelo(mapear: true).useMemoryLock, isFalse);
  });

  group('el contexto', () {
    ContextParams armar() => parametrosDelContexto(
          cuantoContexto: 1024,
          cuantoContesta: 160,
          hilos: 3,
        );

    test('la memoria de la charla y el largo de la respuesta son los pedidos',
        () {
      expect(armar().nCtx, 1024);
      expect(armar().nPredict, 160);
    });

    test('en una tanda entra la charla más larga que pueda haber', () {
      // El paquete no parte el pedido: lo copia entero en una sola tanda. Si
      // la tanda es más chica que la charla, corta con "Prompt tokens (181) >
      // batch capacity (128)". Como la charla nunca pasa del contexto, con una
      // tanda del tamaño del contexto siempre entra.
      expect(armar().nBatch, greaterThanOrEqualTo(armar().nCtx));
    });

    test('las cuentas se hacen de a pedazos chicos, por la memoria', () {
      // Esto es otra cosa que la tanda: el espacio de trabajo crece con este
      // número y se arma uno por mensaje.
      expect(armar().nUbatch, lessThanOrEqualTo(128));
      expect(armar().nUbatch, lessThanOrEqualTo(armar().nBatch));
    });

    test('usa los hilos que se le digan, para pensar y para leer', () {
      expect(armar().nThreads, 3);
      expect(armar().nThreadsBatch, 3);
    });
  });
}
