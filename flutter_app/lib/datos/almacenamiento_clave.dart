import 'dart:io';

import 'package:path_provider/path_provider.dart';

const String archivoClave = 'gemini_key.txt';

/// Acceso al archivo donde la app guardaba la clave de Gemini.
///
/// La app ya no usa IA, así que esto queda solo para borrar la clave que
/// pueda haber quedado de una versión anterior: es una credencial y no tiene
/// por qué seguir en el celular.
/// La clave NUNCA va en el código ni en el repo: la pega el usuario y queda
/// solo en el celular.
class AlmacenamientoClave {
  File? _archivo;

  Future<File> _obtenerArchivo() async {
    if (_archivo != null) return _archivo!;
    final dir = await getApplicationDocumentsDirectory();
    return _archivo = File('${dir.path}/$archivoClave');
  }

  /// Devuelve la clave guardada, o null si todavía no se cargó ninguna.
  Future<String?> cargar() async {
    try {
      final archivo = await _obtenerArchivo();
      if (!await archivo.exists()) return null;
      final clave = (await archivo.readAsString()).trim();
      return clave.isEmpty ? null : clave;
    } catch (_) {
      return null;
    }
  }

  Future<void> guardar(String clave) async {
    final archivo = await _obtenerArchivo();
    await archivo.writeAsString(clave.trim());
  }

  /// Borra el archivo si existe.
  Future<void> borrar() async {
    try {
      final archivo = await _obtenerArchivo();
      if (await archivo.exists()) await archivo.delete();
    } catch (_) {
      // Si no se puede borrar, igual se vuelve a pedir la clave.
    }
  }
}
