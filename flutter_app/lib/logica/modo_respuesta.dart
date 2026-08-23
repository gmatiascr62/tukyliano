/// Las dos formas de contestar un ejercicio.
///
/// Está acá y no adentro de una pantalla porque lo usan varias: el «via» y el
/// quiz de verbos, y las dos tienen que decir lo mismo en el botón.
enum ModoRespuesta {
  /// Se toca cuál de las opciones va. Rápido, y es el que sirve para
  /// reconocer: la respuesta está a la vista y hay que elegirla.
  elegir,

  /// Se escribe la respuesta entera. Es más difícil porque no hay de dónde
  /// copiarse: hay que acordarse de cómo se escribe.
  escribir,
}

extension EtiquetaModo on ModoRespuesta {
  String get etiqueta => switch (this) {
        ModoRespuesta.elegir => 'Elegir',
        ModoRespuesta.escribir => 'Escribir',
      };
}
