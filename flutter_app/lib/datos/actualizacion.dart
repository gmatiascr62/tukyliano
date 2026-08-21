import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// El número de build con el que se compiló este APK.
///
/// Lo pone el workflow con `--dart-define=BUILD=<número de la corrida>`, que
/// siempre sube. Compilando a mano queda en 0, y con 0 no se busca ninguna
/// actualización: sería comparar contra nada.
const int buildInstalado = int.fromEnvironment('BUILD');

/// La última versión publicada. Es la API de GitHub, que en un repo público
/// contesta sin necesidad de ninguna clave.
const String urlUltimaVersion =
    'https://api.github.com/repos/gmatiascr62/tukyliano/releases/latest';

/// Cómo se llama el archivo bajado. Se pisa siempre el mismo para no ir
/// dejando APKs viejos ocupando lugar.
const String archivoActualizacion = 'Tukyliano.apk';

/// Una versión publicada, más nueva que la instalada.
class VersionNueva {
  const VersionNueva({
    required this.nombre,
    required this.build,
    required this.url,
    required this.bytes,
  });

  /// Como se muestra: "1.0.63".
  final String nombre;

  /// Lo que se compara contra [buildInstalado].
  final int build;

  /// De dónde se baja el APK.
  final String url;

  final int bytes;

  /// Para mostrarle al usuario cuánto va a gastar antes de bajarla.
  String get tamano => '${(bytes / (1024 * 1024)).round()} MB';
}

/// El número de build que trae una etiqueta como "v1.0.63".
///
/// Es el último pedazo después del punto, que es como lo publica el workflow.
/// Si la etiqueta tuviera otra forma se devuelve 0 y no se ofrece nada: mejor
/// no avisar nada que ofrecer una actualización que no se entiende.
int buildDeEtiqueta(String etiqueta) {
  final ultimo = etiqueta.split('.').last;
  return int.tryParse(ultimo) ?? 0;
}

/// Busca y baja la actualización.
class Actualizacion {
  Actualizacion({
    http.Client? cliente,
    int? instalado,
    Future<Directory?> Function()? carpeta,
  })  : _cliente = cliente ?? http.Client(),
        _instalado = instalado ?? buildInstalado,
        _carpeta = carpeta ?? _carpetaDeDescargas;

  final http.Client _cliente;
  final int _instalado;
  final Future<Directory?> Function() _carpeta;

  static Future<Directory?> _carpetaDeDescargas() async {
    // La carpeta propia de la app en la memoria externa: no hace falta ningún
    // permiso y el instalador de Android la puede leer.
    try {
      return await getExternalStorageDirectory() ??
          await getApplicationDocumentsDirectory();
    } catch (_) {
      return null;
    }
  }

  /// La versión publicada si es más nueva que la instalada, o null.
  ///
  /// Nunca tira: si no hay internet, si GitHub contesta cualquier cosa o si
  /// todavía no hay ninguna publicada, simplemente no hay novedades. Esto
  /// corre al arrancar la app y no tiene por qué molestar a nadie.
  Future<VersionNueva?> buscar() async {
    if (_instalado <= 0) return null;

    try {
      final respuesta = await _cliente
          .get(Uri.parse(urlUltimaVersion), headers: {
            'Accept': 'application/vnd.github+json',
          })
          .timeout(const Duration(seconds: 10));
      if (respuesta.statusCode != 200) return null;

      final datos = jsonDecode(utf8.decode(respuesta.bodyBytes));
      if (datos is! Map) return null;

      final etiqueta = datos['tag_name'] as String? ?? '';
      final build = buildDeEtiqueta(etiqueta);
      if (build <= _instalado) return null;

      final apk = _apkDe(datos['assets']);
      if (apk == null) return null;

      return VersionNueva(
        nombre: etiqueta.startsWith('v') ? etiqueta.substring(1) : etiqueta,
        build: build,
        url: apk['browser_download_url'] as String,
        bytes: apk['size'] as int? ?? 0,
      );
    } catch (_) {
      return null;
    }
  }

  /// El archivo .apk de la publicación. Puede haber otros adjuntos.
  Map<String, dynamic>? _apkDe(Object? assets) {
    if (assets is! List) return null;
    for (final item in assets) {
      if (item is! Map<String, dynamic>) continue;
      final nombre = item['name'] as String? ?? '';
      final url = item['browser_download_url'] as String? ?? '';
      if (nombre.toLowerCase().endsWith('.apk') && url.isNotEmpty) return item;
    }
    return null;
  }

  /// Baja el APK y devuelve dónde quedó, o null si no se pudo.
  ///
  /// [alAvanzar] recibe cuánto va, de 0 a 1. Son 40 MB: sin eso la pantalla se
  /// quedaría quieta un minuto y parecería colgada.
  Future<File?> bajar(
    VersionNueva version, {
    void Function(double)? alAvanzar,
  }) async {
    try {
      final carpeta = await _carpeta();
      if (carpeta == null) return null;

      final pedido = http.Request('GET', Uri.parse(version.url));
      final respuesta = await _cliente.send(pedido);
      if (respuesta.statusCode != 200) return null;

      final total = respuesta.contentLength ?? version.bytes;
      final archivo = File('${carpeta.path}/$archivoActualizacion');
      final salida = archivo.openWrite();
      var bajado = 0;

      try {
        await for (final trozo in respuesta.stream) {
          salida.add(trozo);
          bajado += trozo.length;
          if (total > 0) alAvanzar?.call((bajado / total).clamp(0.0, 1.0));
        }
      } finally {
        await salida.close();
      }

      // Un archivo a medias no se instala: Android diría que está dañado y no
      // se entendería por qué.
      if (total > 0 && bajado < total) {
        await archivo.delete();
        return null;
      }

      return archivo;
    } catch (_) {
      return null;
    }
  }
}
