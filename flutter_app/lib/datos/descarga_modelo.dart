import 'dart:async';
import 'dart:io';

import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../ia/modelo.dart';

/// En qué anda la bajada del modelo.
enum PasoDescarga {
  /// Todavía no se sabe: hay que mirar si el archivo ya está.
  mirando,

  /// No está y hay que bajarlo.
  falta,

  /// Bajando. [Descarga.cuanto] dice cuánto va.
  bajando,

  /// Bajado entero; se está sacando la huella para ver si es el que es. En un
  /// celular común son unos segundos y por eso se avisa aparte.
  verificando,

  /// Está y sirve.
  listo,

  /// Algo salió mal. [Descarga.problema] dice qué.
  fallo,
}

/// Cómo viene la bajada, para pintarlo en pantalla.
class Descarga {
  const Descarga({
    required this.paso,
    this.bajados = 0,
    this.total = bytesDelModelo,
    this.problema = '',
  });

  final PasoDescarga paso;

  /// Cuántos bytes hay en el celular, contando lo de una bajada anterior que se
  /// haya cortado.
  final int bajados;

  /// Cuánto pesa el archivo entero.
  final int total;

  final String problema;

  /// De 0 a 1, para la barra.
  double get cuanto => total <= 0 ? 0 : (bajados / total).clamp(0, 1).toDouble();

  /// "148 de 383 MB", que es lo que se entiende de una bajada.
  String get texto {
    final hechos = (bajados / (1024 * 1024)).round();
    final todos = (total / (1024 * 1024)).round();
    return '$hechos de $todos MB';
  }
}

/// Baja el modelo de IA y lo deja guardado en la carpeta privada de la app.
///
/// Tres cosas que no son obvias y por las que está escrito así:
///
/// - **Se puede retomar.** Son cientos de megas: cortarse a la mitad y tener que
///   empezar de nuevo sería insoportable. Lo bajado va a un archivo aparte y la
///   próxima vez se pide desde donde quedó, con una cabecera Range.
/// - **Se verifica.** Recién cuando la huella SHA-256 coincide con la que está
///   escrita en el código, el archivo pasa a llamarse como el bueno. Así nunca
///   se intenta cargar un modelo cortado por la mitad.
/// - **La huella se saca de a pedazos.** Leer mil megas de una en memoria tumba un
///   celular de gama baja.
class DescargaModelo {
  DescargaModelo({
    http.Client? cliente,
    Future<Directory?> Function()? carpeta,
    this.url = urlDelModelo,
    this.huellaEsperada = sha256DelModelo,
  })  : _cliente = cliente ?? http.Client(),
        _carpeta = carpeta ?? _carpetaDeLaApp;

  final http.Client _cliente;

  /// Devuelve null cuando no hay dónde guardar (los tests).
  final Future<Directory?> Function() _carpeta;

  final String url;
  final String huellaEsperada;

  static Future<Directory?> _carpetaDeLaApp() =>
      getApplicationDocumentsDirectory();

  bool _cortar = false;

  Future<File?> _elBueno() async {
    final dir = await _carpeta();
    return dir == null ? null : File('${dir.path}/$archivoDelModelo');
  }

  Future<File?> _elQueSeEstaBajando() async {
    final dir = await _carpeta();
    return dir == null ? null : File('${dir.path}/$archivoDelModeloAMedias');
  }

  /// Dónde quedó el modelo, o null si todavía no está.
  Future<String?> rutaSiEsta() async {
    try {
      final archivo = await _elBueno();
      if (archivo == null || !await archivo.exists()) return null;
      return archivo.path;
    } catch (_) {
      return null;
    }
  }

  /// Cuánto hay bajado de una vez anterior que se cortó.
  Future<int> cuantoHayAMedias() async {
    try {
      final archivo = await _elQueSeEstaBajando();
      if (archivo == null || !await archivo.exists()) return 0;
      return await archivo.length();
    } catch (_) {
      return 0;
    }
  }

