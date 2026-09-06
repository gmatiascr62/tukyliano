/// El nivel que se muestra en el centro del anillo.
///
/// Sale de las respuestas acertadas y **solo sube**. Un nivel que baja porque
/// se estuvo una semana sin practicar es la forma más rápida de que alguien no
/// vuelva a abrir la app.
class Nivel {
  const Nivel({
    required this.numero,
    required this.nombre,
    required this.desde,
    required this.hasta,
    required this.aciertos,
  });

  final int numero;

  /// En italiano, como los nombres de las secciones.
  final String nombre;

  /// Cuántos aciertos hacen falta para llegar a este nivel, y cuántos para el
  /// siguiente. En el último, [hasta] es null: no hay nada más que alcanzar.
  final int desde;
  final int? hasta;

  final int aciertos;

  /// Qué parte del anillo va pintada, de 0 a 1.
  double get cuanto {
    final proximo = hasta;
    if (proximo == null) return 1;
    return ((aciertos - desde) / (proximo - desde)).clamp(0.0, 1.0);
  }

  /// Cuántos aciertos faltan para el nivel que sigue, o 0 si es el último.
  int get faltan => hasta == null ? 0 : hasta! - aciertos;

  bool get esElUltimo => hasta == null;
}

/// Cuántos aciertos pide cada nivel. Los saltos crecen para que los primeros
/// lleguen rápido —el que recién empieza necesita ver que avanza— y los
/// últimos cuesten.
const List<(int, String)> escalones = [
  (0, 'Principiante'),
  (50, 'Alunno'),
  (150, 'Studente'),
  (350, 'Esperto'),
  (700, 'Bravo'),
  (1200, 'Maestro'),
];

Nivel nivelPara(int aciertos) {
  final cuantos = aciertos < 0 ? 0 : aciertos;

  var cual = 0;
  for (var i = escalones.length - 1; i >= 0; i--) {
    if (cuantos >= escalones[i].$1) {
      cual = i;
      break;
    }
  }

  return Nivel(
    numero: cual + 1,
    nombre: escalones[cual].$2,
    desde: escalones[cual].$1,
    hasta: cual + 1 < escalones.length ? escalones[cual + 1].$1 : null,
    aciertos: cuantos,
  );
}
