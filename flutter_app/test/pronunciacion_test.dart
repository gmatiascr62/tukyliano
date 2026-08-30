import 'package:flutter_test/flutter_test.dart';
import 'package:tukyliano/datos/escucha.dart';
import 'package:tukyliano/datos/palabras_habladas.dart';
import 'package:tukyliano/logica/pronunciacion.dart';

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
    test('son diez y no se repiten', () {
      expect(palabrasParaDecir.length, 10);
      expect(
        palabrasParaDecir.map((p) => p.italiano).toSet().length,
        palabrasParaDecir.length,
      );
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
