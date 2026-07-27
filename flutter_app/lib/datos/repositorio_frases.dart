import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart' show rootBundle;

import '../constantes.dart';
import '../ia/prompts.dart';

/// Frases escritas a mano y empaquetadas con la app, indexadas por
/// verbo + tiempo + persona.
///
/// Sirven para dos cosas: la frase aparece al instante (no hay que esperar a
/// Gemini) y no gasta cuota. Cuando una forma no tiene frase guardada, la
/// pantalla sigue pidiéndosela a la IA como antes.
class RepositorioFrases {
  RepositorioFrases({Future<String> Function(String)? leerAsset})
      : _leerAsset = leerAsset ?? rootBundle.loadString;

  final Future<String> Function(String) _leerAsset;

  final Map<String, List<FraseGenerada>> _porForma = {};
  bool _cargado = false;

  static String claveDe(String verbo, String tiempo, String persona) =>
      '$verbo|$tiempo|$persona';

  /// Lee el asset una sola vez. Si falla, la app queda como estaba antes de
  /// que existieran las frases guardadas: todo lo genera la IA.
  Future<void> cargar() async {
    if (_cargado) return;
    _cargado = true;
    try {
      final json = jsonDecode(await _leerAsset(assetFrases));
      final lista = (json is Map<String, dynamic> ? json['frases'] : json);
      if (lista is! List) return;
      for (final item in lista) {
        if (item is! Map<String, dynamic>) continue;
        final espanol = item['espanol'] as String? ?? '';
        final italiano = item['italiano'] as String? ?? '';
        if (espanol.isEmpty || italiano.isEmpty) continue;
        final clave = claveDe(
          item['verbo'] as String? ?? '',
          item['tiempo'] as String? ?? '',
          item['persona'] as String? ?? '',
        );
        _porForma.putIfAbsent(clave, () => []).add(FraseGenerada(
              espanol: espanol,
              italiano: italiano,
              pista: item['pista'] as String? ?? '',
            ));
      }
    } catch (_) {
      // Un asset roto no puede dejar la pantalla sin frases.
    }
  }

  /// Una frase al azar entre las guardadas para esa forma, o null si no hay.
  FraseGenerada? elegir({
    required String verbo,
    required String tiempo,
    required String persona,
    Random? azar,
  }) {
    final opciones = _porForma[claveDe(verbo, tiempo, persona)];
    if (opciones == null || opciones.isEmpty) return null;
    return opciones[(azar ?? Random()).nextInt(opciones.length)];
  }

  /// Cuántas frases hay cargadas. Se usa en los tests.
  int get cantidad => _porForma.values.fold(0, (n, l) => n + l.length);
}
