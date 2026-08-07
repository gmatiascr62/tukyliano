import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../constantes.dart';
import '../modelos/racconto.dart';

/// Cuentos para leer.
///
/// Mismo camino que el resto de los datos: copia empaquetada con la app,
/// copia escribible en el celular, y chequeo contra GitHub por si hay
/// cuentos nuevos. Así se agregan sin publicar un APK.
class RepositorioRacconti {
  RepositorioRacconti({
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

  DatosRacconti _datos = DatosRacconti.vacio;
  bool _cargado = false;

  DatosRacconti get datos => _datos;
  int get version => _datos.version;

  Future<File?> _archivo() async {
    try {
      final dir = await _carpeta();
      return dir == null
          ? null
          : File('${dir.path}/$archivoRaccontiLocal');
    } catch (_) {
      return null;
    }
  }

  /// Lee los cuentos guardados una sola vez.
  Future<void> cargar() async {
    if (_cargado) return;
    _cargado = true;
    try {
      final archivo = await _archivo();
      final texto = archivo != null && await archivo.exists()
          ? await archivo.readAsString()
          : await _leerAsset(assetRacconti);
      _datos = DatosRacconti.desdeJson(
          jsonDecode(texto) as Map<String, dynamic>);
    } catch (_) {
      // Con el asset roto no hay cuentos, pero la pantalla no crashea.
    }
  }

  /// Chequea el JSON remoto y, si trae una versión más nueva, la guarda y la
  /// usa. Devuelve true solo si hubo cuentos nuevos.
  Future<bool> verificarActualizacion() async {
    try {
      final respuesta = await _cliente
          .get(Uri.parse(urlRaccontiRemoto))
          .timeout(const Duration(seconds: 8));
      if (respuesta.statusCode != 200) return false;

      // El body viene en UTF-8: sin esto los acentos se rompen.
      final texto = utf8.decode(respuesta.bodyBytes);
      final nuevos = DatosRacconti.desdeJson(
          jsonDecode(texto) as Map<String, dynamic>);
      if (nuevos.version <= _datos.version) return false;

      _datos = nuevos;
      final archivo = await _archivo();
      await archivo?.writeAsString(texto);
      return true;
    } catch (_) {
      // Sin internet o con el JSON remoto roto se sigue con lo que ya hay.
      return false;
    }
  }
}
