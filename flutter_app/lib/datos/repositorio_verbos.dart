import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../constantes.dart';
import '../modelos/verbo.dart';

/// Cómo terminó el chequeo de verbos nuevos.
///
/// No tiene mensajes: la actualización es silenciosa a propósito. Al usuario
/// no le sirve saber que se fue a mirar si había verbos nuevos; solo le
/// importa que estén. Los estados quedan porque los usan los tests y porque
/// distinguen "llegaron datos nuevos" de "no pasó nada".
enum EstadoActualizacion { actualizado, yaAlDia, sinConexion, error }

class ResultadoActualizacion {
  const ResultadoActualizacion(this.estado, [this.datos]);

  final EstadoActualizacion estado;

  /// Solo viene cuando el estado es [EstadoActualizacion.actualizado].
  final DatosVerbos? datos;
}

/// Carga los verbos y chequea si hay una versión nueva en GitHub.
class RepositorioVerbos {
  RepositorioVerbos({http.Client? cliente}) : _cliente = cliente ?? http.Client();

  final http.Client _cliente;
  File? _archivoLocal;

  /// Archivo escribible propio de la app. En Android la carpeta de la app es
  /// de solo lectura, igual que pasaba en Kivy con user_data_dir.
  Future<File> _obtenerArchivoLocal() async {
    if (_archivoLocal != null) return _archivoLocal!;
    final dir = await getApplicationDocumentsDirectory();
    return _archivoLocal = File('${dir.path}/$archivoVerbosLocal');
  }

  /// Devuelve los verbos guardados. La primera vez copia el JSON empaquetado
  /// con la app al archivo escribible.
  Future<DatosVerbos> cargar() async {
    final archivo = await _obtenerArchivoLocal();

    if (!await archivo.exists()) {
      final porDefecto = await rootBundle.loadString(assetVerbos);
      await archivo.writeAsString(porDefecto);
    }

    return _parsear(await archivo.readAsString());
  }

  /// Chequea el JSON remoto y, si trae una versión más nueva, la guarda.
  Future<ResultadoActualizacion> verificarActualizacion(int versionActual) async {
    try {
      final respuesta = await _cliente
          .get(Uri.parse(urlRemoto))
          .timeout(const Duration(seconds: 8));

      if (respuesta.statusCode != 200) {
        return const ResultadoActualizacion(EstadoActualizacion.error);
      }

      // El body viene en UTF-8: sin esto los acentos se rompen.
      final remotos = _parsear(utf8.decode(respuesta.bodyBytes));

      if (remotos.version > versionActual) {
        final archivo = await _obtenerArchivoLocal();
        await archivo.writeAsString(utf8.decode(respuesta.bodyBytes));
        return ResultadoActualizacion(EstadoActualizacion.actualizado, remotos);
      }

      return const ResultadoActualizacion(EstadoActualizacion.yaAlDia);
    } on SocketException {
      return const ResultadoActualizacion(EstadoActualizacion.sinConexion);
    } on http.ClientException {
      return const ResultadoActualizacion(EstadoActualizacion.sinConexion);
    } catch (_) {
      return const ResultadoActualizacion(EstadoActualizacion.error);
    }
  }

  DatosVerbos _parsear(String texto) =>
      DatosVerbos.desdeJson(jsonDecode(texto) as Map<String, dynamic>);
}
