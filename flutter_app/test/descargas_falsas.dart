import 'dart:io';

import 'package:tukyliano/datos/descargas.dart';

/// Descargas de mentira: guarda en memoria y contesta en el acto.
///
/// Los tests de pantalla corren con un reloj falso, y ahí la lectura de
/// archivos de verdad no avanza nunca: la pantalla se quedaría cargando para
/// siempre. Esta no toca el disco, así que contesta en el mismo turno.
class DescargasFalsas implements Descargas {
  DescargasFalsas({this.sePuedeBajar = true, this.yaBajadas = const {}}) {
    _tengo.addAll(yaBajadas);
  }

  /// False imita que no hay señal o que el servidor contesta mal.
  final bool sePuedeBajar;

  /// Las que ya estaban en el celular antes de abrir la pantalla.
  final Set<String> yaBajadas;

  /// Las direcciones que se pidieron, en orden.
  final List<String> pedidas = [];

  final Set<String> _tengo = {};

  @override
  Future<File?> donde(String archivo) async => File('/de-mentira/$archivo');

  @override
  Future<bool> yaEsta(String archivo) async => _tengo.contains(archivo);

  @override
  Future<Set<String>> cualesEstan(Iterable<String> archivos) async =>
      archivos.where(_tengo.contains).toSet();

  @override
  Future<File?> bajar(String url, String archivo) async {
    if (_tengo.contains(archivo)) return File('/de-mentira/$archivo');
    pedidas.add(url);
    if (!sePuedeBajar) return null;
    _tengo.add(archivo);
    return File('/de-mentira/$archivo');
  }

  @override
  Future<void> borrar(String archivo) async => _tengo.remove(archivo);

  @override
  Future<int> cuantoOcupa() async => _tengo.length * 700 * 1024;
}
