import 'dart:io';
import 'dart:math';

import 'package:path_provider/path_provider.dart';

const String archivoQuien = 'quien_soy.txt';

/// Un número que la app se inventa la primera vez que se abre.
///
/// Es lo único que identifica a este celular ante el servidor, y existe por
/// una sola razón: repartir. Sin él, el tope de mensajes por día sería del
/// servidor entero y el primero que charlara toda la tarde dejaría a los
/// demás sin nada.
///
/// No es una cuenta ni un usuario: no hay mail, ni nombre, ni nada que se
/// pueda rastrear hasta una persona. Lo que el servidor guarda contra este
/// número es "mandó catorce mensajes el martes", y nada más. Si se desinstala
/// la app se pierde y la próxima vez se inventa otro.
class QuienSoy {
  QuienSoy({Future<Directory?> Function()? carpeta, Random? azar})
      : _carpeta = carpeta ?? _carpetaDeLaApp,
        _azar = azar ?? Random.secure();

  final Future<Directory?> Function() _carpeta;
  final Random _azar;

  static Future<Directory?> _carpetaDeLaApp() =>
      getApplicationDocumentsDirectory();

  String? _enMemoria;

  /// El número de este celular. Si no había, se inventa uno y se guarda.
  ///
  /// Cuando no hay dónde escribir —los tests, o un celular raro— igual
  /// devuelve uno: vale para esta sesión y el servidor lo trata como a
  /// cualquier otro.
  Future<String> cual() async {
    final enMemoria = _enMemoria;
    if (enMemoria != null) return enMemoria;

    try {
      final dir = await _carpeta();
      final archivo = dir == null ? null : File('${dir.path}/$archivoQuien');

      if (archivo != null && archivo.existsSync()) {
        final guardado = archivo.readAsStringSync().trim();
        if (guardado.isNotEmpty) return _enMemoria = guardado;
      }

      final nuevo = _inventar();
      archivo?.writeAsStringSync(nuevo);
      return _enMemoria = nuevo;
    } catch (_) {
      return _enMemoria = _inventar();
    }
  }

  /// Veinte caracteres al azar. No hace falta más: no es un secreto, es un
  /// número para contar.
  String _inventar() {
    const letras = 'abcdefghijklmnopqrstuvwxyz0123456789';
    return [
      for (var i = 0; i < 20; i++) letras[_azar.nextInt(letras.length)],
    ].join();
  }
}
