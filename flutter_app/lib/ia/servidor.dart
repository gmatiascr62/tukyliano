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

/// Lo que el servidor sabe de una palabra. Vacío cuando no la sabe nadie.
class PalabraDelServidor {
  const PalabraDelServidor({this.es = const [], this.vieneDe = ''});

  final List<String> es;

  /// La palabra de diccionario, cuando lo que se buscó era una forma.
  final String vieneDe;

  bool get hay => es.isNotEmpty;
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

  /// Manda la charla y devuelve lo que contestó.
  ///
  /// [quien] es el número que la app se inventó la primera vez. [escena] dice
  /// de qué charla se trata —la libre con Tuky, o el bar—, y con eso el
  /// servidor elige las instrucciones del modelo. [codigo] es el de
  /// invitación, si alguna vez hay lista; vacío mientras no la haya.
  Future<String> charlar({
    required String quien,
    required String saludo,
    required List<Map<String, String>> mensajes,
    String escena = 'libre',
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
              'escena': escena,
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

  /// Qué quiere decir una palabra que el diccionario de la app no tiene.
  ///
  /// Devuelve las traducciones, o la lista vacía si tampoco el servidor la
  /// sabe. **Nunca tira**: que una palabra no aparezca no puede ser un error
  /// con cartel. El que la tocó tiene que leer "no está en el diccionario",
  /// igual que antes de que esto existiera, y seguir leyendo.
  ///
  /// Del otro lado: el servidor primero mira su base, y solo si nunca nadie
  /// buscó esa palabra le pregunta a la IA y la guarda. Así se le pregunta
  /// una sola vez en la historia, y el segundo que la busque no gasta nada.
  ///
  /// [donde] es el renglón donde apareció, y es lo que desambigua:
  /// "lumicino" solo es "lucecita", y en "ridotto al lumicino" es "en las
  /// últimas".
  Future<PalabraDelServidor> queQuiereDecir({
    required String quien,
    required String palabra,
    String donde = '',
    String codigo = '',
  }) async {
    try {
      final respuesta = await _cliente
          .post(
            Uri.parse('$_url/palabra'),
            headers: {'Content-Type': 'application/json; charset=utf-8'},
            body: jsonEncode({
              'quien': quien,
              'codigo': codigo,
              'palabra': palabra,
              'donde': donde,
            }),
          )
          .timeout(_paciencia);
      if (respuesta.statusCode != 200) return const PalabraDelServidor();
      final datos = _leer(respuesta.bodyBytes);
      return PalabraDelServidor(
        es: [
          for (final t in datos['es'] as List? ?? const []) '$t',
        ],
        vieneDe: datos['base'] as String? ?? '',
      );
    } catch (_) {
      return const PalabraDelServidor();
    }
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
