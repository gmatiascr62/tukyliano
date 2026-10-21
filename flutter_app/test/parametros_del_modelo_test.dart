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
}
