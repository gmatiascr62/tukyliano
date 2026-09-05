import 'package:flutter_test/flutter_test.dart';
import 'package:tukyliano/datos/escucha.dart';
import 'package:tukyliano/datos/palabras_habladas.dart';
import 'package:tukyliano/logica/pronunciacion.dart';
import 'package:tukyliano/modelos/palabra_hablada.dart';

ComoSalio _decir(String palabra, String oido, {List<String> otras = const []}) {
  return comparar(
    esperada: palabra,
    oido: LoEscuchado(mejor: oido, alternativas: [oido, ...otras]),
  );
}

void main() {
  group('normalizar', () {
    test('saca mayúsculas, tildes y puntuación', () {
      expect(normalizar('Ciao!'), 'ciao');
      expect(normalizar('Perché...'), 'perche');
      expect(normalizar('  Grazie, mille  '), 'grazie mille');
    });

    test('escribe los números con letras', () {
      // Es el caso que más molesta: se dice "cinque" perfecto y Android
      // devuelve "5".
      expect(normalizar('5'), 'cinque');
      expect(normalizar('Ne ho 3.'), 'ne ho tre');
    });

    test('deja el apóstrofo, que separa palabras en italiano', () {
      expect(normalizar("L'ho buttato via"), "l'ho buttato via");
    });
  });

  group('cuantasSeguidas', () {
    const frase = 'il conto per favore';

    test('cuenta las palabras que ya salieron, desde el principio', () {
      expect(cuantasSeguidas(esperada: frase, oido: ''), 0);
      expect(cuantasSeguidas(esperada: frase, oido: 'il'), 1);
      expect(cuantasSeguidas(esperada: frase, oido: 'il conto'), 2);
      expect(cuantasSeguidas(esperada: frase, oido: 'Il conto, per favore.'), 4);
    });

    test('no avanza si se dice otra cosa', () {
      expect(cuantasSeguidas(esperada: frase, oido: 'il canto per favore'), 1);
    });

    test('saltea lo que el reconocedor mete de más', () {
      // Mientras corrige lo que escribió llegan palabras sueltas que no van.
      expect(
        cuantasSeguidas(esperada: frase, oido: 'il eh conto per favore'),
        4,
      );
    });

    test('empezar por el medio no cuenta', () {
      expect(cuantasSeguidas(esperada: frase, oido: 'per favore'), 0);
    });
  });

  group('comparar', () {
    test('el reconocedor entendió la palabra', () {
      expect(_decir('cinque', 'cinque'), ComoSalio.bien);
    });

    test('la entendió aunque la haya escrito distinto', () {
      expect(_decir('cinque', '5'), ComoSalio.bien);
      expect(_decir('ciao', 'Ciao!'), ComoSalio.bien);
    });

    test('entendió otra cosa', () {
      // "chi" dicho a la española suena "qui", que es otra palabra italiana.
      expect(_decir('cinque', 'quinque'), ComoSalio.mal);
    });

    test('casi: la palabra estaba, pero no en primer lugar', () {
      expect(
        _decir('nonna', 'nona', otras: ['nonna']),
        ComoSalio.casi,
      );
    });

    test('sin nada escuchado no cuenta como error', () {
      expect(comparar(esperada: 'ciao', oido: null), ComoSalio.nada);
      expect(
        comparar(esperada: 'ciao', oido: const LoEscuchado(mejor: '  ')),
        ComoSalio.nada,
      );
    });
  });

  group('las palabras de la prueba', () {
    test('los sonidos son unos cuantos y no se repiten', () {
      expect(sonidosParaDecir.length, greaterThanOrEqualTo(50));
      expect(
        sonidosParaDecir.map((p) => p.italiano).toSet().length,
        sonidosParaDecir.length,
      );
    });

    test('cada sonido tiene varias palabras para practicarlo', () {
      // Con una sola palabra por sonido no se practica el sonido: se aprende
      // esa palabra de memoria.
      final cuantas = <String, int>{};
      for (final palabra in sonidosParaDecir) {
        cuantas[palabra.sonido] = (cuantas[palabra.sonido] ?? 0) + 1;
      }
      for (final entrada in cuantas.entries) {
        expect(entrada.value, greaterThanOrEqualTo(2), reason: entrada.key);
      }
    });

    test('las frases son largas, con traducción y sin apóstrofos', () {
      expect(frasesParaDecir.length, greaterThanOrEqualTo(20));
      for (final frase in frasesParaDecir) {
        expect(frase.grupo, GrupoHabla.frases, reason: frase.italiano);
        expect(
          enPalabras(frase.italiano).length,
          inInclusiveRange(8, 12),
          reason: frase.italiano,
        );
        // El reconocedor a veces escribe el apóstrofo separado ("dov'è" como
        // "dove è"), y la frase no coincidiría por algo que no tiene nada que
        // ver con la pronunciación.
        expect(frase.italiano, isNot(contains("'")), reason: frase.italiano);
        // La tarjeta pinta de verde partiendo por espacios, y el avance se
        // cuenta sobre el texto normalizado: si no dieran lo mismo, el verde
        // quedaría corrido respecto de lo que se dijo.
        expect(
          frase.italiano.split(' ').length,
          enPalabras(frase.italiano).length,
          reason: frase.italiano,
        );
      }
    });

    test('los números van del 0 al 30, en orden y sin faltar ninguno', () {
      expect(numerosParaDecir.length, 31);
      for (final (i, numero) in numerosParaDecir.indexed) {
        expect(numero.sonido, '$i', reason: numero.italiano);
        expect(numero.grupo, GrupoHabla.numeros, reason: numero.italiano);
      }
    });

    test('cada número se reconoce dicho o escrito con cifra', () {
      // Android devuelve "23" cuando se dice "ventitré", así que las dos
      // formas tienen que dar bien.
      for (final (i, numero) in numerosParaDecir.indexed) {
        expect(
          _decir(numero.italiano, numero.italiano),
          ComoSalio.bien,
          reason: numero.italiano,
        );
        expect(
          _decir(numero.italiano, '$i'),
          ComoSalio.bien,
          reason: '$i = ${numero.italiano}',
        );
      }
    });

    test('cada una se compara consigo misma sin ayuda', () {
      // Si una palabra normalizada quedara vacía o con símbolos raros, decirla
      // bien daría mal para siempre.
      for (final palabra in palabrasParaDecir) {
        expect(
          _decir(palabra.italiano, palabra.italiano),
          ComoSalio.bien,
          reason: palabra.italiano,
        );
        expect(normalizar(palabra.italiano), isNotEmpty);
      }
    });

    test('todas tienen traducción, pista y sonido', () {
      for (final palabra in palabrasParaDecir) {
        expect(palabra.espanol, isNotEmpty, reason: palabra.italiano);
        expect(palabra.pista, isNotEmpty, reason: palabra.italiano);
        expect(palabra.sonido, isNotEmpty, reason: palabra.italiano);
      }
    });
  });
}
