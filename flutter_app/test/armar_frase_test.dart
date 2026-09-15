import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tukyliano/logica/armar_frase.dart';

void main() {
  group('las palabras de la frase', () {
    test('la ficha no se lleva la coma ni el punto', () {
      expect(
        palabrasDeLaFrase('Quando arrivo a casa, mangio qualcosa.'),
        ['Quando', 'arrivo', 'a', 'casa', 'mangio', 'qualcosa'],
      );
    });

    test('el apóstrofo queda, que es parte de la palabra', () {
      expect(palabrasDeLaFrase("L'ho buttato via"), ["L'ho", 'buttato', 'via']);
    });

    test('las repetidas van las dos veces', () {
      expect(palabrasDeLaFrase('la casa e la sedia').length, 5);
    });
  });

  group('el banco de fichas', () {
    test('trae todas las palabras de la frase', () {
      final fichas = fichasPara('Ho molta fame', azar: Random(1));

      for (final palabra in ['Ho', 'molta', 'fame']) {
        expect(fichas, contains(palabra), reason: palabra);
      }
    });

    test('trae además las de más que se le piden', () {
      final fichas = fichasPara('Ho molta fame', cuantasDeMas: 3, azar: Random(1));

      expect(fichas.length, 6);
    });

    test('las de más nunca son una palabra que ya esté en la frase', () {
      // "casa" y "tempo" están en el relleno: si se colaran como ficha de más,
      // habría dos y poner las dos daría bien sin estar bien.
      final fichas = fichasPara('Vado a casa con poco tempo', azar: Random(3));

      expect(fichas.where((f) => f.toLowerCase() == 'casa').length, 1);
      expect(fichas.where((f) => f.toLowerCase() == 'tempo').length, 1);
    });

    test('las otras formas del verbo van primero que el relleno', () {
      final fichas = fichasPara(
        'Ho fame',
        extras: ['hai', 'abbiamo', 'avete'],
        cuantasDeMas: 3,
        azar: Random(7),
      );

      expect(fichas.toSet(), {'Ho', 'fame', 'hai', 'abbiamo', 'avete'});
    });

    test('si el verbo no da suficientes, completa con el relleno', () {
      final fichas = fichasPara(
        'Ho fame',
        extras: ['hai'],
        cuantasDeMas: 3,
        azar: Random(7),
      );

      expect(fichas.length, 5);
      expect(fichas, contains('hai'));
    });

    test('sin palabras no hay fichas', () {
      expect(fichasPara('   '), isEmpty);
    });

    test('no siempre salen en el mismo orden', () {
      final unas = fichasPara('Ho molta fame oggi', azar: Random(1));
      final otras = fichasPara('Ho molta fame oggi', azar: Random(2));

      // Podrían coincidir de casualidad, pero no con estas dos semillas.
      expect(unas, isNot(otras));
    });
  });

  group('lo que sobra', () {
    test('sin fichas de más no sobra nada', () {
      expect(
        fichasQueSobran(
          correcta: 'Ho molta fame',
          puestas: ['Ho', 'molta', 'fame'],
        ),
        isEmpty,
      );
    });

    test('la que no va queda marcada', () {
      expect(
        fichasQueSobran(
          correcta: 'Ho molta fame',
          puestas: ['Ho', 'molta', 'fame', 'sempre'],
        ),
        ['sempre'],
      );
    });

    test('no importan las mayúsculas ni los signos de la frase', () {
      expect(
        fichasQueSobran(
          correcta: 'Ho molta fame.',
          puestas: ['ho', 'molta', 'fame'],
        ),
        isEmpty,
      );
    });

    test('una repetida de más sí sobra', () {
      expect(
        fichasQueSobran(
          correcta: 'la casa e la sedia',
          puestas: ['la', 'la', 'la', 'casa'],
        ),
        ['la'],
      );
    });
  });
}