  /// Baja el modelo, contando cómo va.
  ///
  /// Si ya está, termina en [PasoDescarga.listo] sin tocar la red. Si hay una
  /// bajada a medias, sigue desde ahí.
  Stream<Descarga> bajar() async* {
    _cortar = false;
    yield const Descarga(paso: PasoDescarga.mirando);

    final bueno = await _elBueno();
    final aMedias = await _elQueSeEstaBajando();
    if (bueno == null || aMedias == null) {
      yield const Descarga(
        paso: PasoDescarga.fallo,
        problema: 'No hay dónde guardar el modelo en este celular.',
      );
      return;
    }

    if (await bueno.exists()) {
      yield Descarga(
        paso: PasoDescarga.listo,
        bajados: await bueno.length(),
        total: await bueno.length(),
      );
      return;
    }

    var hechos = await cuantoHayAMedias();
    IOSink? abierto;

    try {
      final pedido = http.Request('GET', Uri.parse(url));
      if (hechos > 0) pedido.headers['Range'] = 'bytes=$hechos-';

      final respuesta = await _cliente.send(pedido).timeout(
            const Duration(seconds: 30),
          );

      // 206 = me manda el pedazo que falta. 200 = me manda todo de nuevo, así
      // que lo que había no sirve y se empieza de cero.
      if (respuesta.statusCode == 200) {
        hechos = 0;
        if (await aMedias.exists()) await aMedias.delete();
      } else if (respuesta.statusCode != 206) {
        yield Descarga(
          paso: PasoDescarga.fallo,
          bajados: hechos,
          problema: 'El servidor contestó ${respuesta.statusCode}. '
              'Probá de nuevo más tarde.',
        );
        return;
      }

      final total = hechos + (respuesta.contentLength ?? bytesDelModelo);
      yield Descarga(paso: PasoDescarga.bajando, bajados: hechos, total: total);

      final escribiendo = aMedias.openWrite(mode: FileMode.append);
      abierto = escribiendo;
      // Avisar a cada pedacito haría mil setState por segundo: alcanza con
      // avisar cuando se nota en la barra.
      var desdeElUltimoAviso = 0;

      await for (final pedazo in respuesta.stream) {
        if (_cortar) {
          await escribiendo.flush();
          await escribiendo.close();
          abierto = null;
          yield Descarga(paso: PasoDescarga.falta, bajados: hechos, total: total);
          return;
        }
        escribiendo.add(pedazo);
        hechos += pedazo.length;
        desdeElUltimoAviso += pedazo.length;
        if (desdeElUltimoAviso >= 512 * 1024) {
          desdeElUltimoAviso = 0;
          yield Descarga(
            paso: PasoDescarga.bajando,
            bajados: hechos,
            total: total,
          );
        }
      }

      await escribiendo.flush();
      await escribiendo.close();
      abierto = null;

      yield Descarga(paso: PasoDescarga.verificando, bajados: hechos, total: total);

      final huella = await _huellaDe(aMedias);
      if (huella != huellaEsperada) {
        // No sirve de nada guardarlo: o se cortó mal o no es el archivo que
        // esperábamos. En los dos casos hay que bajarlo de nuevo entero.
        await aMedias.delete();
        yield Descarga(
          paso: PasoDescarga.fallo,
          total: total,
          problema: 'El archivo que se bajó no es el que esperábamos. '
              'Se borró; probá de nuevo.',
        );
        return;
      }

      await aMedias.rename(bueno.path);
      await borrarLosViejos();
      yield Descarga(paso: PasoDescarga.listo, bajados: hechos, total: total);
    } on TimeoutException {
      yield Descarga(
        paso: PasoDescarga.fallo,
        bajados: hechos,
        problema: 'El servidor tardó demasiado. Probá de nuevo.',
      );
    } catch (error) {
      yield Descarga(
        paso: PasoDescarga.fallo,
        bajados: hechos,
        problema: 'Se cortó la bajada. Fijate si tenés internet y seguí desde '
            'donde quedó.',
      );
    } finally {
      await abierto?.flush();
      await abierto?.close();
    }
  }

  /// Corta la bajada en curso. Lo bajado queda para la próxima.
  void cortar() => _cortar = true;

  /// Borra el modelo y lo que haya a medias. Es lo que hace falta para
  /// recuperar los megas o para empezar de nuevo.
  Future<void> borrar() async {
    for (final archivo in [await _elBueno(), await _elQueSeEstaBajando()]) {
      try {
        if (archivo != null && await archivo.exists()) await archivo.delete();
      } catch (_) {
        // Si no se puede borrar, no hay nada que hacer: tampoco es grave.
      }
    }
  }

  /// Borra los modelos de versiones anteriores de la app.
  ///
  /// Cada modelo lleva su revisión en el nombre, así que al cambiar de modelo
  /// el viejo queda ahí ocupando sus cientos de megas sin que nadie lo use ni
  /// lo vea. Esto corre cuando el nuevo ya está bajado y verificado: antes no,
  /// porque si la bajada falla el viejo es lo único que hay.
  Future<void> borrarLosViejos() async {
    try {
      final dir = await _carpeta();
      if (dir == null) return;
      await for (final cosa in dir.list()) {
        final nombre = cosa.path.split('/').last;
        final esDeUnModelo = nombre.startsWith(principioDeLosModelos) &&
            (nombre.endsWith('.gguf') || nombre.endsWith('.bajando'));
        final esElDeAhora = nombre == archivoDelModelo ||
            nombre == archivoDelModeloAMedias;
        if (cosa is File && esDeUnModelo && !esElDeAhora) {
          await cosa.delete();
        }
      }
    } catch (_) {
      // Dejar basura no es grave; romper por querer limpiarla, sí.
    }
  }

  /// La huella del archivo, leyéndolo de a pedazos para no cargarlo entero en
  /// memoria.
  Future<String> _huellaDe(File archivo) async {
    final salida = AccumulatorSink<Digest>();
    final entrada = sha256.startChunkedConversion(salida);
    await for (final pedazo in archivo.openRead()) {
      entrada.add(pedazo);
    }
    entrada.close();
    return salida.events.single.toString();
  }
}
