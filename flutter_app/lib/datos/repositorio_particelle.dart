import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../constantes.dart';
import '../modelos/particella.dart';

/// Frases con hueco para practicar las partículas.
///
/// Mismo camino que el resto de los datos: copia empaquetada con la app, copia
/// escribible en el celular, y chequeo contra GitHub por si hay frases nuevas.
///
/// A diferencia de los otros repositorios este no está atado a un archivo:
/// via, ci y ne son tres JSON con la misma forma, así que se le pasan por
/// parámetro y hay una sola clase en vez de tres iguales.
class RepositorioParticelle {
  RepositorioParticelle({
    required this.asset,
    required this.urlRemoto,
    required this.archivoLocal,
    Future<String> Function(String)? leerAsset,
    http.Client? cliente,
    Future<Directory?> Function()? carpeta,
  })  : _leerAsset = leerAsset ?? rootBundle.loadString,
        _cliente = cliente ?? http.Client(),
        _carpeta = carpeta ?? _carpetaDeLaApp;

  /// El de la sección Via.
  factory RepositorioParticelle.via({
    Future<String> Function(String)? leerAsset,
    http.Client? cliente,
    Future<Directory?> Function()? carpeta,
  }) =>
      RepositorioParticelle(
        asset: assetVia,
        urlRemoto: urlViaRemoto,
        archivoLocal: archivoViaLocal,
        leerAsset: leerAsset,
        cliente: cliente,
        carpeta: carpeta,
      );

  final String asset;
  final String urlRemoto;
  final String archivoLocal;

  final Future<String> Function(String) _leerAsset;
  final http.Client _cliente;

  /// Devuelve null cuando no hay dónde guardar (los tests): en ese caso se usa
  /// el asset y no se cachea nada.
  final Future<Directory?> Function() _carpeta;

  static Future<Directory?> _carpetaDeLaApp() =>
      getApplicationDocumentsDirectory();

  DatosParticelle _datos = DatosParticelle.vacio;

  /// La lectura en curso, o null si todavía no empezó.
  ///
  /// Se guarda el Future y no un simple "ya cargué" porque la app arranca la
  /// lectura al abrirse y la pantalla la vuelve a pedir al entrar: con un
  /// booleano, la segunda llamada volvía enseguida con los datos todavía
  /// vacíos y la sección decía "no hay frases" para siempre.
  Future<void>? _lectura;

  DatosParticelle get datos => _datos;
  int get version => _datos.version;

  Future<File?> _archivo() async {
    try {
      final dir = await _carpeta();
      return dir == null ? null : File('${dir.path}/$archivoLocal');
    } catch (_) {
      return null;
    }
  }

  /// Lee las frases guardadas una sola vez. Quien llegue mientras se está
  /// leyendo espera la misma lectura en vez de arrancar otra.
  Future<void> cargar() => _lectura ??= _leer();

  Future<void> _leer() async {
    try {
      final archivo = await _archivo();
      final texto = archivo != null && await archivo.exists()
          ? await archivo.readAsString()
          : await _leerAsset(asset);
      _datos =
          DatosParticelle.desdeJson(jsonDecode(texto) as Map<String, dynamic>);
    } catch (_) {
      // Con el asset roto no hay frases, pero la pantalla no crashea.
    }
  }

  /// Chequea el JSON remoto y, si trae una versión más nueva, la guarda y la
  /// usa. Devuelve true solo si hubo frases nuevas.
  Future<bool> verificarActualizacion() async {
    try {
      final respuesta = await _cliente
          .get(Uri.parse(urlRemoto))
          .timeout(const Duration(seconds: 8));
      if (respuesta.statusCode != 200) return false;

      // El body viene en UTF-8: sin esto los acentos se rompen.
      final texto = utf8.decode(respuesta.bodyBytes);
      final nuevas =
          DatosParticelle.desdeJson(jsonDecode(texto) as Map<String, dynamic>);
      if (nuevas.version <= _datos.version) return false;

      _datos = nuevas;
      final archivo = await _archivo();
      await archivo?.writeAsString(texto);
      return true;
    } catch (_) {
      // Sin internet o con el JSON remoto roto se sigue con lo que ya hay.
      return false;
    }
  }
}
