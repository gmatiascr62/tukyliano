import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../modelos/lectura.dart';

/// De dónde sale el catálogo de fábulas.
///
/// El catálogo viaja en la app porque es un archivo de texto chico: con él se
/// puede ver la lista entera, con títulos y duraciones, sin internet. Los
/// audios no: esos se bajan cuando se tocan.
class RepositorioLecturas {
  RepositorioLecturas({
    Future<String> Function(String)? leerAsset,
    this.archivo = 'assets/favole.json',
    this.clave = 'favole',
  }) : _leerAsset = leerAsset ?? rootBundle.loadString;

  final Future<String> Function(String) _leerAsset;

  /// Cuál catálogo se lee y bajo qué clave está la lista adentro.
  ///
  /// Son parámetros y no constantes porque la misma pantalla sirve para
  /// las fábulas de La Fontaine y para los capítulos de Pinocchio: tienen
  /// la misma forma —título, audio, duración, peso y renglones— y lo
  /// único que cambia es de qué archivo salen.
  final String archivo;
  final String clave;

  Lecturas _catalogo = const Lecturas();
  bool _cargado = false;

  Future<Lecturas> cargar() async {
    if (_cargado) return _catalogo;
    try {
      final datos = jsonDecode(await _leerAsset(archivo));
      _catalogo = Lecturas(
        lecturas: [
          for (final una in datos[clave] as List)
            Lectura.desdeJson(una as Map<String, dynamic>),
        ],
        base: datos['base'] as String? ?? '',
        credito: datos['credito'] as String? ?? '',
        fuente: datos['fuente'] as String? ?? '',
        textoDe: datos['textoDe'] as String? ?? '',
      );
    } catch (_) {
      _catalogo = const Lecturas();
    }
    _cargado = true;
    return _catalogo;
  }
}
