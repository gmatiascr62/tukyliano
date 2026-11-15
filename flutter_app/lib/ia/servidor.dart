import 'dart:convert';

import 'package:http/http.dart' as http;

/// Dónde vive el servidor de la charla.
const String urlDelServidor = 'https://tukyliano.gmatiascr62.workers.dev';

/// Algo salió mal y el servidor dijo qué, en criollo.
///
/// El servidor contesta dos cosas: un `error` para el código y un `mensaje`
/// para leer. El mensaje ya viene escrito para el alumno, así que la app lo
/// muestra tal cual en vez de inventar uno propio: si algún día hay que
/// cambiar cómo se explica una falla, se cambia en el servidor y lo ven todos
/// sin instalar nada.
class FallaDelServidor implements Exception {
  const FallaDelServidor(this.motivo, this.mensaje);

  final String motivo;
  final String mensaje;

  @override
  String toString() => mensaje;
}

/// Habla con el servidor de Tukyliano.
///
/// Reemplaza al cliente de Gemini que vivía en la app. Las diferencias que
/// importan:
///
/// - **No hay clave.** Ni acá, ni en el celular, ni pegada por el usuario. El
///   modelo lo corre Cloudflare en la cuenta donde vive el servidor.
/// - **El modelo se elige del otro lado.** Cambiarlo no toca la app ni
///   necesita publicar un APK.
/// - **Los topes son del servidor.** Él sabe cuántos mensajes van hoy y
///   contesta que se acabó; la app solo lo muestra.
class Servidor {
  Servidor({http.Client? cliente, String? url})
      : _cliente = cliente ?? http.Client(),
        _url = url ?? urlDelServidor;

  final http.Client _cliente;
  final String _url;

  /// Cuánto se espera antes de darlo por perdido. El servidor se toma hasta
  /// 25 para el modelo, así que acá hay que darle un poco más.
  static const _paciencia = Duration(seconds: 30);

  /// Manda la charla y devuelve lo que contestó Tuky.
  ///
  /// [quien] es el número que la app se inventó la primera vez. [codigo] es
  /// el de invitación, si alguna vez hay lista; vacío mientras no la haya.
  Future<String> charlar({
    required String quien,
    required String saludo,
    required List<Map<String, String>> mensajes,
    String codigo = '',
  }) async {
    final http.Response respuesta;
    try {
      respuesta = await _cliente
          .post(
            Uri.parse('$_url/charla'),
            headers: {'Content-Type': 'application/json; charset=utf-8'},
            body: jsonEncode({
              'quien': quien,
              'codigo': codigo,
              'saludo': saludo,
              'mensajes': mensajes,
            }),
          )
          .timeout(_paciencia);
    } catch (e) {
      // Sin señal, o el servidor no contesta: para el alumno es lo mismo.
      throw const FallaDelServidor(
        'sinInternet',
        'No hay internet, o el servidor no está contestando. Probá de nuevo.',
      );
    }

    final datos = _leer(respuesta.bodyBytes);

    if (respuesta.statusCode != 200) {
      throw FallaDelServidor(
        datos['error'] as String? ?? 'roto',
        datos['mensaje'] as String? ??
            'Algo salió mal del lado del servidor. Avisale a Matías.',
      );
    }

    final texto = (datos['texto'] as String? ?? '').trim();
    if (texto.isEmpty) {
      throw const FallaDelServidor(
        'sinRespuesta',
        'La IA no contestó nada. Probá de nuevo.',
      );
    }
    return texto;
  }

  /// El cuerpo como mapa. Una respuesta que no es JSON no tiene que tirar
  /// abajo la pantalla: se trata como un servidor roto, que es lo que es.
  Map<String, dynamic> _leer(List<int> cuerpo) {
    try {
      final datos = jsonDecode(utf8.decode(cuerpo));
      return datos is Map<String, dynamic> ? datos : const {};
    } catch (_) {
      return const {};
    }
  }
}
