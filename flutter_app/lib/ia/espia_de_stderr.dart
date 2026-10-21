import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

/// Nombre del archivo donde queda lo último que dijo el código nativo.
const String archivoDelDicho = 'ultimo_error_nativo.txt';

/// Atrapa lo que el código nativo escribe en la salida de error.
///
/// llama.cpp cuenta en detalle por qué no pudo cargar un modelo, pero lo
/// escribe en la salida de error del proceso. En una computadora eso se lee en
/// la terminal; en un celular no se lee en ningún lado, y lo único que queda es
/// un "no se pudo" sin motivo.
///
/// Esto lo desvía a un archivo mientras dura el intento y después lo devuelve.
/// Es el mismo truco que usa cualquier programa para guardar su propia salida:
/// la salida de error es el descriptor número 2, y se puede apuntar a otro
/// lado con dup2. Al terminar se deja todo como estaba.
///
/// Solo en Linux y Android, que es donde los números de abajo son estos. En
/// cualquier otro lado no hace nada y no molesta.
class EspiaDeStderr {
  EspiaDeStderr(this.archivo);

  /// Dónde se guarda lo que diga el código nativo.
  final File archivo;

  /// Copia de la salida de error original, para devolverla a su lugar.
  int? _laDeAntes;
  int? _laDelArchivo;

  static bool get sirveAca => Platform.isAndroid || Platform.isLinux;

  // Los números de open(2) en Linux y Android.
  static const int _soloEscribir = 1; // O_WRONLY
  static const int _crearloSiNoEsta = 64; // O_CREAT
  static const int _vaciarlo = 512; // O_TRUNC
  static const int _permisos = 420; // 0644
  static const int _salidaDeError = 2;

  /// Empieza a guardar. Devuelve false si no se pudo (y entonces no hay nada
  /// que deshacer).
  bool empezar() {
    if (!sirveAca || _laDeAntes != null) return false;
    try {
      final libc = DynamicLibrary.process();
      final abrir = libc.lookupFunction<Int32 Function(Pointer<Utf8>, Int32, Int32),
          int Function(Pointer<Utf8>, int, int)>('open');
      final copiar =
          libc.lookupFunction<Int32 Function(Int32), int Function(int)>('dup');
      final apuntar = libc.lookupFunction<Int32 Function(Int32, Int32),
          int Function(int, int)>('dup2');

      final nombre = archivo.path.toNativeUtf8();
      final alArchivo = abrir(
        nombre,
        _soloEscribir | _crearloSiNoEsta | _vaciarlo,
        _permisos,
      );
      malloc.free(nombre);
      if (alArchivo < 0) return false;

      final guardada = copiar(_salidaDeError);
      if (guardada < 0 || apuntar(alArchivo, _salidaDeError) < 0) {
        _cerrar(alArchivo);
        if (guardada >= 0) _cerrar(guardada);
        return false;
      }

      _laDeAntes = guardada;
      _laDelArchivo = alArchivo;
      return true;
    } catch (_) {
      // Si no están esas funciones, se sigue sin el espía.
      return false;
    }
  }

  /// Devuelve la salida de error a su lugar y entrega lo que se haya escrito.
  Future<String> terminar() async {
    final guardada = _laDeAntes;
    final alArchivo = _laDelArchivo;
    _laDeAntes = null;
    _laDelArchivo = null;
    if (guardada == null || alArchivo == null) return '';

    try {
      final libc = DynamicLibrary.process();
      libc.lookupFunction<Int32 Function(Int32, Int32), int Function(int, int)>(
          'dup2')(guardada, _salidaDeError);
      _cerrar(guardada);
      _cerrar(alArchivo);
    } catch (_) {
      // Peor que no poder devolverla es no intentarlo: igual seguimos.
    }

    try {
      if (!await archivo.exists()) return '';
      return await archivo.readAsString();
    } catch (_) {
      return '';
    }
  }

  void _cerrar(int cual) {
    try {
      DynamicLibrary.process().lookupFunction<Int32 Function(Int32),
          int Function(int)>('close')(cual);
    } catch (_) {
      // Nada que hacer.
    }
  }
}

/// De todo lo que escupió el código nativo, lo que sirve leer en una pantalla.
///
/// Son cientos de renglones contando qué tensor cargó: lo que importa es el
/// que dice qué salió mal, que es siempre uno de los últimos.
String loQueImporta(String crudo, {int cuantos = 3, int largoMaximo = 300}) {
  final renglones = crudo
      .split('\n')
      .map((renglon) => renglon.trim())
      .where((renglon) => renglon.isNotEmpty)
      .toList();
  if (renglones.isEmpty) return '';

  const palabrasFeas = ['error', 'fail', 'failed', 'cannot', 'unable', 'unsupported'];
  final feos = renglones
      .where((renglon) =>
          palabrasFeas.any((mala) => renglon.toLowerCase().contains(mala)))
      .toList();

  final elegidos = (feos.isNotEmpty ? feos : renglones);
  final ultimos = elegidos.sublist(
    elegidos.length > cuantos ? elegidos.length - cuantos : 0,
  );

  final texto = ultimos.join(' · ');
  return texto.length <= largoMaximo
      ? texto
      : texto.substring(texto.length - largoMaximo);
}
