import 'package:tukyliano/datos/escucha.dart';

/// Micrófono de mentira: contesta lo que se le dejó preparado. En los tests no
/// hay micrófono ni plugin, así que el de verdad no se puede usar.
class EscuchaFalsa implements Escucha {
  EscuchaFalsa({
    this.respuesta,
    this.puedeEscuchar = true,
    this.problema = '',
    this.parciales = const [],
    this.porTurnos = const [],
  });

  /// Lo que va a "escuchar". Null imita el silencio.
  LoEscuchado? respuesta;

  /// Una respuesta distinta por llamada, para imitar lo que de verdad pasa con
  /// una frase larga: Android corta en la pausa de la coma y devuelve la
  /// primera mitad, y la segunda llega recién en la escucha siguiente. Pasada
  /// la lista, se queda callada.
  final List<LoEscuchado?> porTurnos;

  /// False imita el celular sin reconocedor, o sin permiso al micrófono.
  final bool puedeEscuchar;

  /// Lo que se va entendiendo mientras se habla, antes de la respuesta.
  final List<String> parciales;

  @override
  String problema;

  int escuchadas = 0;
  int cortadas = 0;
  bool _cortada = false;

  @override
  bool get listo => puedeEscuchar;

  @override
  Future<bool> preparar() async => puedeEscuchar;

  @override
  Future<LoEscuchado?> escuchar({void Function(String parcial)? alOir}) async {
    escuchadas++;
    if (!puedeEscuchar) return null;
    _cortada = false;

    if (porTurnos.isNotEmpty) {
      final turno = escuchadas - 1;
      final oido = turno < porTurnos.length ? porTurnos[turno] : null;
      if (oido != null) alOir?.call(oido.mejor);
      return oido;
    }

    LoEscuchado? ultimo;
    for (final parcial in parciales) {
      ultimo = LoEscuchado(mejor: parcial, alternativas: [parcial]);
      alOir?.call(parcial);
      // Como el micrófono de verdad: si lo cortan a mitad de camino, contesta
      // con lo último que llegó a entender.
      if (_cortada) return ultimo;
    }
    // Una sola vez, como el de verdad: Android manda un resultado final por
    // sesión de escucha, y si después se lo vuelve a llamar y no se dice nada
    // más, contesta silencio. Devolverlo en cada llamada hacía que la pantalla
    // pareciera escuchar ocho veces lo mismo.
    return escuchadas == 1 ? respuesta : null;
  }

  @override
  Future<void> cortar() async {
    cortadas++;
    _cortada = true;
  }
}
