import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../modelos/diccionario.dart';

/// De dónde sale el diccionario.
///
/// Del archivo que viaja adentro de la app. Son 770 KB, que al lado de los 20
/// megas de audio del podcast no se notan, y a cambio el traductor anda sin
/// internet, sin clave y sin gastar cuota de nada.
class RepositorioDiccionario {
  RepositorioDiccionario({Future<String> Function(String)? leerAsset})
      : _leerAsset = leerAsset ?? rootBundle.loadString;

  final Future<String> Function(String) _leerAsset;

  static const String _elArchivo = 'assets/diccionario.json';

  Diccionario _diccionario = const Diccionario();
  bool _cargado = false;

  Diccionario get diccionario => _diccionario;

  Future<Diccionario> cargar() async {
    if (_cargado) return _diccionario;
    try {
      _diccionario = Diccionario.desdeJson(
        jsonDecode(await _leerAsset(_elArchivo)) as Map<String, dynamic>,
      );
    } catch (_) {
      // Sin diccionario el chat avisa que no encontró la palabra, que es lo
      // mismo que pasa con una palabra que no está. No se cae nada.
      _diccionario = const Diccionario();
    }
    _cargado = true;
    return _diccionario;
  }
}
