import 'package:tukyliano/datos/voz.dart';

/// Voz de mentira: anota lo que se le pidió decir. En los tests no hay motor
/// de voz, así que la de verdad no se puede usar.
class VozFalsa implements Voz {
  VozFalsa({this.hayItaliano = true, this.cuantasVoces = 2});

  /// False imita el celular sin la voz italiana instalada.
  final bool hayItaliano;

  /// Cuántas voces italianas tiene el celular. Con una sola no hay selector.
  final int cuantasVoces;

  final dicho = <String>[];
  int callados = 0;
  bool? lenta;

  @override
  late final List<VozItaliana> voces = [
    for (var i = 0; i < cuantasVoces; i++)
      VozItaliana(id: 'it-it-x-v$i-local', nombre: nombresDeVoces[i]),
  ];

  @override
  VozItaliana? vozElegida;

  @override
  Future<void> usarVoz(VozItaliana voz) async => vozElegida = voz;

  @override
  Future<bool> preparar() async => hayItaliano;

  @override
  Future<void> decir(String texto) async {
    if (!hayItaliano) throw StateError('no debería hablar sin voz italiana');
    dicho.add(texto);
  }

  @override
  Future<void> callar() async => callados++;

  @override
  Future<void> usarVelocidadLenta(bool valor) async => lenta = valor;
}
