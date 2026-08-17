import 'dart:convert';

import 'package:http/http.dart' as http;

/// Modelo "lite" a propósito: gemini-2.5-flash tiene una cuota gratis de solo
/// 20 pedidos por día por proyecto, que se agota enseguida. El lite tiene una
/// cuota aparte mucho más alta.
const String modeloGemini = 'gemini-flash-lite-latest';
const String urlGemini =
    'https://generativelanguage.googleapis.com/v1beta/models/$modeloGemini:generateContent';
const String urlClaveGemini = 'https://aistudio.google.com/apikey';

/// La clave de Gemini no existe, es inválida o fue revocada.
class ClaveInvalidaError implements Exception {
  const ClaveInvalidaError(this.detalle);
  final String detalle;
  @override
  String toString() => 'ClaveInvalidaError: $detalle';
}

/// Se agotó la cuota gratis del día. No es culpa de la clave: mañana anda.
class CuotaAgotadaError implements Exception {
  const CuotaAgotadaError();
  @override
  String toString() => 'CuotaAgotadaError';
}

/// El pedido salió bien pero no vino texto (por ejemplo, cuando el modelo
/// bloquea la respuesta).
class SinRespuestaError implements Exception {
  const SinRespuestaError();
  @override
  String toString() => 'SinRespuestaError';
}

/// Un turno de la charla en el formato que espera la API: 'user' es el alumno
/// y 'model' es la IA.
Map<String, dynamic> turnoGemini(String rol, String texto) => {
      'role': rol,
      'parts': [
        {'text': texto},
      ],
    };

/// Cliente de Gemini.
///
/// La clave NUNCA está acá: llega por parámetro desde el archivo privado del
/// celular. No se le manda generationConfig: thinkingConfig hacía fallar el
/// pedido con 400 en el modelo lite.
class Gemini {
  Gemini({http.Client? cliente}) : _cliente = cliente ?? http.Client();

  final http.Client _cliente;

  /// Manda la charla entera y devuelve lo que contesta la IA.
  ///
  /// Va toda la conversación en cada pedido porque la API no guarda nada: la
  /// memoria del chat es esta lista, y por eso alcanza con tirarla para que el
  /// chat se olvide de todo.
  Future<String> charlar(
    List<Map<String, dynamic>> contenidos,
    String apiKey,
  ) async {
    final respuesta = await _cliente
        .post(
          Uri.parse(urlGemini).replace(queryParameters: {'key': apiKey}),
          headers: {'Content-Type': 'application/json; charset=utf-8'},
          body: jsonEncode({'contents': contenidos}),
        )
        .timeout(const Duration(seconds: 25));

    if (respuesta.statusCode == 429) throw const CuotaAgotadaError();
    if (respuesta.statusCode == 403) {
      throw ClaveInvalidaError(respuesta.body);
    }
    // Un 400 puede ser la clave o un pedido mal armado. Se distingue por el
    // mensaje: si no, un error nuestro le haría creer al usuario que su clave
    // dejó de andar y la cambiaría al vicio.
    if (respuesta.statusCode == 400) {
      if (respuesta.body.toUpperCase().contains('API_KEY') ||
          respuesta.body.toUpperCase().contains('API KEY')) {
        throw ClaveInvalidaError(respuesta.body);
      }
      throw Exception('Gemini rechazó el pedido: ${respuesta.body}');
    }
    if (respuesta.statusCode != 200) {
      throw Exception('Gemini respondió ${respuesta.statusCode}');
    }

    return _texto(utf8.decode(respuesta.bodyBytes));
  }

  /// Saca el texto de la respuesta. Va todo chequeado porque un JSON distinto
  /// al esperado tiene que dar un error entendible y no un crash.
  String _texto(String cuerpo) {
    final datos = jsonDecode(cuerpo);
    if (datos is! Map) throw const SinRespuestaError();

    final candidatos = datos['candidates'];
    if (candidatos is! List || candidatos.isEmpty) {
      throw const SinRespuestaError();
    }

    final contenido = candidatos.first;
    if (contenido is! Map) throw const SinRespuestaError();
    final partes = (contenido['content'] as Map?)?['parts'];
    if (partes is! List || partes.isEmpty) throw const SinRespuestaError();

    final texto = ((partes.first as Map)['text'] as String?)?.trim() ?? '';
    if (texto.isEmpty) throw const SinRespuestaError();
    return texto;
  }
}
