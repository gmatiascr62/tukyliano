import 'package:flutter_test/flutter_test.dart';
import 'package:tukyliano/logica/correccion.dart';

/// Atajo: las palabras que quedaron en verde y las que quedaron en rojo.
({List<String> bien, List<String> mal}) partir(
  String correcta,
  String respuesta,
) {
  final r = corregir(correcta: correcta, respuesta: respuesta);
  return (
    bien: r.where((p) => p.acertada).map((p) => p.palabra).toList(),
    mal: r.where((p) => !p.acertada).map((p) => p.palabra).toList(),
  );
}

void main() {
  test('la respuesta exacta queda toda en verde', () {
    final r = corregir(correcta: 'Ho molta fame', respuesta: 'ho molta fame');
    expect(r.map((p) => p.palabra), ['Ho', 'molta', 'fame']);
    expect(todoAcertado(r), isTrue);
  });

  test('mantiene las palabras como están escritas en la referencia', () {
    // Se muestra la respuesta correcta tal cual, con su mayúscula.
    final r = corregir(correcta: 'Ho molta fame', respuesta: 'ho molta fame');
    expect(r.first.palabra, 'Ho');
  });

  test('marca en rojo solo la palabra que falta', () {
    final r = partir('Ho molta fame', 'ho molto fame');
    expect(r.bien, ['Ho', 'fame']);
    expect(r.mal, ['molta']);
  });

  test('no exige el orden', () {
    expect(partir('Ho molta fame', 'fame molta ho').mal, isEmpty);
  });

  test('una palabra de más no ensucia las que están bien', () {
    expect(partir('Ho fame', 'io ho fame').mal, isEmpty);
  });

  test('la respuesta vacía deja todo en rojo', () {
    final r = partir('Ho molta fame', '');
    expect(r.bien, isEmpty);
    expect(r.mal, ['Ho', 'molta', 'fame']);
    expect(todoAcertado(corregir(correcta: 'Ho fame', respuesta: '')), isFalse);
  });

  test('no le importan las mayúsculas', () {
    expect(partir('Ho fame', 'HO FAME').mal, isEmpty);
  });

  test('ignora los signos de alrededor', () {
    expect(partir('Hai fame?', 'hai fame').mal, isEmpty);
    expect(partir('Hai fame', '¿hai fame?').mal, isEmpty);
  });

  test('los acentos cuentan: sin acento va en rojo', () {
    expect(partir('Domani sarò a scuola', 'domani saro a scuola').mal, ['sarò']);
  });

  test('el apóstrofo es parte de la palabra', () {
    expect(partir("Ho un'idea", "ho un'idea").mal, isEmpty);
    // Separarlo en dos no cuenta como acertado.
    expect(partir("Ho un'idea", 'ho un idea').mal, ["un'idea"]);
  });

  test('una palabra repetida en la referencia necesita escribirla dos veces',
      () {
    // "ho" alcanza para la primera, la segunda queda en rojo.
    final r = partir('Ho fame e ho sete', 'ho fame e sete');
    expect(r.mal, ['ho']);
  });

  test('normalizar deja la palabra comparable', () {
    expect(normalizar('¿Fame?'), 'fame');
    expect(normalizar('FAME,'), 'fame');
    expect(normalizar("un'idea"), "un'idea");
    expect(normalizar('sarò'), 'sarò');
    expect(normalizar('...'), '');
  });

  test('todoAcertado es falso si no hay nada que corregir', () {
    expect(todoAcertado(const []), isFalse);
  });
}
