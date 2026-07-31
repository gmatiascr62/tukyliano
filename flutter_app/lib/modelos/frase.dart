/// Una frase para practicar: el español que se muestra, el italiano de
/// referencia con el que se corrige y una pista opcional (una palabra clave
/// traducida) que el alumno ve solo si la pide.
class Frase {
  const Frase({
    required this.espanol,
    required this.italiano,
    this.pista = '',
  });

  final String espanol;
  final String italiano;
  final String pista;
}
