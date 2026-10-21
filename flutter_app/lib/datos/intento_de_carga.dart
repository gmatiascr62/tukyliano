import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Nombre del archivito que queda mientras se carga el modelo.
const String archivoDelIntento = 'cargando_modelo.marca';

/// Se da cuenta de si la app se cerró sola cargando el modelo.
///
/// Un modelo de IA se carga con código nativo, y cuando algo sale mal ahí el
/// sistema mata el proceso entero: no hay error que atrapar ni mensaje que
/// mostrar, la app se cierra y listo. Peor todavía: al volver a abrirla y
/// entrar al chat, vuelve a cargar, vuelve a cerrarse, y el chat queda
/// inusable sin que nadie entienda por qué.
///
/// Esto lo convierte en algo que se puede contar. Antes de cargar se deja una
/// marca en el disco y al terminar bien se borra. Si al entrar la marca sigue
/// ahí, la vez pasada no se llegó a borrar: el intento anterior se llevó la
/// app puesta, y en vez de repetirlo se avisa.
class IntentoDeCarga {
  IntentoDeCarga({Future<Directory?> Function()? carpeta})
      : _carpeta = carpeta ?? _carpetaDeLaApp;

  /// Devuelve null cuando no hay dónde guardar (los tests).
  final Future<Directory?> Function() _carpeta;

  static Future<Directory?> _carpetaDeLaApp() =>
      getApplicationDocumentsDirectory();

  Future<File?> _marca() async {
    try {
      final dir = await _carpeta();
      return dir == null ? null : File('${dir.path}/$archivoDelIntento');
    } catch (_) {
      return null;
    }
  }

  /// True si la vez pasada la carga no terminó.
  Future<bool> seCerroLaVezPasada() async {
    try {
      final marca = await _marca();
      return marca != null && await marca.exists();
    } catch (_) {
      return false;
    }
  }

  /// Deja la marca. Va antes de cargar el modelo.
  Future<void> empiezo() async {
    try {
      // Con flush: si la app se muere un segundo después, la marca tiene que
      // estar escrita de verdad y no esperando en un buffer.
      await (await _marca())?.writeAsString(
        DateTime.now().toIso8601String(),
        flush: true,
      );
    } catch (_) {
      // Sin marca se pierde el aviso, pero no es razón para no dejar cargar.
    }
  }

  /// Saca la marca. Va cuando el modelo cargó bien.
  Future<void> salioBien() async {
    try {
      final marca = await _marca();
      if (marca != null && await marca.exists()) await marca.delete();
    } catch (_) {
      // Lo mismo: no poder borrarla no tiene que romper nada.
    }
  }
}
