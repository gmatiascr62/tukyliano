import 'package:flutter_test/flutter_test.dart';
import 'package:tukyliano/logica/nivel.dart';

void main() {
  test('sin nada hecho arranca en el primero', () {
    final nivel = nivelPara(0);

    expect(nivel.numero, 1);
    expect(nivel.nombre, 'Principiante');
    expect(nivel.cuanto, 0);
  });

  test('el anillo se llena entre un escalón y el siguiente', () {
    // El segundo escalón está en 50: a mitad de camino va la mitad pintada.
    expect(nivelPara(25).cuanto, closeTo(0.5, 0.001));
    expect(nivelPara(49).numero, 1);
    expect(nivelPara(50).numero, 2);
    expect(nivelPara(50).cuanto, 0);
  });

  test('dice cuántas faltan para el que sigue', () {
    expect(nivelPara(40).faltan, 10);
    expect(nivelPara(50).faltan, 100);
  });

  test('el último no tiene nada más adelante', () {
    final ultimo = nivelPara(escalones.last.$1);

    expect(ultimo.nombre, 'Maestro');
    expect(ultimo.esElUltimo, isTrue);
    expect(ultimo.cuanto, 1);
    expect(ultimo.faltan, 0);
    // Y seguir acertando no rompe nada ni lo hace volver atrás.
    expect(nivelPara(99999).nombre, 'Maestro');
  });

  test('nunca baja: más aciertos nunca dan un nivel menor', () {
    var anterior = 0;
    for (var aciertos = 0; aciertos <= 1500; aciertos += 7) {
      final numero = nivelPara(aciertos).numero;
      expect(numero, greaterThanOrEqualTo(anterior), reason: '$aciertos');
      anterior = numero;
    }
  });

  test('un número raro no rompe la pantalla', () {
    expect(nivelPara(-5).numero, 1);
  });

  test('los escalones van de menor a mayor y no se repiten', () {
    for (var i = 1; i < escalones.length; i++) {
      expect(escalones[i].$1, greaterThan(escalones[i - 1].$1));
    }
    expect(
      escalones.map((e) => e.$2).toSet().length,
      escalones.length,
    );
  });
}
