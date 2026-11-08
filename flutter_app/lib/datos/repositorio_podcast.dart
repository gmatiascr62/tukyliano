import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../modelos/episodio.dart';

/// De dónde salen los episodios.
///
/// Por ahora, solo del archivo que viaja adentro de la app. A diferencia de
/// las frases o los artículos, acá no se busca nada en GitHub todavía: esto
/// es una prueba para escuchar si la voz sintética aguanta dos minutos
/// seguidos. Si la sección sobrevive a esa prueba, se le agrega el mismo
/// camino de actualización que tienen las otras y se podrán publicar
/// episodios nuevos sin publicar un APK.
class RepositorioPodcast {
  RepositorioPodcast({Future<String> Function(String)? leerAsset})
      : _leerAsset = leerAsset ?? rootBundle.loadString;

  final Future<String> Function(String) _leerAsset;

  static const String _elArchivo = 'assets/podcast.json';

  Podcast _podcast = const Podcast(episodios: []);
  bool _cargado = false;

  Podcast get podcast => _podcast;

  Future<Podcast> cargar() async {
    if (_cargado) return _podcast;
    try {
      _podcast = Podcast.desdeJson(jsonDecode(await _leerAsset(_elArchivo)));
    } catch (_) {
      // Sin episodios la pantalla avisa que no hay nada; no se rompe la app.
      _podcast = const Podcast(episodios: []);
    }
    _cargado = true;
    return _podcast;
  }
}
