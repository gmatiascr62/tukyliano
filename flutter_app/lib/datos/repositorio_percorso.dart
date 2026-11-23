import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../modelos/percorso.dart';

/// De dónde sale el camino.
///
/// Por ahora solo del asset, sin copia en el celular ni chequeo contra
/// GitHub como hacen los cuentos y las frases. Es a propósito: el camino es
/// la estructura de la app, no contenido que se agrega. El día que haya que
/// agregar una ciudad sin publicar un APK, se le pone lo mismo que tienen
/// los otros repositorios.
class RepositorioPercorso {
  RepositorioPercorso({Future<String> Function(String)? leerAsset})
    : _leerAsset = leerAsset ?? rootBundle.loadString;

  final Future<String> Function(String) _leerAsset;

  Percorso _camino = Percorso.vacio;
  bool _cargado = false;

  Percorso get camino => _camino;

  Future<void> cargar() async {
    if (_cargado) return;
    try {
      final crudo = await _leerAsset('assets/percorso.json');
      final datos = jsonDecode(crudo);
      if (datos is Map<String, dynamic>) {
        _camino = Percorso.desdeJson(datos);
      }
    } catch (_) {
      // Sin camino la app sigue andando: las secciones de siempre están
      // donde estaban. Es una puerta más, no el piso.
    }
    _cargado = true;
  }
}
