import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../modelos/radio_italiana.dart';

/// De dónde salen las radios.
///
/// Del archivo que viaja en la app, por ahora. Las direcciones de los streams
/// se rompen solas —las emisoras las cambian sin avisar— así que esto es
/// candidato a mudarse al servidor, donde una emisora caída se arregla sin
/// publicar un APK.
class RepositorioRadios {
  RepositorioRadios({Future<String> Function(String)? leerAsset})
      : _leerAsset = leerAsset ?? rootBundle.loadString;

  final Future<String> Function(String) _leerAsset;

  static const String _elArchivo = 'assets/radios.json';

  List<RadioItaliana> _radios = const [];
  bool _cargado = false;

  List<RadioItaliana> get radios => _radios;

  Future<List<RadioItaliana>> cargar() async {
    if (_cargado) return _radios;
    try {
      final datos = jsonDecode(await _leerAsset(_elArchivo));
      _radios = [
        for (final radio in datos['radios'] as List)
          RadioItaliana.desdeJson(radio as Map<String, dynamic>),
      ];
    } catch (_) {
      _radios = const [];
    }
    _cargado = true;
    return _radios;
  }
}
