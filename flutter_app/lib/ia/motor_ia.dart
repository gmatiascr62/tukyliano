/// El motor de IA, visto desde la app.
///
/// La pantalla del chat habla con esto y nunca con llama.cpp: así se puede
/// probar todo con un motor de mentira, y el día que convenga cambiar de motor
/// se cambia un archivo y nada más. Es el mismo arreglo que ya tienen la voz
/// ([Voz]) y el micrófono ([Escucha]).
library;

/// Lo que puede salir mal, en castellano y para mostrar en pantalla.
class ProblemaDelMotor implements Exception {
  const ProblemaDelMotor(this.mensaje);

  final String mensaje;

  @override
  String toString() => mensaje;
}

abstract class MotorIA {
  /// Carga el modelo en memoria. Tarda unos segundos la primera vez.
  ///
  /// Devuelve false si no se pudo; [problema] dice por qué.
  Future<bool> preparar();

  bool get listo;

  /// Por qué no se pudo preparar, o cadena vacía si anduvo.
  String get problema;

  /// Contesta el prompt de a pedacitos, como los va generando.
  ///
  /// Va en streaming y no de una porque un modelo chico en un celular escribe
  /// a unas pocas palabras por segundo: esperar la respuesta entera callado
  /// parecería que se colgó.
  Stream<String> responder(String prompt);

  /// Corta la respuesta que se está generando.
  Future<void> cortar();

  /// Saca el modelo de la memoria. Se llama al salir del chat: son cientos de
  /// megas y dejarlos ocupados haría que Android mate la app al rato.
  Future<void> liberar();
}
