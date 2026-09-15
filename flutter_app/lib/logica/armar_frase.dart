/// Las fichas para armar una frase tocando palabras, en vez de escribirla
/// letra por letra con el teclado.
///
/// El banco trae las palabras de la frase más unas cuantas de más, todas
/// mezcladas. Las de más son las que hacen que el ejercicio no se resuelva
/// solo: sin ellas alcanzaría con tocar todo lo que hay.
library;

import 'dart:math';

/// Saca los signos de alrededor de la palabra. En la ficha no van: la coma y
/// el punto los pone la frase, no el alumno, y una ficha que dijera "casa,"
/// delataría que esa palabra va justo antes de la coma.
///
/// El apóstrofo queda pegado porque es parte de la palabra (l'ho, un'idea),
/// igual que en [normalizar] de la corrección.
String sinSignos(String palabra) => palabra.replaceAll(
      RegExp(r'''^[^\wàèéìòùá-ú']+|[^\wàèéìòùá-ú']+$'''),
      '',
    );

/// Las palabras de la frase, ya listas para ser fichas.
List<String> palabrasDeLaFrase(String frase) => frase
    .split(RegExp(r'\s+'))
    .map(sinSignos)
    .where((palabra) => palabra.isNotEmpty)
    .toList();

/// Palabras de relleno para cuando el verbo no da suficientes. Son las que más
/// se repiten en las frases de la app (artículos, preposiciones, pronombres y
/// adverbios cortos), así la de más no se nota por rara sino que hay que
/// pensarla.
const List<String> palabrasDeRelleno = [
  'il', 'lo', 'la', 'le', 'gli', 'un', 'una', 'di', 'da', 'a', 'in', 'con',
  'su', 'per', 'tra', 'non', 'anche', 'già', 'sempre', 'mai', 'molto', 'poco',
  'più', 'meno', 'ancora', 'solo', 'bene', 'male', 'tutto', 'niente', 'qui',
  'oggi', 'domani', 'ieri', 'quando', 'perché', 'però', 'come', 'dove', 'che',
  'mi', 'ti', 'ci', 'si', 'ne', 'casa', 'tempo', 'cosa', 'sera', 'mattina',
];

/// Cuántas palabras de más lleva el banco.
const int fichasDeMas = 3;

/// El banco de fichas para [frase], mezclado.
///
/// [extras] son las palabras de más que conviene ofrecer primero: las otras
/// conjugaciones del mismo verbo, que es donde está la duda de verdad (ho o
/// hai, andavo o andrò). Lo que falte se completa con [palabrasDeRelleno].
/// Nunca se repite una palabra que ya esté en la frase: sería una ficha de más
/// que en realidad está bien, y confundiría al corregir.
List<String> fichasPara(
  String frase, {
  Iterable<String> extras = const [],
  int cuantasDeMas = fichasDeMas,
  Random? azar,
}) {
  final random = azar ?? Random();
  final propias = palabrasDeLaFrase(frase);
  if (propias.isEmpty) return const [];

  final yaEstan = propias.map((p) => p.toLowerCase()).toSet();
  List<String> limpiar(Iterable<String> palabras) {
    final salida = <String>[];
    for (final palabra in palabras.map(sinSignos)) {
      if (palabra.isEmpty) continue;
      if (!yaEstan.add(palabra.toLowerCase())) continue;
      salida.add(palabra);
    }
    salida.shuffle(random);
    return salida;
  }

  // Primero las del verbo y después el relleno: las dos listas van mezcladas
  // por separado para que el relleno no le gane el lugar a la conjugación.
  final deMas = [...limpiar(extras), ...limpiar(palabrasDeRelleno)]
      .take(max(0, cuantasDeMas))
      .toList();

  return [...propias, ...deMas]..shuffle(random);
}

/// Las fichas que se pusieron de más: las que no entran en [correcta].
///
/// Hace falta porque la corrección mira la frase correcta palabra por palabra
/// y no se entera de lo que sobra. Sin esto, poner todas las fichas —también
/// las de más— pintaría la frase entera de verde.
List<String> fichasQueSobran({
  required String correcta,
  required Iterable<String> puestas,
}) {
  final quedan =
      palabrasDeLaFrase(correcta).map((p) => p.toLowerCase()).toList();

  return [
    for (final palabra in puestas)
      if (!quedan.remove(sinSignos(palabra).toLowerCase())) palabra,
  ];
}
