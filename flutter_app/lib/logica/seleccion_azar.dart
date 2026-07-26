import 'dart:math';

import '../modelos/verbo.dart';

/// Un verbo/tiempo/persona sorteado para preguntar.
class Combo {
  const Combo({
    required this.verbo,
    required this.tiempo,
    required this.persona,
    required this.conjugacion,
  });

  final Verbo verbo;
  final String tiempo;
  final String persona;
  final Conjugacion conjugacion;
}

/// Elige verbo, tiempo y persona al azar entre los que tengan datos cargados
/// para alguno de los tiempos pedidos. Devuelve null si ninguno sirve.
Combo? elegirComboAzar(
  Iterable<Verbo> verbos,
  List<String> tiempos, {
  Random? azar,
}) {
  final random = azar ?? Random();

  final validos = verbos.where((v) => v.tieneAlgunTiempo(tiempos)).toList();
  if (validos.isEmpty) return null;

  final verbo = validos[random.nextInt(validos.length)];
  final tiemposVerbo =
      tiempos.where(verbo.tiempos.containsKey).toList();
  final tiempo = tiemposVerbo[random.nextInt(tiemposVerbo.length)];
  final personas = verbo.tiempos[tiempo]!.keys.toList();
  final persona = personas[random.nextInt(personas.length)];

  return Combo(
    verbo: verbo,
    tiempo: tiempo,
    persona: persona,
    conjugacion: verbo.tiempos[tiempo]![persona]!,
  );
}

/// Teclas especiales del teclado propio.
const String teclaBorrar = '<--';
const String teclaEspacio = 'espacio';

/// Devuelve el texto actualizado después de tocar una tecla.
String aplicarTecla(String textoActual, String tecla) {
  if (tecla == teclaBorrar) {
    return textoActual.isEmpty
        ? textoActual
        : textoActual.substring(0, textoActual.length - 1);
  }
  if (tecla == teclaEspacio) return '$textoActual ';
  return textoActual + tecla;
}
