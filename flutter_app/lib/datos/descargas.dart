import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Baja audios y los guarda en el celular.
///
/// Esto es lo que permite tener horas de audio sin que la app pese horas de
/// audio. Hasta ahora todo el sonido viajaba adentro del APK: con tres
/// episodios del podcast ya eran 95 MB, y un solo audiolibro son 130 más.
/// Así no se escala.
///
/// Lo que se baja queda en la carpeta privada de la app. Eso significa dos
/// cosas: que nadie más lo ve, y que si se desinstala la app se va con ella.
/// Es lo correcto para material que no es del usuario: no le ensucia la
/// galería ni le deja archivos sueltos.
abstract class Descargas {
  /// Dónde queda guardado algo, esté bajado o no.
  Future<File?> donde(String archivo);

  /// Si ya está en el celular.
  Future<bool> yaEsta(String archivo);

  /// Cuáles de estos ya están. Se pregunta de una porque la pantalla los
  /// necesita todos juntos para dibujarse.
  Future<Set<String>> cualesEstan(Iterable<String> archivos);

  /// Baja uno. Devuelve dónde quedó, o null si no se pudo.
  Future<File?> bajar(String url, String archivo);

  /// Borra lo bajado. Para cuando el celular se queda sin lugar.
  Future<void> borrar(String archivo);

  /// Cuánto ocupa todo lo bajado, en bytes.
  Future<int> cuantoOcupa();
}

/// La de verdad: pide por internet y escribe en el disco.
///
/// Está separada de la interfaz porque los tests de pantalla corren con un
/// reloj falso, y ahí la lectura de archivos de verdad no avanza nunca: la
/// pantalla se quedaría cargando para siempre. Con la interfaz, esos tests
/// usan una de mentira que contesta en el acto.
class DescargasEnElCelular implements Descargas {
  DescargasEnElCelular({
    http.Client? cliente,
    Future<Directory?> Function()? carpeta,
  })
      : _cliente = cliente ?? http.Client(),
        _carpeta = carpeta ?? _laDeLaApp;

  final http.Client _cliente;
  final Future<Directory?> Function() _carpeta;

  static Future<Directory?> _laDeLaApp() async {
    try {
      return await getApplicationSupportDirectory();
    } catch (_) {
      return null;
    }
  }

  /// Cuánto se espera por un archivo. Son menos de un mega con buena señal,
  /// pero con señal mala un minuto es poco.
  static const _paciencia = Duration(minutes: 3);

  @override
  Future<File?> donde(String archivo) async {
    final carpeta = await _carpeta();
    if (carpeta == null) return null;
    return File('${carpeta.path}/audio/$archivo');
  }

  @override
  Future<bool> yaEsta(String archivo) async {
    final donde_ = await donde(archivo);
    if (donde_ == null) return false;
    return donde_.exists();
  }

  @override
  Future<Set<String>> cualesEstan(Iterable<String> archivos) async {
    final estan = <String>{};
    for (final archivo in archivos) {
      if (await yaEsta(archivo)) estan.add(archivo);
    }
    return estan;
  }

  /// Se baja a un archivo con otro nombre y recién al final se le pone el
  /// definitivo. Sin eso, una bajada cortada a la mitad deja un mp3 roto que
  /// la próxima vez se da por bueno —ya existe— y no suena nunca.
  @override
  Future<File?> bajar(String url, String archivo) async {
    final destino = await donde(archivo);
    if (destino == null) return null;
    if (await destino.exists()) return destino;

    final aMedias = File('${destino.path}.bajando');
    try {
      await destino.parent.create(recursive: true);
      final respuesta =
          await _cliente.get(Uri.parse(url)).timeout(_paciencia);
      if (respuesta.statusCode != 200 || respuesta.bodyBytes.isEmpty) {
        return null;
      }
      await aMedias.writeAsBytes(respuesta.bodyBytes, flush: true);
      await aMedias.rename(destino.path);
      return destino;
    } catch (_) {
      // Sin señal, el servidor caído, el celular sin lugar: para el alumno es
      // lo mismo, y la pantalla lo dice de una sola forma.
      try {
        if (await aMedias.exists()) await aMedias.delete();
      } catch (_) {}
      return null;
    }
  }

  @override
  Future<void> borrar(String archivo) async {
    final donde_ = await donde(archivo);
    if (donde_ == null) return;
    try {
      if (await donde_.exists()) await donde_.delete();
    } catch (_) {}
  }

  @override
  Future<int> cuantoOcupa() async {
    final carpeta = await _carpeta();
    if (carpeta == null) return 0;
    final audio = Directory('${carpeta.path}/audio');
    if (!await audio.exists()) return 0;
    var total = 0;
    try {
      await for (final cosa in audio.list()) {
        if (cosa is File) total += await cosa.length();
      }
    } catch (_) {}
    return total;
  }
}
