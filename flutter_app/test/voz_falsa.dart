import 'dart:async';

import 'package:tukyliano/datos/voz.dart';

/// Voz de mentira: anota lo que se le pidió decir. En los tests no hay motor
/// de voz, así que la de verdad no se puede usar.
class VozFalsa implements Voz {
  VozFalsa({
    this.hayItaliano = true,
    this.cuantasVoces = 2,
    this.deACadaUna = false,
  });

  /// Con true, decirYEsperar no vuelve hasta que el test llame a [seguir].
  ///
  /// Sirve para mirar la pantalla en el medio de un episodio. Sin esto, el
  /// episodio entero pasa en un suspiro y solo se puede ver cómo quedó al
  /// final, que es justo donde los errores de desplazamiento no se notan.
  final bool deACadaUna;

  Completer<void>? _frenada;

  /// False imita el celular sin la voz italiana instalada.
  final bool hayItaliano;

  /// Cuántas de las voces ofrecidas encontró. Con una sola no hay selector.
  final int cuantasVoces;

  final dicho = <String>[];
  int callados = 0;
  bool? lenta;

  @override
  late final List<VozItaliana> voces = [
    for (var i = 0; i < cuantasVoces; i++)
      VozItaliana(
        id: 'it-it-x-v$i-local',
        nombre: vocesOfrecidas.values.elementAt(i),
      ),
  ];

  @override
  VozItaliana? vozElegida;

  @override
  Future<void> usarVoz(VozItaliana voz) async => vozElegida = voz;

  @override
  Future<bool> preparar() async {
    if (!hayItaliano) return false;
    // La voz de verdad fija la primera al prepararse, así la pastilla muestra
    // la que de verdad suena.
    if (voces.isNotEmpty) await usarVoz(voces.first);
    return true;
  }

  @override
  Future<void> decir(String texto) async {
    if (!hayItaliano) throw StateError('no debería hablar sin voz italiana');
    dicho.add(texto);
  }

  /// La de verdad vuelve recién cuando terminó de hablar. Acá vuelve enseguida
  /// —no hay nada que esperar— pero anota con qué voz se dijo cada frase, que
  /// es lo que el podcast necesita poder probar: que Giulia y Lorenzo se
  /// turnen de verdad.
  final conQueVoz = <String>[];

  @override
  Future<void> decirYEsperar(String texto) async {
    if (!hayItaliano) throw StateError('no debería hablar sin voz italiana');
    dicho.add(texto);
    conQueVoz.add(vozElegida?.nombre ?? 'la de fábrica');
    if (!deACadaUna) return;
    _frenada = Completer<void>();
    await _frenada!.future;
  }

  /// Deja que termine la frase que está diciendo.
  void seguir() {
    final frenada = _frenada;
    _frenada = null;
    if (frenada != null && !frenada.isCompleted) frenada.complete();
  }

  @override
  Future<void> callar() async {
    callados++;
    seguir();
  }

  @override
  Future<void> usarVelocidadLenta(bool valor) async => lenta = valor;
}
