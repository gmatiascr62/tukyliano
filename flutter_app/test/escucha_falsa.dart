import 'package:tukyliano/datos/escucha.dart';

/// Micrófono de mentira: contesta lo que se le dejó preparado. En los tests no
/// hay micrófono ni plugin, así que el de verdad no se puede usar.
class EscuchaFalsa implements Escucha {
  EscuchaFalsa({
    this.respuesta,
    this.puedeEscuchar = true,
    this.problema = '',
    this.diagnostico = '',
    this.parciales = const [],
  });

  /// Lo que va a "escuchar". Null imita el silencio.
  LoEscuchado? respuesta;

  /// False imita el celular sin reconocedor, o sin permiso al micrófono.
  final bool puedeEscuchar;

  /// Lo que se va entendiendo mientras se habla, antes de la respuesta.
  final List<String> parciales;

  @override
  String problema;

  @override
  String diagnostico;

  int escuchadas = 0;
  int cortadas = 0;

  @override
  bool get listo => puedeEscuchar;

  @override
  Future<bool> preparar() async => puedeEscuchar;

  @override
  Future<LoEscuchado?> escuchar({
    void Function(String parcial)? alOir,
    void Function(double volumen)? alSonido,
  }) async {
    escuchadas++;
    if (!puedeEscuchar) return null;
    for (final parcial in parciales) {
      alOir?.call(parcial);
      alSonido?.call(0.5);
    }
    return respuesta;
  }

  @override
  Future<void> cortar() async => cortadas++;
}
