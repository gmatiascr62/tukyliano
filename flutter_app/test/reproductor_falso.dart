import 'dart:async';

import 'package:tukyliano/datos/reproductor.dart';

/// Reproductor de mentira: anota lo que se le pidió y deja al test mover el
/// reloj a mano.
///
/// Mover el reloj es la gracia. Con el audio de verdad habría que esperar seis
/// minutos para ver qué pasa en la frase cien; acá se salta ahí y se mira.
class ReproductorFalso implements Reproductor {
  ReproductorFalso({this.hayArchivo = true, this.duraDeMas = false});

  /// Con true imita el caso en que se abrió el audio de otra versión: dura
  /// mucho más de lo que dice la tabla de tiempos del episodio.
  final bool duraDeMas;

  /// False imita el episodio al que le falta el archivo de audio.
  final bool hayArchivo;

  String? cargado;
  bool andando = false;
  bool? lenta;
  int soltadas = 0;
  Duration donde = Duration.zero;

  final _porDonde = StreamController<Duration>.broadcast();
  final _termino = StreamController<void>.broadcast();

  @override
  String? porQueFallo;

  @override
  Duration? duracion;

  @override
  Future<bool> cargar(String archivo) async {
    if (!hayArchivo) {
      porQueFallo = 'de mentira: no está el archivo';
      return false;
    }
    cargado = archivo;
    duracion = Duration(seconds: duraDeMas ? 300 : 30);
    return true;
  }

  @override
  Future<void> reproducir() async => andando = true;

  @override
  Future<void> pausar() async => andando = false;

  @override
  Future<void> irA(Duration adonde) async {
    donde = adonde;
    _porDonde.add(adonde);
  }

  @override
  Future<void> usarVelocidadLenta(bool valor) async => lenta = valor;

  @override
  Stream<Duration> get porDonde => _porDonde.stream;

  @override
  Stream<void> get termino => _termino.stream;

  @override
  Future<void> soltar() async {
    soltadas++;
    await _porDonde.close();
    await _termino.close();
  }

  /// Mueve el reloj del reproductor, como si el audio hubiera avanzado.
  void correrA(Duration adonde) {
    donde = adonde;
    _porDonde.add(adonde);
  }

  /// Llegó al final del episodio.
  void terminar() => _termino.add(null);
}
