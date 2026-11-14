import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../modelos/charla.dart';

/// De dónde salen las charlas guionadas.
///
/// Del archivo que viaja adentro de la app, como el podcast: son unos pocos
/// kilobytes y tienen que andar sin internet, que es medio sentido de que
/// existan.
class RepositorioCharlas {
  RepositorioCharlas({Future<String> Function(String)? leerAsset})
      : _leerAsset = leerAsset ?? rootBundle.loadString;

  final Future<String> Function(String) _leerAsset;

  static const String _elArchivo = 'assets/charlas.json';

  List<Charla> _charlas = const [];
  bool _cargado = false;

  List<Charla> get charlas => _charlas;

  Future<List<Charla>> cargar() async {
    if (_cargado) return _charlas;
    try {
      final datos = jsonDecode(await _leerAsset(_elArchivo));
      _charlas = [
        for (final charla in datos['charlas'] as List)
          Charla.desdeJson(charla as Map<String, dynamic>),
      ];
    } catch (_) {
      // Sin charlas la pantalla lo avisa; no se cae la app.
      _charlas = const [];
    }
    _cargado = true;
    return _charlas;
  }
}
