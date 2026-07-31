/// Una palabra de la respuesta correcta, con si el alumno la acertó o no.
class PalabraCorregida {
  const PalabraCorregida(this.palabra, this.acertada);

  final String palabra;
  final bool acertada;
}

/// Deja la palabra comparable: sin mayúsculas y sin los signos de alrededor
/// (¿ ? ¡ ! . , ; :). Los acentos se mantienen a propósito: en italiano
/// distinguen conjugaciones (sarò no es saro) y el teclado de la app tiene las
/// teclas para escribirlos. El apóstrofo también queda, porque forma parte de
/// la palabra (un'idea, d'acqua).
String normalizar(String palabra) {
  final limpia = palabra.toLowerCase().replaceAll(RegExp(r'''^[^\wàèéìòùá-ú']+|[^\wàèéìòùá-ú']+$'''), '');
  return limpia;
}

List<String> _palabras(String frase) => frase
    .split(RegExp(r'\s+'))
    .map(normalizar)
    .where((p) => p.isNotEmpty)
    .toList();

/// Marca palabra por palabra de la respuesta correcta si el alumno la escribió.
///
/// La comparación no mira la posición: alcanza con que la palabra aparezca en
/// la respuesta. Si mirara la posición, olvidarse una palabra al principio
/// pintaría de rojo todo el resto, que no es lo que pasó.
List<PalabraCorregida> corregir({
  required String correcta,
  required String respuesta,
}) {
  final escritas = _palabras(respuesta);

  return [
    for (final original in correcta.split(RegExp(r'\s+')).where((p) => p.isNotEmpty))
      if (normalizar(original).isEmpty)
        PalabraCorregida(original, true)
      else if (escritas.remove(normalizar(original)))
        PalabraCorregida(original, true)
      else
        PalabraCorregida(original, false),
  ];
}

/// True si acertó todas las palabras de la respuesta correcta.
bool todoAcertado(List<PalabraCorregida> corregidas) =>
    corregidas.isNotEmpty && corregidas.every((p) => p.acertada);
