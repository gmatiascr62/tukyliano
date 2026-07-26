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

/// Cliente de Gemini. No se le manda generationConfig: thinkingConfig hacía
/// fallar el pedido con 400 en el modelo lite.
class Gemini {
  Gemini({http.Client? cliente}) : _cliente = cliente ?? http.Client();

  final http.Client _cliente;

  Future<String> preguntar(String prompt, String apiKey) async {
    final respuesta = await _cliente
        .post(
          Uri.parse(urlGemini).replace(queryParameters: {'key': apiKey}),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'contents': [
              {
                'parts': [
                  {'text': prompt}
                ]
              }
            ],
          }),
        )
        .timeout(const Duration(seconds: 20));

    if (respuesta.statusCode == 400 || respuesta.statusCode == 403) {
      throw ClaveInvalidaError(respuesta.body);
    }
    if (respuesta.statusCode != 200) {
      throw Exception('Gemini respondió ${respuesta.statusCode}');
    }

    final datos = jsonDecode(utf8.decode(respuesta.bodyBytes));
    return datos['candidates'][0]['content']['parts'][0]['text'] as String;
  }
}

/// Gemini a veces envuelve el JSON en ```json ... ``` u otro texto alrededor.
Map<String, dynamic> extraerJson(String texto) {
  final inicio = texto.indexOf('{');
  final fin = texto.lastIndexOf('}');
  if (inicio == -1 || fin == -1 || fin < inicio) {
    throw FormatException('No se encontró JSON en la respuesta: $texto');
  }
  return jsonDecode(texto.substring(inicio, fin + 1)) as Map<String, dynamic>;
}
