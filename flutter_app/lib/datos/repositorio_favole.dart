import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../modelos/favola.dart';

/// De dónde sale el catálogo de fábulas.
///
/// El catálogo viaja en la app porque es un archivo de texto chico: con él se
/// puede ver la lista entera, con títulos y duraciones, sin internet. Los
/// audios no: esos se bajan cuando se tocan.
class RepositorioFavole {
  RepositorioFavole({Future<String> Function(String)? leerAsset})
      : _leerAsset = leerAsset ?? rootBundle.loadString;

  final Future<String> Function(String) _leerAsset;

  static const String _elArchivo = 'assets/favole.json';

  Favole _catalogo = const Favole();
  bool _cargado = false;

  Future<Favole> cargar() async {
    if (_cargado) return _catalogo;
    try {
      final datos = jsonDecode(await _leerAsset(_elArchivo));
      _catalogo = Favole(
        favole: [
          for (final una in datos['favole'] as List)
            Favola.desdeJson(una as Map<String, dynamic>),
        ],
        base: datos['base'] as String? ?? '',
        credito: datos['credito'] as String? ?? '',
        fuente: datos['fuente'] as String? ?? '',
      );
    } catch (_) {
      _catalogo = const Favole();
    }
    _cargado = true;
    return _catalogo;
  }
}
