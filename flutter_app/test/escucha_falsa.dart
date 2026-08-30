import 'package:tukyliano/datos/escucha.dart';

/// Micrófono de mentira: contesta lo que se le dejó preparado. En los tests no
/// hay micrófono ni plugin, así que el de verdad no se puede usar.
class EscuchaFalsa implements Escucha {
  EscuchaFalsa({
    this.respuesta,
    this.puedeEscuchar = true,
    this.problema = '',
  });

  /// Lo que va a "escuchar". Null imita el silencio.
  LoEscuchado? respuesta;

  /// False imita el celular sin reconocedor, o sin permiso al micrófono.
  final bool puedeEscuchar;

  @override
  String problema;

  int escuchadas = 0;
  int cortadas = 0;

  @override
  bool get listo => puedeEscuchar;

  @override
  Future<bool> preparar() async => puedeEscuchar;

  @override
  Future<LoEscuchado?> escuchar() async {
    escuchadas++;
    if (!puedeEscuchar) return null;
    return respuesta;
  }

  @override
  Future<void> cortar() async => cortadas++;
}
