import 'dart:io';

import 'package:path_provider/path_provider.dart';

const String archivoClave = 'gemini_key.txt';

/// La clave de la API de Gemini, guardada en el celular.
///
/// La clave NUNCA va en el código, ni en el repo, ni dentro del APK: el repo es
/// público y Google revoca las claves que encuentra publicadas. La pega el
/// usuario una sola vez y queda en la carpeta privada de la app, que ninguna
/// otra app puede leer.
class AlmacenamientoClave {
  AlmacenamientoClave({Future<Directory?> Function()? carpeta})
      : _carpeta = carpeta ?? _carpetaDeLaApp;

  /// Devuelve null cuando no hay dónde guardar (los tests): ahí la clave vale
  /// solo para la sesión abierta.
  final Future<Directory?> Function() _carpeta;

  static Future<Directory?> _carpetaDeLaApp() =>
      getApplicationDocumentsDirectory();

  File? _archivo;

  Future<File?> _obtenerArchivo() async {
    if (_archivo != null) return _archivo;
    try {
      final dir = await _carpeta();
      return dir == null ? null : _archivo = File('${dir.path}/$archivoClave');
    } catch (_) {
      return null;
    }
  }

  /// Devuelve la clave guardada, o null si todavía no se cargó ninguna.
  ///
  /// El archivo se lee y se escribe con las versiones "Sync": es una línea de
  /// texto, tarda menos que un cuadro de animación, y así lo único asincrónico
  /// que queda es averiguar la carpeta.
  Future<String?> cargar() async {
    try {
      final archivo = await _obtenerArchivo();
      if (archivo == null || !archivo.existsSync()) return null;
      final clave = archivo.readAsStringSync().trim();
      return clave.isEmpty ? null : clave;
    } catch (_) {
      return null;
    }
  }

  Future<void> guardar(String clave) async {
    try {
      final archivo = await _obtenerArchivo();
      archivo?.writeAsStringSync(clave.trim());
    } catch (_) {
      // Si no se puede escribir, la clave igual sirve para esta sesión: se va
      // a volver a pedir la próxima vez.
    }
  }

  /// Borra el archivo si existe. Se usa cuando la clave dejó de funcionar: no
  /// tiene sentido guardar una credencial que ya no vale.
  Future<void> borrar() async {
    try {
      final archivo = await _obtenerArchivo();
      if (archivo != null && archivo.existsSync()) archivo.deleteSync();
    } catch (_) {
      // Si no se puede borrar, igual se vuelve a pedir la clave.
    }
  }
}
