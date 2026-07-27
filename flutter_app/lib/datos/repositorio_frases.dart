import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../constantes.dart';
import '../ia/prompts.dart';

/// Frases de práctica, indexadas por verbo + tiempo + persona.
///
/// Sigue el mismo camino que los verbos: viene una copia empaquetada con la
/// app, se guarda una copia escribible en el celular, y se chequea contra
/// GitHub por si hay frases nuevas. Así se pueden agregar frases sin publicar
/// un APK.
///
/// Sirven para dos cosas: la frase aparece al instante (no hay que esperar a
/// Gemini) y no gasta cuota. Cuando una forma no tiene frase guardada, la
/// pantalla sigue pidiéndosela a la IA.
class RepositorioFrases {
  RepositorioFrases({
    Future<String> Function(String)? leerAsset,
    http.Client? cliente,
    Future<Directory?> Function()? carpeta,
  })  : _leerAsset = leerAsset ?? rootBundle.loadString,
        _cliente = cliente ?? http.Client(),
        _carpeta = carpeta ?? _carpetaDeLaApp;

  final Future<String> Function(String) _leerAsset;
  final http.Client _cliente;

  /// Devuelve null cuando no hay dónde guardar (los tests): en ese caso se
  /// usa el asset y no se cachea nada.
  final Future<Directory?> Function() _carpeta;

  static Future<Directory?> _carpetaDeLaApp() =>
      getApplicationDocumentsDirectory();

  final Map<String, List<FraseGenerada>> _porForma = {};
  bool _cargado = false;
  int _version = 0;

  int get version => _version;

  static String claveDe(String verbo, String tiempo, String persona) =>
      '$verbo|$tiempo|$persona';

  Future<File?> _archivo() async {
    try {
      final dir = await _carpeta();
      return dir == null ? null : File('${dir.path}/$archivoFrasesLocal');
    } catch (_) {
      return null;
    }
  }

  /// Lee las frases guardadas una sola vez. Si algo falla, la app queda como
  /// antes de que existieran: todo lo genera la IA.
  Future<void> cargar() async {
    if (_cargado) return;
    _cargado = true;
    try {
      final archivo = await _archivo();
      final texto = archivo != null && await archivo.exists()
          ? await archivo.readAsString()
          : await _leerAsset(assetFrases);
      _indexar(texto);
    } catch (_) {
      // Un asset roto no puede dejar la pantalla sin frases.
    }
  }

  /// Chequea el JSON remoto y, si trae una versión más nueva, la guarda y la
  /// usa. Devuelve true solo si hubo frases nuevas.
  Future<bool> verificarActualizacion() async {
    try {
      final respuesta = await _cliente
          .get(Uri.parse(urlFrasesRemoto))
          .timeout(const Duration(seconds: 8));
      if (respuesta.statusCode != 200) return false;

      // El body viene en UTF-8: sin esto los acentos se rompen.
      final texto = utf8.decode(respuesta.bodyBytes);
      final version = _versionDe(texto);
      if (version <= _version) return false;

      _indexar(texto);
      final archivo = await _archivo();
      await archivo?.writeAsString(texto);
      return true;
    } catch (_) {
      // Sin internet o con el JSON remoto roto se sigue con lo que ya hay.
      return false;
    }
  }

  int _versionDe(String texto) {
    final json = jsonDecode(texto);
    return json is Map<String, dynamic> ? json['version'] as int? ?? 0 : 0;
  }

  void _indexar(String texto) {
    final json = jsonDecode(texto);
    final lista = json is Map<String, dynamic> ? json['frases'] : json;
    if (lista is! List) return;

    _porForma.clear();
    _version = json is Map<String, dynamic> ? json['version'] as int? ?? 0 : 0;

    for (final item in lista) {
      if (item is! Map<String, dynamic>) continue;
      final espanol = item['espanol'] as String? ?? '';
      final italiano = item['italiano'] as String? ?? '';
      if (espanol.isEmpty || italiano.isEmpty) continue;
      final clave = claveDe(
        item['verbo'] as String? ?? '',
        item['tiempo'] as String? ?? '',
        item['persona'] as String? ?? '',
      );
      _porForma.putIfAbsent(clave, () => []).add(FraseGenerada(
            espanol: espanol,
            italiano: italiano,
            pista: item['pista'] as String? ?? '',
          ));
    }
  }

  /// Una frase al azar entre las guardadas para esa forma, o null si no hay.
  ///
  /// Si se pasa [conjugacionItaliana], solo se consideran las frases que la
  /// contengan. Es la red de contención para el JSON remoto, que no pasa por
  /// la validación del build: una frase mal etiquetada o con el verbo mal
  /// escrito se ignora y esa forma cae en la IA.
  FraseGenerada? elegir({
    required String verbo,
    required String tiempo,
    required String persona,
    String conjugacionItaliana = '',
    Random? azar,
  }) {
    var opciones = _porForma[claveDe(verbo, tiempo, persona)];
    if (opciones == null || opciones.isEmpty) return null;

    if (conjugacionItaliana.isNotEmpty) {
      final esperada = conjugacionItaliana.toLowerCase();
      opciones =
          opciones.where((f) => f.italiano.toLowerCase().contains(esperada)).toList();
      if (opciones.isEmpty) return null;
    }

    return opciones[(azar ?? Random()).nextInt(opciones.length)];
  }

  /// Cuántas frases hay cargadas. Se usa en los tests.
  int get cantidad => _porForma.values.fold(0, (n, l) => n + l.length);
}
