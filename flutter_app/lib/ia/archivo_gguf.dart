import 'dart:io';
import 'dart:typed_data';

/// Lo que se puede saber del archivo del modelo sin cargarlo.
///
/// Cuando el modelo no carga, el que se queja es código nativo y sus mensajes
/// no salen a ningún lado: en el celular solo se ve "no se pudo". Mirar el
/// archivo desde Dart no arregla nada, pero convierte ese "no se pudo" en algo
/// que se puede contar: cuánto pesa, si de verdad es un GGUF y de qué versión.
/// Con eso se sabe si el problema es el archivo o es otra cosa.
class FichaDelArchivo {
  const FichaDelArchivo({
    required this.bytes,
    required this.esGguf,
    required this.version,
    required this.tensores,
  });

  /// Cuánto pesa, en bytes.
  final int bytes;

  /// Si arranca con las cuatro letras que lleva todo GGUF.
  final bool esGguf;

  /// Versión del formato. 3 es la que usan los modelos de hoy.
  final int version;

  /// Cuántos tensores dice tener.
  final int tensores;

  /// "378 MB, GGUF v3, 310 tensores", que es lo que sirve leer en un error.
  String get resumen {
    final megas = (bytes / (1024 * 1024)).round();
    if (!esGguf) return '$megas MB, pero no parece un archivo GGUF';
    return '$megas MB, GGUF v$version, $tensores tensores';
  }
}

/// Lee el principio del archivo del modelo. Null si no se pudo ni abrir.
///
/// Son 24 bytes: las cuatro letras, la versión y dos contadores. No hace falta
/// más y en un celular es instantáneo.
Future<FichaDelArchivo?> mirarElArchivo(File archivo) async {
  RandomAccessFile? abierto;
  try {
    final bytes = await archivo.length();
    abierto = await archivo.open();
    final principio = await abierto.read(24);
    if (principio.length < 24) {
      return FichaDelArchivo(
        bytes: bytes,
        esGguf: false,
        version: 0,
        tensores: 0,
      );
    }

    final datos = ByteData.sublistView(principio);
    final esGguf = principio[0] == 0x47 && // G
        principio[1] == 0x47 && // G
        principio[2] == 0x55 && // U
        principio[3] == 0x46; //   F

    return FichaDelArchivo(
      bytes: bytes,
      esGguf: esGguf,
      version: esGguf ? datos.getUint32(4, Endian.little) : 0,
      tensores: esGguf ? datos.getUint64(8, Endian.little) : 0,
    );
  } catch (_) {
    return null;
  } finally {
    await abierto?.close();
  }
}
