import 'dart:async';

import 'package:tukyliano/datos/descarga_modelo.dart';
import 'package:tukyliano/ia/modelo.dart';

/// Una descarga de mentira, para los tests de pantalla.
///
/// No existe para evitar la red —para eso alcanza con un cliente falso— sino
/// para evitar el disco: adentro de un test de widget, leer un archivo de
/// verdad no termina nunca, porque el reloj del test está congelado y el I/O
/// de verdad necesita que el reloj corra. La descarga de verdad se prueba en
/// descarga_modelo_test.dart, que no es un test de pantalla y ahí sí anda.
class DescargaFalsa implements DescargaModelo {
  DescargaFalsa({
    this.yaBajado = false,
    this.aMedias = 0,
    this.pasos,
    this.rutaFinal = '/una/ruta/$archivoDelModelo',
  });

  /// Si el modelo ya está en el celular.
  bool yaBajado;

  /// Cuántos bytes hay de una bajada que se cortó.
  final int aMedias;

  /// Qué va a ir contando la bajada. Si es null, baja bien.
  final List<Descarga>? pasos;

  final String rutaFinal;

  int bajadas = 0;
  int cortes = 0;
  int borrados = 0;

  @override
  String get url => urlDelModelo;

  @override
  String get huellaEsperada => sha256DelModelo;

  @override
  Future<String?> rutaSiEsta() async => yaBajado ? rutaFinal : null;

  @override
  Future<int> cuantoHayAMedias() async => aMedias;

  @override
  Stream<Descarga> bajar() async* {
    bajadas++;
    final losPasos = pasos ??
        const [
          Descarga(paso: PasoDescarga.bajando, bajados: 50, total: 100),
          Descarga(paso: PasoDescarga.verificando, bajados: 100, total: 100),
          Descarga(paso: PasoDescarga.listo, bajados: 100, total: 100),
        ];
    for (final paso in losPasos) {
      if (paso.paso == PasoDescarga.listo) yaBajado = true;
      yield paso;
    }
  }

  @override
  void cortar() => cortes++;

  @override
  Future<void> borrar() async {
    borrados++;
    yaBajado = false;
  }
}
