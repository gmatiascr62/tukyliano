import 'dart:async';

import 'package:tukyliano/ia/motor_ia.dart';

/// Un motor de IA de mentira, para los tests.
///
/// El de verdad necesita un modelo de 400 MB y una biblioteca nativa de
/// Android: nada de eso existe en un test. Este contesta lo que se le diga, de
/// a pedacitos como el de verdad, y anota lo que le preguntaron.
class MotorFalso implements MotorIA {
  MotorFalso({
    this.respuesta = 'Bene! E tu?',
    this.pedazos = const [],
    this.seCargaBien = true,
    this.problemaAlCargar = 'Este celular no puede correr el modelo.',
    this.error,
    this.demora = Duration.zero,
  });

  /// Lo que contesta, entero. Si [pedazos] no está vacío, manda eso.
  final String respuesta;

  /// La respuesta partida, para probar lo que se ve mientras escribe.
  final List<String> pedazos;

  final bool seCargaBien;
  final String problemaAlCargar;

  /// Para probar qué se muestra cuando algo falla.
  final Object? error;

  /// Cuánto tarda entre pedacito y pedacito.
  final Duration demora;

  /// Los prompts que se le mandaron, en orden.
  final List<String> prompts = [];

  bool preparado = false;
  bool liberado = false;
  int cortes = 0;

  @override
  bool get listo => preparado;

  @override
  String get problema => seCargaBien ? '' : problemaAlCargar;

  @override
  Future<bool> preparar() async {
    preparado = seCargaBien;
    return seCargaBien;
  }

  @override
  Stream<String> responder(String prompt) async* {
    prompts.add(prompt);
    if (error != null) throw error!;
    for (final pedazo in pedazos.isEmpty ? [respuesta] : pedazos) {
      if (demora > Duration.zero) await Future<void>.delayed(demora);
      yield pedazo;
    }
  }

  @override
  Future<void> cortar() async => cortes++;

  @override
  Future<void> liberar() async => liberado = true;
}
